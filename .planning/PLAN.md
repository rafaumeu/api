# PLAN — LouvorJA API

> Baseado na SPEC.md v1.0. Cada task é um PR independente. PRs pequenos = Mayco aprova rápido.

---

## Fase 1: Correções Prioritárias (Bugs + Dados)

### F1-T1 — Popular `type` nas categorias Doxologia e Infantis
- **Controllers:** Nenhum (data fix via migration ou SQL)
- **Arquivos:** Nova migration `database/migrations/` ou SQL inline
- **Testes:** Validar que `/admin/categories/{2,5}` retorna `type` populado
- **PR:** Um commit, < 10 linhas
- **Dependências:** Nenhuma

### F1-T2 — Corrigir FtpController 500
- **Controller:** `app/Http/Controllers/FtpController.php`
- **Causa:** `JWT::decode()` recebe null quando `$request->token` não é enviado
- **Fix:** Validar parâmetro token, retornar 400 se ausente
- **Testes:** Testar com e sem token
- **PR:** Um commit, < 20 linhas
- **Dependências:** Nenhuma

### F1-T3 — Adicionar show() no HymnalController
- **Controller:** `app/Http/Controllers/HymnalController.php`
- **Rota:** `GET /{lang}/hymnal/{id}` (público)
- **Descrição:** Retorna música específica do hinário
- **Reaproveitar:** Mesma query do HymnalController@index com filtro por ID
- **Testes:** Testar show() com ID válido e inválido
- **PR:** Um controller, uma rota. < 15 linhas de código

---

## Fase 2: Endpoints Públicos Faltantes (Pedidos do Diego)

### F2-T1 — Rota pública: `GET /{lang}/categories/{id}/albums`
- **Controller:** `CategoryAlbumController@index` (reaproveitar com filtro)
- **Rota:** `/{lang}/categories/{id}/albums` (público, sem auth)
- **Descrição:** Retorna álbuns de uma categoria específica
- **Cache:** 5 minutos
- **OpenAPI:** Adicionar OA\Get no CategoryAlbumController
- **Testes:** Testar com id=2 (Doxologia) e id=5 (Infantis)
- **Dependências:** F1-T1 (ter type populado)

### F2-T2 — Endpoint composto: `GET /{lang}/categories/{id}/albums-with-musics`
- **Controller:** Novo `CategoryAlbumMusicController` ou método no CategoryController
- **Rota:** `/{lang}/categories/{id}/albums-with-musics`
- **Descrição:** Retorna álbuns + músicas de cada álbum
- **Output:**
```json
{
  "category": { "id": 2, "name": "Doxologia", "type": "hymnal" },
  "albums": [
    {
      "id": 5,
      "name": "Hinos Clássicos",
      "musics": [
        { "id": 100, "name": "Grande És Tu", "track": 1 }
      ]
    }
  ]
}
```
- **Cache:** 5 minutos
- **Testes:** Testar com dados reais, validar nested structure
- **Dependências:** F2-T1

### F2-T3 — Endpoint: `GET /{lang}/albums/category/{slug}`
- **Controller:** Novo método em `AlbumController` ou rota com join
- **Rota:** `/{lang}/albums/category/{slug}`
- **Descrição:** Filtra álbuns pela slug da categoria
- **Exemplo:** `/{lang}/albums/category/hymnal`
- **Testes:** Validar slug 'hymnal', 'kids', 'worship'
- **Dependências:** F1-T1

### F2-T4 — Endpoint: `GET /{lang}/collections/online`
- **Controller:** Novo método ou controller específico
- **Rota:** `/{lang}/collections/online`
- **Descrição:** Retorna coletâneas online (álbuns marcados como online)
- **Critério:** Filtrar álbuns por categoria com type='online' ou flag específica
- **Testes:** Validar retorno apenas de álbuns online
- **Dependências:** F1-T1

---

## Fase 3: Banco de Dados (Manifest + Download)

