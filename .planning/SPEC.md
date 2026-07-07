# SPEC — LouvorJA API

## Metadados

| Campo | Valor |
|-------|-------|
| **Projeto** | louvorja/api |
| **Versão** | 1.8.0 (estimada, PR #27 + PRs abertos) |
| **Stack** | Laravel Lumen (PHP 8.3), MySQL, SQLite (export), Redis (cache), PHPUnit 10 |
| **Autor** | Rafael Zendron (rafaumeu) |
| **Data** | 2026-07-01 |
| **Status** | Baseline + Novas Funcionalidades (SDD Fase 1) |

---

## 1. Baseline — Estado Atual da API

### 1.1 Arquitetura Geral

```
┌─────────────┐     ┌──────────────────────────────┐
│  Cliente     │────▶│  API Lumen (PHP 8.3)        │
│  (App Web,   │     │  Porta 80 (prod) / 5003      │
│   Electron,  │     │  louvorja.com.br             │
│   Delphi)    │     │                              │
└─────────────┘     └──────┬───────────────────────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │  MySQL   │ │ JSON     │ │ YouTube  │
        │  (DB)    │ │ (estático)│ │ Data API │
        └──────────┘ └──────────┘ └──────────┘
```

### 1.2 Middleware Stack (ordem de execução)

| Middleware | Função | Aplica-se a |
|-----------|--------|-------------|
| `CorsMiddleware` | CORS headers (`Allow-Origin: *`) | Todas rotas |
| `GeneralMiddleware` | Bot blocking, subdomain redirect | `/health` + grupo `general` |
| `RateLimitMiddleware` | Rate limiting por IP (300/min geral, 600/min arquivos/metadados) | Grupo `rate_limit` |
| `ApiMiddleware` | Header `Api-Token` validation | Grupo `api` |
| `Authenticate (JWT)` | JWT guard | Grupo `auth` |
| `AccessMiddleware` | Permissões por role (insert/update/delete) | Rotas admin específicas |
| `ConfirmedPasswordMiddleware` | Exige troca de senha se temporária | Prefixo `admin` |
| `LangMiddleware` | Extrai `{lang}` da URL e injeta `$request->id_language` | Grupo `lang` |
| `RequestLoggingMiddleware` | Log de requests | Grupo `api` |
| `SecurityHeadersMiddleware` | Security headers (CSP, X-Frame, etc.) | Grupo `rate_limit` |

### 1.3 Endpoints Públicos (sem autenticação JWT — apenas Api-Token)

#### 1.3.1 Sem autenticação (fora do middleware `api`)

| Método | Rota | Controller | Descrição | Cache |
|--------|------|------------|-----------|-------|
| GET | `/health` | `HealthCheckController@check` | Health check (fora do GeneralMiddleware) | - |
| GET | `/` | Closure | Array vazio | - |
| GET | `/openapi.json` | `OpenApiController@spec` | OpenAPI spec dinâmica | - |
| GET | `/documentation` | `OpenApiController@ui` | Swagger UI | - |
| GET | `/file/{path:.*}` | `FileController@open` | Serve arquivo físico (imagem/áudio) | - |
| GET | `/metadata` | `MetaController@index` | Metadados da Bíblia | - |
| GET | `/player` | `PlayerController@index` | HTML inline com YouTube embed | - |
| GET | `/json_db` | `DatabaseJsonController@manifest` | Manifest de JSONs | 1h |
| GET | `/json_db/{file}` | `DatabaseJsonController@index` | JSON específico (legado) | - |
| GET | `/db/manifest` | `DatabaseJsonController@manifest` | Manifest (novo) | 1h |
| GET | `/db/{table}` | `DatabaseJsonController@table` | Registros paginados de tabela JSON | 5min |
| GET | `/db/{table}/categories` | `DatabaseJsonController@categories` | Valores únicos de coluna | 10min |
| GET | `/download` | `DownloadController@index` | Informações de download | - |
| GET | `/version` | `VersionController@index` | Versão API, PHP, Lumen, min_client | - |
| GET | `/version_log` | `VersionLogController@index` | Log de versões | - |

#### 1.3.2 Com Api-Token (grupo `api`)

| Método | Rota | Controller | Descrição |
|--------|------|------------|-----------|
| GET | `/params` | `ParamsController@index` | Parâmetros do app Delphi |
| GET | `/ftp` | `FtpController@index` | Dados FTP (bugado — 500) |
| GET | `/onlinevideos` | `OnlineVideosController@index` | Vídeos online (SQL ou JSON) |

#### 1.3.3 Autenticação (`/auth/`)

| Método | Rota | Controller | Descrição |
|--------|------|------------|-----------|
| POST | `/auth/login` | `AuthController@login` | Login (username + password) |
| POST | `/auth/refresh-token` | `AuthController@refreshToken` | Refresh JWT |
| POST | `/auth/refresh_token` | `AuthController@refreshToken` | Refresh JWT (alias) |
| GET | `/auth/me` | `AuthController@me` | Usuário atual |
| POST | `/auth/logout` | `AuthController@logout` | Invalida token |
| POST | `/auth/change-password` | `AuthController@changePassword` | Troca senha |

### 1.4 Endpoints com lang (`/{lang}/` — públicos, sem JWT)

| Método | Rota | Controller | Descrição |
|--------|------|------------|-----------|
| GET | `/{lang}/` | Closure | Vazio |
| GET | `/{lang}/config` | `ConfigController@index` | Configs públicas |
| GET | `/{lang}/configs` | `ConfigController@index` | Alias |
| GET | `/{lang}/languages` | `LanguageController@index` | Idiomas |
| GET | `/{lang}/musics` | `MusicController@index` | Músicas (paginado) |
| GET | `/{lang}/musics/{id}` | `MusicController@show` | Música específica |
| GET | `/{lang}/music/{id}` | `MusicController@show` | Alias |
| GET | `/{lang}/categories` | `CategoryController@index` | Categorias |
| GET | `/{lang}/categories_albums` | `CategoryAlbumController@index` | Relação cat-album |
| GET | `/{lang}/albums` | `AlbumController@index` | Álbuns |
| GET | `/{lang}/albums/{id}` | `AlbumController@show` | Álbum específico |
| GET | `/{lang}/album/{id}` | `AlbumController@show` | Alias |
| GET | `/{lang}/albums_musics` | `AlbumMusicController@index` | Relação album-music |
| GET | `/{lang}/lyrics` | `LyricController@index` | Letras |
| GET | `/{lang}/hymnal` | `HymnalController@index` | Hinários |
| GET | `/{lang}/files` | `FileController@index` | Arquivos |
| GET | `/{lang}/ftp` | `FtpController@index` | FTP (público) |
| GET | `/{lang}/download` | `DownloadController@index` | Download (fora do group api) |

### 1.5 Endpoints Admin (`/admin/` — require JWT + confirmed_pwd + access)

| Método | Rota | Controller | Access | Descrição |
|--------|------|------------|--------|-----------|
| GET | `/admin/users` | `UserController@index` | users | Lista usuários |
| POST | `/admin/users` | `UserController@store` | users | Cria usuário |
| GET | `/admin/users/{id}` | `UserController@show` | users | Usuário específico |
| PUT | `/admin/users/{id}` | `UserController@update` | users | Atualiza usuário |
| DELETE | `/admin/users/{id}` | `UserController@destroy` | users | Exclui usuário |
| GET | `/admin/categories` | `CategoryController@index` | - | Lista categorias |
| GET | `/admin/categories/{id}` | `CategoryController@show` | - | Categoria específica |
| POST | `/admin/categories` | `CategoryController@store` | categories | Cria categoria |
| PUT | `/admin/categories/{id}` | `CategoryController@update` | categories | Atualiza categoria |
| DELETE | `/admin/categories/{id}` | `CategoryController@destroy` | categories | Exclui categoria |
| GET | `/admin/categories_albums` | `CategoryAlbumController@index` | - | Lista relação |
| GET | `/admin/categories_albums/{id}` | `CategoryAlbumController@show` | - | Relação específica |
| POST | `/admin/categories_albums` | `CategoryAlbumController@store` | categories_albums | Cria relação |
| PUT | `/admin/categories_albums/{id}` | `CategoryAlbumController@update` | categories_albums | Atualiza relação |
| DELETE | `/admin/categories_albums/{id}` | `CategoryAlbumController@destroy` | categories_albums | Exclui relação |
| GET | `/admin/albums` | `AlbumController@index` | - | Lista álbuns |
| GET | `/admin/albums/{id}` | `AlbumController@show` | - | Álbum específico |
| POST | `/admin/albums` | `AlbumController@store` | albums | Cria álbum |
| PUT | `/admin/albums/{id}` | `AlbumController@update` | albums | Atualiza álbum |
| DELETE | `/admin/albums/{id}` | `AlbumController@destroy` | albums | Exclui álbum |
| GET | `/admin/musics` | `MusicController@index` | - | Lista músicas |
| GET | `/admin/musics/{id}` | `MusicController@show` | - | Música específica |
| POST | `/admin/musics` | `MusicController@store` | musics | Cria música |
| PUT | `/admin/musics/{id}` | `MusicController@update` | musics | Atualiza música |
| DELETE | `/admin/musics/{id}` | `MusicController@destroy` | musics | Exclui música |
| GET | `/admin/albums_musics` | `AlbumMusicController@index` | - | Lista relação |
| GET | `/admin/albums_musics/{id}` | `AlbumMusicController@show` | - | Relação específica |
| POST | `/admin/albums_musics` | `AlbumMusicController@store` | albums_musics | Cria relação |
| PUT | `/admin/albums_musics/{id}` | `AlbumMusicController@update` | albums_musics | Atualiza relação |
| DELETE | `/admin/albums_musics/{id}` | `AlbumMusicController@destroy` | albums_musics | Exclui relação |
| GET | `/admin/lyrics` | `LyricController@index` | - | Lista letras |
| GET | `/admin/lyrics/{id}` | `LyricController@show` | - | Letra específica |
| POST | `/admin/lyrics` | `LyricController@store` | lyrics | Cria letra |
| PUT | `/admin/lyrics/{id}` | `LyricController@update` | lyrics | Atualiza letra |
| DELETE | `/admin/lyrics/{id}` | `LyricController@destroy` | lyrics | Exclui letra |
| GET | `/admin/files` | `FileController@index` | - | Lista arquivos |
| GET | `/admin/files/{id}` | `FileController@show` | - | Arquivo específico |

> Nota: CRUD de `files` (store/update/destroy) está COMENTADO nas rotas.

### 1.6 Endpoints Tasks (`/tasks/` — require Api-Token)

| Método | Rota | Controller | Descrição |
|--------|------|------------|-----------|
| GET | `/tasks` | `TaskController@index` | Lista tarefas |
| GET | `/tasks/refresh_configs` | `TaskController@refresh_configs` | Refresh configs |
| GET | `/tasks/export_database` | `TaskController@export_database` | Export SQL |
| GET | `/tasks/refresh_files_size` | `TaskController@refresh_files_size` | Atualiza tamanhos |
| GET | `/tasks/refresh_files_duration` | `TaskController@refresh_files_duration` | Atualiza durações |
| GET | `/tasks/refresh_online_videos` | `TaskController@refresh_online_videos` | Atualiza YouTube |
| GET | `/tasks/import_slides` | `TaskController@import_slides` | Importa slides |
| GET | `/tasks/export_database_json` | `TaskController@export_database_json` | Export JSON |

### 1.7 Schema do Banco de Dados (21 tabelas)

#### Core
| Tabela | PK | Campos principais |
|--------|----|-------------------|
| `languages` | `id_language` (varchar 5) | `language` |
| `files` | `id_file` (int auto) | `name`, `type`, `size`, `dir`, `file_name`, `version`, `duration` |
| `albums` | `id_album` (int auto) | `name`, `id_file_image`, `color` (varchar 7), `id_language` |
| `categories` | `id_category` (int auto) | `name`, `slug` (varchar 20), `order`, `type` (varchar 20), `id_language` |
| `musics` | `id_music` (int auto) | `name`, `id_file_image`, `id_file_music`, `id_file_instrumental_music`, `id_language` |
| `lyrics` | `id_lyric` (int auto) | `id_music`, `lyric`, `aux_lyric`, `time`, `instrumental_time`, `show_slide`, `order` |
| `albums_musics` | `id_album_music` (int auto) | `id_album`, `id_music`, `track` |
| `categories_albums` | `id_category_album` (int auto) | `id_category`, `id_album`, `name`, `order` |

#### Bible
| Tabela | PK | Campos principais |
|--------|----|-------------------|
| `bible_book` | `id_bible_book` | `book_number`, `name`, `chapters`, `testament`, `abbreviation`, `color` |
| `bible_version` | `id_bible_version` | `name`, `abbreviation` |
| `bible_verse` | `id_bible_verse` | `id_bible_version`, `id_bible_book`, `chapter`, `verse`, `text` |

#### Admin / Infra
| Tabela | PK | Campos principais |
|--------|----|-------------------|
| `users` | `id` (bigint auto) | `name`, `username`, `email`, `password`, `is_admin`, `permissions` (json) |
| `configs` | `key` (varchar PK) | `type` (enum), `value`, `details` (json) |
| `logs` | `id_log` | `table`, `action`, `old_values` (json), `new_values` (json), `user_id` |
| `download_logs` | `id_download_log` | `version`, `ip`, `browser` |
| `ftp` | `id_ftp` | `active`, `data` (json) |
| `ftp_logs` | `id_ftp_logs` | `version`, `ip`, `error` (json) |
| `online_videos_channels` | `id_online_video_channel` | `channel_id`, `title`, `playlists` (json) |
| `online_videos_playlists` | `id_online_video_playlist` | `playlist_id`, `title` |
| `online_videos` | `id_online_video` | `video_id`, `title`, `sequence` |

---

## 2. Problemas Conhecidos (Bugs Ativos)

### RF-001 — SQL Injection em FileController::index()
- **Arquivo:** `app/Http/Controllers/FileController.php` (linhas 20-27)
- **Descrição:** `whereRaw` com concatenação direta de `$request["id_album"]`
- **Severidade:** CRÍTICA
- **PR:** #5 (mergeado) — FIX APLICADO em main

### RF-002 — StreamedResponse::header() bug (RESOLVIDO)
- **Causa:** RateLimitMiddleware chamava `->header()` em StreamedResponse
- **Fix:** PR #26 → `->headers->set()`. Elias corrigiu manualmente em prod.
- **PR #27:** Limites diferenciados (300/600/600) — AGUARDANDO MAYCO

### RF-003 — FtpController retorna 500
- **Rota:** `GET /ftp`
- **Causa:** `Firebase\JWT\JWT::decode()` recebe null em vez de string
- **Status:** NÃO RESOLVIDO

### RF-004 — CORS wildcard
- `CorsMiddleware` envia `Access-Control-Allow-Origin: *` em todos ambientes
- **PR:** #6 (security headers + CORS whitelist) — AGUARDANDO MAYCO

### RF-005 — env() extensivo (RESOLVIDO)
- **PR:** #10 — 36 chamadas substituídas por `config()`, `config:cache` compatível
- **MERGED**

### RF-006 — env() não configurado localmente
- `.env` sem `APP_KEY`, `JWT_SECRET`, `API_TOKEN` em dev — EnvValidator bloqueia
- **Impacto:** `php artisan` commands falham localmente

### RF-007 — Doxologia (id=2) e Infantis (id=5) sem `type`
- **Categorias** existem no banco mas não têm campo `type` populado
- **Impacto:** Aplicações não conseguem filtrar por tipo

### RF-008 — HymnalController sem método show()
- Controller só tem `index()` — não existe show() nem nas rotas públicas nem admin
- **Impacto:** Não é possível buscar hinário específico por ID via API

### RF-009 — Métodos show() existem mas sem rota pública
- `CategoryController@show`, `AlbumController@show`, `LyricController@show` existem
- Só expostos via `/admin/` (autenticado)
- **Pedido do Diego:** Precisa de endpoint para álbuns/músicas de categoria específica (Doxologia e Kids)

### RF-010 — Rate limit pode bloquear Electron Desktop no primeiro boot
- Primeiro boot faz 16.871 requisições (82 albums, 2.509 músicas, 14.268 bible chapters)
- **PR #27:** Limite de 600/min para arquivos ajuda mas não resolve para 16k req em lote
- Alternativa: rate limit mais alto para `/file/` e `/json_db/`

---

## 3. Funcionalidades Novas (Feature Requests)

### FR-001 — Endpoint: álbuns e músicas de uma categoria específica
- **Rota proposta:** `GET /{lang}/categories/{id}/albums-with-musics`
- **Descrição:** Retorna álbuns da categoria + músicas de cada álbum
- **Resolve:** Doxologia (id=2) e Kids/Infantis (id=5)
- **Prioridade:** ALTA (pedido do Diego)

### FR-002 — Endpoint: coletâneas online
- **Rota proposta:** `GET /{lang}/collections/online`
- **Descrição:** Retorna álbuns/vídeos que são coletâneas online
- **Prioridade:** ALTA (pedido do Diego)

### FR-003 — Endpoint: manifest do banco de dados
- **Rota proposta:** `GET /db/manifest`
- **Descrição:** JÁ EXISTE (DatabaseJsonController@manifest)
- **Adicionar:** Versão, data de geração, tamanho total, contagem de arquivos

### FR-004 — Endpoint: download do banco de dados
- **Rota proposta:** `GET /db/download`
- **Descrição:** Download de um bundle .zip com todos os JSONs
- **Prioridade:** MÉDIA (Elias pediu)

### FR-005 — Rota pública: categories/{id}/albums
- **Rota proposta:** `GET /{lang}/categories/{id}/albums` (público)
- **Já existe admin:** `CategoryAlbumController@index` no admin
- **Solução:** Adicionar rota pública com filtro por category_id

### FR-006 — Endpoint: albums/category/{slug}
- **Rota proposta:** `GET /{lang}/albums/category/{slug}`
- **Descrição:** Filtra álbuns pela slug da categoria
- **Resolve:** Doxologia, Kids sem precisar saber o ID numérico

### FR-007 — Endpoint de sugestão de hinos
- **Rota proposta:** `POST /{lang}/suggest`
- **Descrição:** Sugere hinos baseado em tema, ocasião, texto bíblico
- **Prioridade:** BAIXA (requer LLM/embeddings)

### FR-008 — Endpoint de bundle único
- **Rota proposta:** `GET /db/bundle`
- **Descrição:** Bundle .zip de todos os JSONs (16.871 arquivos) para Electron
- **Prioridade:** MÉDIA

### FR-009 — Health check aprimorado
- **Rota:** `GET /health` (já existe)
- **Melhoria:** Adicionar status do banco, cache, YouTube API, últimas tasks

---

## 4. Requisitos Não-Funcionais (NFs)

| NF | Descrição | Critério de Aceite |
|----|-----------|-------------------|
| NF-01 | **Performance** — Resposta em < 200ms para 95% dos requests públicos | Lighthouse / k6 |
| NF-02 | **Cache** — JSONs estáticos com cache de 5min a 1h | Cache headers + Redis |
| NF-03 | **Segurança** — SQL injection zero | Todos os inputs sanitizados |
| NF-04 | **CORS** — Whitelist configurável (não wildcard em prod) | PR #6 |
| NF-05 | **Documentação** — OpenAPI completa e sempre atualizada | Swagger UI + CI |
| NF-06 | **Compatibilidade** — Backward compat com Delphi e Electron | Nenhuma rota existente pode quebrar |
| NF-07 | **Observabilidade** — Logs estruturados, métricas | PR #19 |
| NF-08 | **LGPD** — Logs de download sem expor IP completo | Mascarar IP |
| NF-09 | **Rate Limiting** — Limites por tipo de rota | PR #27 |
| NF-10 | **Testes** — 80+ testes, 199+ assertions passando | PHPUnit + CI |

---

## 5. Fora de Escopo

| Item | Motivo |
|------|--------|
| CI/CD no louvorja/api | Mayco não usa GitHub Actions |
| Migração para Node.js/Express | Stack é Lumen/Laravel |
| Electron bundle download server-side | Resolvido via CI do elvieira |
| Chatbot Louvor J.AI | Projeto separado da Thayza |
| Site institucional (`louvorja/site`) | Projeto independente com Bootstrap |
| App web (`louvorja/app`) em TypeScript | Projeto Vue 3+Vuetify separado |
| App Electron do Elias (`elvieira/LouvorJA`) | Repositório separado |
| juanaleixo/louvorja | Fork separado, não na org |

---

## 6. Análise de Impacto (Breakage Risk)

| Mudança | Risco | Mitigação |
|---------|-------|-----------|
| Nova rota pública + controller | BAIXO | Rota nova não afeta existentes |
| Mudar CORS middleware | MÉDIO | Testar com todos os clients |
| Alterar Data helper | ALTO | Usado por TODOS os controllers index() |
| Remover rota | ALTO | Delphi, Electron, App web podem quebrar |
| Renomear campo JSON | ALTO | App web e Electron usam campos fixos |
| Corrigir SQL injection | BAIXO | Apenas FileController afetado |
| Adicionar campo `type` em categorias | BAIXO | Campo já existe no schema, só populando |

---

## 7. Rastreabilidade

| RF-ID | Arquivo | Controller | Rota(s) | Status |
|-------|---------|------------|---------|--------|
| RF-001 | `FileController.php` | `FileController@index` | `/admin/files` | ✅ FIXED (PR #5) |
| RF-002 | `RateLimitMiddleware.php` | Todos | Todas | ✅ FIXED (PR #26, prod manual) |
| RF-003 | `FtpController.php` | `FtpController@index` | `/ftp` | 🔴 BUG |
| RF-004 | `CorsMiddleware.php` | Todas | Todas | 🔴 OPEN (PR #6) |
| RF-005 | `*.php` (36 arquivos) | Vários | Várias | ✅ FIXED (PR #10) |
| RF-007 | `categories` table | `CategoryController` | `/{lang}/categories` | 🔴 DADOS FALTANDO |
| RF-008 | `HymnalController.php` | `HymnalController` | `/{lang}/hymnal` | 🔴 SEM SHOW |
| RF-009 | `routes/web.php` | Category/Album/Lyric | Falta rota pública show() | 🔴 GAP |
| FR-001 | Novo | Novo | `/{lang}/categories/{id}/albums-with-musics` | 📝 PLANEJADO |
| FR-002 | Novo | Novo | `/{lang}/collections/online` | 📝 PLANEJADO |
| FR-003 | `DatabaseJsonController.php` | manifest() | `/db/manifest` | ✅ EXISTE (melhorar) |
| FR-006 | Novo | Novo | `/{lang}/albums/category/{slug}` | 📝 PLANEJADO |