# Specs de Endpoints — LouvorJA API

> Criado: 2026-07-04 por Rafael Zendron (rafaumeu)
> Origem: `.planning/SPEC.md` + `.planning/PLAN.md`

## Endpoints Planejados Pendentes

| RF-ID | Endpoint | Spec | Complexidade | Dependências |
|-------|----------|------|--------------|--------------|
| F1-T3 | `GET /{lang}/hymnal/{id}` | [F1-T3](F1-T3-hymnal-show.md) | Baixa | Nenhuma |
| F2-T1 | `GET /{lang}/categories/{id}/albums` | [F2-T1](F2-T1-categories-albums.md) | Média | F1-T1 (categorias com type) |
| F2-T2 | `GET /{lang}/categories/{id}/albums-with-musics` | [F2-T2](F2-T2-categories-albums-with-musics.md) | Alta | F2-T1 |
| F2-T3 | `GET /{lang}/albums/category/{slug}` | [F2-T3](F2-T3-albums-by-category-slug.md) | Média | F1-T1 (slugs) |
| F2-T4 | `GET /{lang}/collections/online` | [F2-T4](F2-T4-collections-online.md) | Média | F1-T2 (schema online_videos) |
| F3-T2 | `GET /db/bundle` | [F3-T2](F3-T2-db-bundle.md) | Muito Alta | F3-T1 (versionamento) |
| F6-T1 | Refatoração: JSONs estáticos (feedback Mayco PR #28) | [F6-T1](F6-T1-static-json-refactor.md) | Alta | Decisão Mayco (Opção A/B) |

## Ordem de Implementação Sugerida

> **IMPORTANTE:** A spec F6-T1 (refatoração para JSONs estáticos) bloqueia as specs F2-T1 a F2-T4 e F1-T3 caso o Mayco confirme a **Opção A** (remover rotas dinâmicas). Se Opção B (manter rotas servindo estático), F6-T1 redefine a implementação dessas specs.

1. **F1-T3** (hymnal show) — sem dependências, complexidade baixa, warm-up
2. **F2-T1** (albums por categoria) — base para F2-T2 e F2-T3
3. **F2-T3** (albums por slug) — derivado de F2-T1
4. **F2-T2** (albums com musics) — derivado de F2-T1, complexidade alta
5. **F2-T4** (collections online) — independente, médio
6. **F3-T2** (db bundle) — complexidade muito alta, deixar por último

## Convenções

- Cada spec = 1 PR (fork workflow: push para rafaumeu/api, PR para louvorja/api)
- Seguir padrões existentes do projeto (OpenAPI annotations PHP 8 attributes, Data helper para paginação)
- Cache Redis para endpoints públicos (5-10 min conforme spec)
- Rotas públicas no grupo `{lang}`, rotas de DB no grupo `rate_limit`
- Atentar à ordem de registro de rotas em `routes/web.php` para evitar conflitos de matching do Lumen

## Status

- [x] Specs criadas (6/6)
- [ ] Implementação (pendente — specs-only conforme solicitação)
- [ ] PRs abertas (pendente)
