# SPEC: Endpoint Público — Álbuns de uma Categoria

> **Status:** Draft
> **Author:** Rafael Zendron (rafaumeu)
> **Created:** 2026-07-04
> **RF-ID:** F2-T1 (PLAN.md), FR-005 (SPEC.md)
> **Referência:** SPEC.md §3, RF-009

## 1. Contexto

Atualmente só é possível listar álbuns de uma categoria via endpoint admin (`/admin/categories_albums`), que exige JWT + access control. O Diego (@Ajegado) precisa de um endpoint público para listar álbuns de categorias específicas como Doxologia (id=2) e Infantis (id=5), para exibir nas telas do app sem exigir autenticação de admin.

## 2. Requisitos Funcionais

### RF-01: Rota pública `GET /{lang}/categories/{id}/albums`

**User Story:**
> Como app cliente, quero listar os álbuns de uma categoria específica, para exibir coleções como Doxologia e Kids sem autenticação de admin.

**Critérios de Aceite (EARS):**
- WHEN o cliente faz `GET /{lang}/categories/{id}/albums` THE SYSTEM SHALL retornar lista paginada de álbuns pertencentes à categoria informada
- WHEN a categoria existe e tem álbuns THE SYSTEM SHALL retornar `200` com array de álbuns (id, name, url_image, color, subtitle, order)
- IF a categoria não existir THE SYSTEM SHALL retornar `404` com `{"error": "Category not found"}`
- IF a categoria existir mas não tiver álbuns THE SYSTEM SHALL retornar `200` com array vazio `[]`
- THE SYSTEM SHALL aceitar parâmetros de paginação `?page=1&per_page=15`
- WHEN o header `Cache-Control` não desabilitar cache THE SYSTEM SHALL cachear resposta por 5 minutos

### RF-02: Query com join categoria-álbum

**Critérios de Aceite:**
- THE SYSTEM SHALL usar join: `categories_albums` → `albums` → `files` (para url_image)
- THE SYSTEM SHALL filtrar por `categories_albums.id_category = {id}` e `albums.id_language = {lang}`

## 3. Requisitos Não-Funcionais

| Categoria | Requisito | Métrica |
|-----------|-----------|---------|
| Performance | Latência P95 | < 200ms |
| Cache | Redis 5 min | `categories.{lang}.{id}.albums.{page}` |
| Segurança | Pública, sem JWT | Apenas Api-Token |
| Compatibilidade | Nova rota, não afeta `/admin/categories_albums` | - |
| Cobertura | Smoke test com id=2 e id=5 | PHPUnit |

## 4. Fora de Escopo

- Músicas dentro de cada álbum (ver F2-T2)
- Filtro por slug em vez de ID numérico (ver F2-T3)
- Ordenação customizada (usa `order` padrão)

## 5. Dependências

### Técnicas
- `CategoryAlbumController@index` (reaproveitar query com filtro adicional)
- `App\Helpers\Data` para paginação

### Blocadores
- **F1-T1**: Categorias Doxologia (id=2) e Infantis (id=5) devem ter campo `type` populado para teste

## 6. Arquitetura

```
Cliente → GET /{lang}/categories/{id}/albums?page=1
         → LangMiddleware
         → CategoryController@albumsByCategory($request, $id)
           → Category::where('id_category', $id)
                       ->where('id_language', $id_language)
                       ->firstOrFail()
           → CategoryAlbum::join('albums')
                           ->join('files')
                           ->where('id_category', $id)
                           ->paginate()
         → JSON 200 | 404
```

## 7. Implementação

**Opção A (preferida):** Novo método `albumsByCategory()` em `CategoryController`:
- Valida categoria existe (404 se não)
- Query join categories_albums + albums + files
- Retorna via `Data::data()`

**Opção B:** Adicionar filtro `category_id` no `CategoryAlbumController@index` e rota que aponta para ele.

**Rota:** `routes/web.php` dentro do grupo `{lang}`:
```php
$router->get('/categories/{id}/albums', 'CategoryController@albumsByCategory');
```

## 8. Riscos

| Risco | Probabilidade | Impacto | Mitigação |
|-------|--------------|---------|-----------|
| Categoria sem type populado | Média | Baixo | F1-T1 resolve; endpoint funciona independente |
| N+1 queries ao carregar files | Baixa | Médio | Join explícito em vez de eager load |
| Conflito de rota com `/categories/{id}` | Baixa | Baixo | Lumen diferencia `/categories/{id}` de `/categories/{id}/albums` |

## 9. Critério de Pronto

- [ ] Método/rota implementada
- [ ] OpenAPI annotation adicionada
- [ ] Smoke test: `GET /pt/categories/2/albums` retorna 200
- [ ] Smoke test: `GET /pt/categories/999999/albums` retorna 404
- [ ] Cache de 5 min configurado
- [ ] PR < 40 linhas
- [ ] Code review aprovado (Mayco)

## 10. Change Log

| Data | Autor | Mudança |
|------|-------|---------|
| 2026-07-04 | Rafael Zendron | Versão inicial |