### F3-T1 — Melhorar manifest: adicionar metadados
- **Controller:** `DatabaseJsonController@manifest`
- **Descrição:** Atualizar resposta para incluir `version`, `generated_at`, `total_files`, `total_size`
- **Cache:** 1h
- **Formato:**
```json
{
  "version": "1.8.0",
  "generated_at": "2026-07-01T12:00:00Z",
  "total_files": 16871,
  "total_size_mb": 42.5,
  "files": [...]
}
```
- **Testes:** Validar campos adicionais
- **Dependências:** Nenhuma

### F3-T2 — Endpoint de bundle .zip
- **Controller:** `DatabaseJsonController@bundle` (novo)
- **Rota:** `GET /db/bundle`
- **Descrição:** Gera e serve bundle .zip de todos os JSONs
- **Cache:** Gerar uma vez, cachear o arquivo
- **Performance:** `ini_set('memory_limit', '-1')` + `set_time_limit(300)`
- **Alternativa:** Task gera arquivo estático, endpoint serve o arquivo
- **Testes:** Validar zip gerado, integridade dos arquivos
- **Dependências:** F3-T1

### F3-T3 — Health check aprimorado
- **Controller:** `HealthCheckController@check`
- **Adicionar:** Status do banco, cache, YouTube API, últimas tasks
- **Formato:**
```json
{
  "status": "healthy",
  "database": "connected",
  "cache": "redis",
  "youtube_api": "ok",
  "last_export": "2026-07-01T11:00:00Z",
  "version": "1.8.0"
}
```
- **Testes:** Validar todos os checks
- **Dependências:** Nenhuma

---

## Fase 4: Melhorias de Infra (PRs Abertos)

### F4-T1 — Merge PR #6 (CORS + Security Headers)
- **PR:** https://github.com/louvorja/api/pull/6
- **Status:** Aberto
- **Ação:** Rebase em main atual, resolver conflitos se houver
- **Testes:** Validar CORS com múltiplos origins

### F4-T2 — Merge PR #27 (Rate Limiting Ajustado)
- **PR:** https://github.com/louvorja/api/pull/27
- **Status:** Aberto
- **Ação:** Verificar conflitos com main atual
- **Testes:** Validar limites diferentes por tipo de rota

### F4-T3 — Corrigir comentário CRUD de files
- **Arquivo:** `routes/web.php` (linhas comentadas do FileController)
- **Descrição:** Comentário tem `AlbumController` em vez de `FileController`
- **Ação:** Corrigir referência, implementar CRUD se necessário
- **PR:** Correção de documentação, < 10 linhas

---

## Fase 5: Testes e Documentação

### F5-T1 — Script de seed local (16.871 JSONs)
- **Descrição:** Script Python ou bash para baixar todos os JSONs da prod
- **Uso:** `php seed:json` (Artisan command)
- **Cache:** Salvar em `public/db/json/`
- **Testes:** Validar integridade após seed

### F5-T2 — Atualizar OpenAPI spec
- **Descrição:** Regenerar `storage/openapi.json` com todos os novos endpoints
- **Comando:** `php generate_openapi.php`
- **Verificação:** Swagger UI em `/documentation` com todos os endpoints

### F5-T3 — Testes de regressão
- **Descrição:** Rodar `vendor/bin/phpunit` — validar 80+ testes passando
- **Novos testes:** Para cada novo endpoint (F2, F3)
- **Cobertura:** Pelo menos smoke test para cada nova rota

---

## Cronograma Estimado

| Fase | Tasks | Esforço | Dependências |
|------|-------|---------|--------------|
| F1 | 3 | 1 dia | Nenhuma |
| F2 | 4 | 2 dias | F1 |
| F3 | 3 | 1 dia | Nenhuma |
| F4 | 3 | 0.5 dia | PRs abertos |
| F5 | 3 | 0.5 dia | F1-F4 |

**Total:** ~5 dias de trabalho para um dev solo.

---

## Glossário

- **Task:** Unidade atômica de trabalho. Cada task vira 1 PR.
- **Fase:** Agrupamento lógico de tasks. Pode ser executada em paralelo com outras fases (se não houver dependência).
- **Dependência:** Task X depende de Y → Y precisa ser merged antes de X ser criada.
- **PR:** Pull Request no `louvorja/api`. Deve ser pequeno (< 50 linhas idealmente).