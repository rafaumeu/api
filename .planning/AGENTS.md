# AGENTS — Guia para Agentes de IA e Devs Novos

Este documento é referência rápida para qualquer agente de IA ou desenvolvedor que precise trabalhar no `louvorja/api`.

---

## Stack

- **Framework:** Laravel Lumen (micro-framework do Laravel)
- **PHP:** 8.3
- **Banco:** MySQL (produção), SQLite (`:memory:` em testes)
- **Cache:** Redis (produção), File (dev)
- **Auth:** JWT (`php-open-source-saver/jwt-auth`)
- **Testes:** PHPUnit 10 + SQLite in-memory
- **OpenAPI:** `zircote/swagger-php` (PHP 8 Attributes)
- **Tasks:** `TaskController` (não tem schedule — chamadas manuais ou cron externo)

---

## Estrutura de Diretórios

```
louvorja-api/
├── app/
│   ├── Http/
│   │   ├── Controllers/    ← 22 controllers
│   │   └── Middleware/      ← 11 middlewares
│   ├── Helpers/             ← 10 helpers (Data, Configs, DataBase, etc.)
│   └── Models/              ← 21 Eloquent models
├── config/                  ← Config files (PR #10)
├── database/
│   └── migrations/          ← 21 migrations
├── routes/
│   └── web.php              ← Todas as rotas em um arquivo
├── public/
│   ├── db/json/             ← 16.871 JSONs exportados
│   └── index.php
├── storage/
│   ├── openapi.json         ← OpenAPI spec pré-gerada
│   └── logs/
├── tests/                   ← 80+ testes PHPUnit
├── .planning/               ← SDD artifacts (SPEC, PLAN, AGENTS, CONTEXT)
└── bootstrap/
    └── app.php              ← Service providers, middleware registration
```

---

## Regras de Ouro para PRs

1. **PR PEQUENO** = Mayco aprova. Idealmente < 50 linhas de diff.
2. **SEMPRE sincronizar o fork** antes de criar branch:
   ```bash
   git fetch origin main
   git checkout main
   git pull origin main           # main do louvorja/api
   git push fork main             # sincronizar fork
   ```
3. **Limpar untracked files** de branches anteriores:
   ```bash
   git clean -fd app/ tests/ public/
   ```
4. **Assinar commits** (chave sem passphrase):
   ```bash
   git -c user.signingkey=47FECA848C9FB0F0 commit -S -m "feat: ..."
   ```
5. **Push para o fork** (origin = louvorja/api, fork = rafaumeu/api):
   ```bash
   git push fork feat/minha-branch
   ```
6. **PR com head do fork**:
   ```bash
   gh pr create --repo louvorja/api --base main --head rafaumeu:feat/minha-branch
   ```

---

## Pitfalls Conhecidos

### PHP / Lumen

| Pitfall | Sintoma | Solução |
|---------|---------|---------|
| `->header()` em middleware crasha | 500 com `Call to undefined method StreamedResponse::header()` | Usar `$response->headers->set()` |
| `array_collapse()` não existe | Erro fatal | Usar `array_merge(...array_values($array))` |
| `config:cache` quebra com `env()` | Config não carrega | Usar `config()`, não `env()` |
| RouteParams.php causa 500 em testes | Testes com auth retornam 500 | Usar `assertNotEquals(200)` |
| `config(['key' => 'val'])` não sobrescreve em testes | Teste falha | Testar via reflection |
| Rota inexistente retorna 500 em teste | `$this->get('/rota-x')` → 500 | Testar error handler via método direto |

### Git / PR

| Pitfall | Sintoma | Solução |
|---------|---------|---------|
| `git push origin` → Permission denied | Não tem push no louvorja/api | Usar `git push fork` |
| `gh pr create` sem `--head` | "No commits found" | Passar `--head rafaumeu:branch` |
| Chave GPG com passphrase falha em script | Exit 128 | Usar chave sem passphrase |
| Untracked files de branch anterior | `git checkout -b` falha | Rodar `git clean -fd app/ tests/ public/` |

### Telegram / Comunicação

| Pitfall | Regra |
|---------|-------|
| Enviar mensagem automática no grupo | ❌ NUNCA — só quando o usuário pedir |
| Assumir que algo existe porque Mayco pediu | ❌ SEMPRE verificar no código/PRs |
| Fabricar dados de diff | ❌ NUNCA — se não conseguiu ler, pergunte |
| Enviar PR grande | ❌ PR deve ser < 50 linhas idealmente |

---

## Comandos Úteis

```bash
# Rodar testes
vendor/bin/phpunit

# Regenerar OpenAPI spec
php generate_openapi.php

# Servidor dev na porta 8080
php -S 0.0.0.0:8080 -t public public/index.php

# Listar rotas (se disponível)
php artisan route:list

# Export JSONs do banco
curl https://api.louvorja.com.br/tasks/export_database_json -H "Api-Token: $TOKEN"

# Verificar PRs abertos
gh pr list --repo louvorja/api --state open

# Verificar CI de PR
gh pr checks <N> --repo louvorja/api
```

---

## Integrações Externas

| Service | Config | Como testar |
|---------|--------|-------------|
| YouTube Data API v3 | `config/api.php` → `youtube.key` | `GET /tasks/refresh_online_videos` |
| Telegram Bot | `config/api.php` → `telegram.*` | Via `TelegramService::sendMessage()` |
| FTP (servidores igrejas) | `config/files.php` | `GET /tasks/send_database_ftp` |

---

## Repositórios Relacionados

| Repo | Stack | Mantenedor |
|------|-------|------------|
| `louvorja/app` | Vue 3 + Vuetify | Mayco |
| `louvorja/desktop` | Delphi | Mayco |
| `elvieira/LouvorJA` | Vue 3 + Electron | Elias |
| `juanaleixo/louvorja` | Vue 3 + TS + Pinia | Juan |
| `rafaumeu/api` | Lumen (fork) | Rafael |

---

## Contatos

| Pessoa | Papel | Contato |
|--------|-------|---------|
| Mayco | Mantenedor, aprova PRs | Telegram |
| Diego (@Ajegado) | Usuário/Dev, pede features | Grupo devs |
| Elias (@elvieira9) | Electron Desktop | Chat privado 6572836307 |
| Thayza (@Thayza_Raquel) | LouvorJ.AI Chatbot | Grupo devs |
| Rafael (rafaumeu) | Contribuidor, fork | GitHub |