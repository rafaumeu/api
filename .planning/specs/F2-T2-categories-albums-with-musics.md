# SPEC: Endpoint Composto — Álbuns com Músicas de uma Categoria

> **Status:** Draft
> **Author:** Rafael Zendron (rafaumeu)
> **Created:** 2026-07-04
> **RF-ID:** F2-T2 (PLAN.md), FR-001 (SPEC.md)
> **Referência:** SPEC.md §3

## 1. Contexto

O Diego (@Ajegado) precisa de um endpoint que retorne, em uma única requisição, a categoria + todos os seus álbuns + todas as músicas de cada álbum. Hoje isso exige múltiplas chamadas: listar categoria, listar álbuns da categoria, listar músicas de cada álbum. Para coleções como Doxologia (id=2) e Kids (id=5), isso significa dezenas de round trips. Um endpoint composto resolve isso em uma chamada.

## 2. Requisitos Funcionais

### RF-01: Rota `GET /{lang}/categories/{id}/albums-with-musics`

**User Story:**
> Como app cliente, quero obter a categoria completa com álbuns e músicas aninhadas em uma única chamada, para renderizar a tela de coleção sem múltiplas requisições.

**Critérios de Aceite (EARS):**
- WHEN o cliente faz `GET /{lang}/categories/{id}/albums-with-musics` THE SYSTEM SHALL retornar JSON com estrutura aninhada: `category` → `albums[]` → `musics[]`
- WHEN a categoria existe THE SYSTEM SHALL retornar `200` com:
  ```json
  {
    "category": { "id_category": 2, "name": "Doxologia", "type": "hymnal", "slug": "doxologia" },
    "albums": [
      {
        "id_album": 5, "name": "Hinos Clássicos", "color": "#FF5722",
        "url_image": "...", "order": 1,
        "musics": [
          { "id_music": 100, "name": "Grande És Tu", "track": 1, "url_music": "...", "url_image": "..." }
        ]
      }
    ]
  }
  ```
- IF a categoria não existir THE SYSTEM SHALL retornar `404` com `{"error": "Category not found"}`
- IF a categoria existir mas não tiver álbuns THE SYSTEM SHALL retornar `200` com `"albums": []`
- IF um álbum não tiver músicas THE SYSTEM SHALL incluir o álbum com `"musics": []`
- THE SYSTEM SHALL ordenar álbuns por `categories_albums.order` e músicas por `albums_musics.track`
- WHEN o header `Cache-Control` não desabilitar cache THE SYSTEM SHALL cachear resposta por 5 minutos

## 3. Requisitos Não-Funcionais

| Categoria | Requisito | Métrica |
|-----------|-----------|---------|
| Performance | Latência P95 | < 500ms (categoria grande) |
| Cache | Redis 5 min | `categories.{lang}.{id}.awm` |
| Segurança | Pública, sem JWT | Apenas Api-Token |
| Payload | Tamanho máximo | < 1MB por categoria |
| Compatibilidade | Nova rota, não afeta existentes | - |
| Cobertura | Smoke test com id=2 e id=5 | PHPUnit |

## 4. Fora de Escopo

- Paginação de álbuns (todas as coleções são < 20 álbuns)
- Letras/lírics dentro das músicas (futuro, se pedido)
- Filtro por slug ao invés de ID (F2-T3)
- Versão paginada (futuro, se coleções crescerem muito)

## 5. Dependências

### Técnicas
- `App\Models\Category`, `App\Models\Album`, `App\Models\Music`
- `App\Helpers\Data`

### Blocadores
- **F2-T1**: Endpoint de álbuns por categoria deve existir primeiro (compartilha lógica de validação de categoria)

## 6. Arquitetura

```
Cliente → GET /{lang}/categories/{id}/albums-with-musics
         → LangMiddleware
         → CategoryController@albumsWithMusics($request, $id)
           → Category::where('id_category', $id)->firstOrFail()
           → albums = CategoryAlbum::join('albums')
                          ->join('files')
                          ->where('id_category', $id)
                          ->orderBy('order')
                          ->get()
           → foreach albums:
               musics = AlbumMusic::join('musics')
                          ->join('files')
                          ->where('id_album', album.id)
                          ->orderBy('track')
                          ->get()
           → montar estrutura aninhada
         → JSON 200 | 404
```

## 7. Implementação

**Novo método** `albumsWithMusics()` em `CategoryController` (ou novo controller `CategoryAlbumMusicController` se preferir separação).

Lógica:
1. Buscar categoria ou 404
2. Buscar álbuns com join categories_albums + albums + files
3. Buscar músicas agrupadas por id_album (query única com `whereIn` + group em PHP)
4. Montar array aninhado

**Otimização:** Evitar N+1 buscando todas as músicas dos álbuns de uma vez com `whereIn('id_album', $albumIds)`.

**Rota:** `routes/web.php`:
```php
$router->get('/categories/{id}/albums-with-musics', 'CategoryController@albumsWithMusics');
```

## 8. Riscos

| Risco | Probabilidade | Impacto | Mitigação |
|-------|--------------|---------|-----------|
| N+1 queries (1 por álbum) | Alta | Médio | Batch query com `whereIn` |
| Payload grande para categoria com muitos álbuns | Média | Médio | Cache de 5min + `memory_limit` já setado no controller |
| Latência em primeira chamada (sem cache) | Média | Baixo | Cache warm-up via task |

## 9. Critério de Pronto

- [ ] Método `albumsWithMusics()` implementado com batch query (sem N+1)
- [ ] Rota registrada
- [ ] OpenAPI annotation com schema de resposta aninhada
- [ ] Smoke test: `GET /pt/categories/2/albums-with-musics` retorna 200 com estrutura válida
- [ ] Smoke test: `GET /pt/categories/999999/albums-with-musics` retorna 404
- [ ] Cache de 5 min configurado
- [ ] PR < 60 linhas
- [ ] Code review aprovado (Mayco)

## 10. Change Log

| Data | Autor | Mudança |
|------|-------|---------|
| 2026-07-04 | Rafael Zendron | Versão inicial |
