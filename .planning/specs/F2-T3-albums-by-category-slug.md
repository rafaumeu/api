# SPEC: Endpoint — Álbuns por Slug de Categoria

> **Status:** Draft
> **Author:** Rafael Zendron (rafaumeu)
> **Created:** 2026-07-04
> **RF-ID:** F2-T3 (PLAN.md), FR-006 (SPEC.md)
> **Referência:** SPEC.md §3

## 1. Contexto

Os apps cliente (App Web Vue, Electron) frequentemente não conhecem o ID numérico das categorias, mas conhecem o slug (`hymnal`, `doxologia`, `kids`, `worship`). O endpoint `GET /{lang}/categories/{id}/albums` (F2-T1) exige ID numérico. Este endpoint permite filtrar por slug, simplificando a integração client-side.

## 2. Requisitos Funcionais

### RF-01: Rota `GET /{lang}/albums/category/{slug}`

**User Story:**
> Como app cliente, quero buscar álbuns pela slug da categoria (ex: `hymnal`, `kids`), para não depender de IDs numéricos internos.

**Critérios de Aceite (EARS):**
- WHEN o cliente faz `GET /{lang}/albums/category/{slug}` THE SYSTEM SHALL retornar lista paginada de álbuns cuja categoria tem a slug informada
- WHEN a slug existe THE SYSTEM SHALL retornar `200` com álbuns (id, name, url_image, color, subtitle, order)
- IF a slug não corresponder a nenhuma categoria THE SYSTEM SHALL retornar `200` com array vazio `[]` (não 404 — slugs podem não existir em todos idiomas)
- THE SYSTEM SHALL aceitar parâmetros `?page=1&per_page=15`
- THE SYSTEM SHALL aceitar parâmetro `?q=texto` para busca textual no nome do álbum
- WHEN cache disponível THE SYSTEM SHALL cachear por 5 minutos

### RF-02: Query com join triplo

**Critérios de Aceite:**
- THE SYSTEM SHALL fazer join: `albums` → `categories_albums` → `categories`
- THE SYSTEM SHALL filtrar por `categories.slug = {slug}` e `albums.id_language = {lang}`

## 3. Requisitos Não-Funcionais

| Categoria | Requisito | Métrica |
|-----------|-----------|---------|
| Performance | Latência P95 | < 200ms |
| Cache | Redis 5 min | `albums.{lang}.category.{slug}.{page}` |
| Segurança | Pública, sem JWT | Apenas Api-Token |
| Compatibilidade | Nova rota, não afeta `/albums` nem `/albums/{id}` | - |
| Cobertura | Smoke test com slugs `hymnal`, `kids` | PHPUnit |

## 4. Fora de Escopo

- Músicas aninhadas (usar F2-T2 para isso)
- Múltiplas slugs em uma chamada (futuro)
- Busca fuzzy na slug (match exato apenas)

## 5. Dependências

### Técnicas
- `App\Models\Album`, `App\Models\Category`
- `App\Helpers\Data`

### Blocadores
- **F1-T1**: Categorias devem ter `slug` populada corretamente (campo já existe no schema, mas Doxologia/Kids podem não ter)

## 6. Arquitetura

```
Cliente → GET /{lang}/albums/category/{slug}?page=1
         → LangMiddleware
         → AlbumController@byCategorySlug($request, $slug)
           → Album::select(...)->join('categories_albums', ...)
                        ->join('categories', ...)
                        ->join('files', ...)
                        ->where('categories.slug', $slug)
                        ->where('albums.id_language', $id_language)
                        ->paginate()
         → JSON 200 (array, possivelmente vazio)
```

## 7. Implementação

**Novo método** `byCategorySlug()` em `AlbumController`.

Observação: o `index()` atual do `AlbumController` já tem lógica que verifica `categories_slug` no request (linhas com `isset($request["categories_slug"])`). Reaproveitar esse padrão.

**Rota:** `routes/web.php` dentro do grupo `{lang}`:
```php
$router->get('/albums/category/{slug}', 'AlbumController@byCategorySlug');
```

**Atenção:** Registrar esta rota ANTES de `/albums/{id}` para evitar que Lumen interprete `category` como `{id}`. Ou usar path distinto.

## 8. Riscos

| Risco | Probabilidade | Impacto | Mitigação |
|-------|--------------|---------|-----------|
| Rota `/albums/category/{slug}` conflita com `/albums/{id}` | Alta | Alto | Lumen matching é greedy — registrar `/albums/category/{slug}` antes, ou o `category` será capturado como `{id}`. **Testar ordem das rotas.** |
| Slug com caracteres especiais | Baixa | Baixo | Lumen decodifica URL automaticamente |
| Categoria sem slug em alguns idiomas | Média | Baixo | Retornar array vazio em vez de erro |

## 9. Critério de Pronto

- [ ] Método `byCategorySlug()` implementado
- [ ] Rota registrada **antes** de `/albums/{id}` (verificar ordem)
- [ ] OpenAPI annotation adicionada
- [ ] Smoke test: `GET /pt/albums/category/hymnal` retorna 200
- [ ] Smoke test: `GET /pt/albums/category/kids` retorna 200
- [ ] Smoke test: `GET /pt/albums/category/nonexistent` retorna 200 com `[]`
- [ ] Cache de 5 min configurado
- [ ] PR < 40 linhas
- [ ] Code review aprovado (Mayco)

## 10. Change Log

| Data | Autor | Mudança |
|------|-------|---------|
| 2026-07-04 | Rafael Zendron | Versão inicial |
