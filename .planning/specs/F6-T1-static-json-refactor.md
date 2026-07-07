# SPEC: F6-T1 — Refatoração para JSONs Estáticos Pré-gerados

> **Status:** Draft
> **Author:** Rafael Zendron (rafaumeu)
> **Created:** 2026-07-07
> **Approved by:** [Pendente]
> **Motivação:** Feedback do Mayco no PR #28 — app desktop/web não deve bater na API em tempo real; deve ler JSONs locais

## 1. Contexto

O PR #28 adicionou 6 endpoints dinâmicos (CategoryController::albums, albumsWithMusics, AlbumController::byCategorySlug, CollectionController::online, HymnalController::show, DatabaseJsonController::bundle) que consultam o banco MySQL em tempo real.

O Mayco deixou o seguinte comentário:

> "A aplicação desktop (e a web, já que usarão o mesmo fonte) não deve se comunicar com a api. Deve somente ler os arquivos JSON baixados na máquina do usuário... A única rota que ela deve ler é a rota para ver se tem novas versões disponíveis, e baixar esses arquivos atualizados... Nesse caso, teria que criar rotas para a geração desses jsons."

**Implicação:** Todos os endpoints dinâmicos adicionados no PR #28 precisam ser refatorados para seguir o padrão `DatabaseJsonController`: dados pré-gerados como arquivos JSON estáticos, servidos sem consultar o banco.

## 2. Requisitos Funcionais

### RF-01: Rota de versão dos JSONs estáticos
**User Story:** Como desenvolvedor do app, quero consultar a versão atual dos JSONs pré-gerados, para saber se preciso baixar atualizações.

**Critérios de Aceite (EARS):**
- WHEN o app faz `GET /db/manifest` THE SYSTEM SHALL retornar objeto JSON com `version`, `generated_at`, e lista de `files` com `name`, `hash` (md5/sha256), `size`
- WHEN existe uma nova versão THE SYSTEM SHALL incrementar `version` automaticamente
- IF o app enviar header `If-None-Match` com o hash atual THE SYSTEM SHALL retornar 304 Not Modified

### RF-02: Rota de download de JSON individual
**User Story:** Como desenvolvedor do app, quero baixar um JSON específico por nome, para atualizar meus dados locais.

**Critérios de Aceite (EARS):**
- WHEN o app faz `GET /db/{file}.json` THE SYSTEM SHALL servir o arquivo estático de `public/db/json/{file}.json`
- WHEN o arquivo não existe THE SYSTEM SHALL retornar 404
- WHEN o app enviar header `If-None-Match` THE SYSTEM SHALL retornar 304 se o hash for igual

### RF-03: Rota de bundle ZIP (download completo)
**User Story:** Como desenvolvedor do app, quero baixar um ZIP com todos os JSONs de uma vez, para first-time setup.

**Critérios de Aceite (EARS):**
- WHEN o app faz `GET /db/bundle` THE SYSTEM SHALL servir ZIP com todos os arquivos JSON
- WHEN nenhum JSON existe THE SYSTEM SHALL retornar 404
- O ZIP deve conter todos os `.json` de `public/db/json/`
- Cache do ZIP: 1 hora

### RF-04: Rota de geração de JSONs (admin/task)
**User Story:** como administrador, quero disparar a geração/atualização dos JSONs estáticos, para publicar novos dados sem deploy.

**Critérios de Aceite (EARS):**
- WHEN o admin faz `GET /tasks/generate_static_jsons` THE SYSTEM SHALL executar a geração de todos os JSONs pré-gerados
- WHEN a geração termina THE SYSTEM SHALL salvar arquivos em `public/db/json/` e atualizar o manifest
- WHEN a geração falhar THE SYSTEM SHALL retornar erro com detalhes
- A geração DEVE cobrir: categories, albums, musics, lyrics, hymnal, collections/online, categories_albums, albums_musics, categories/{id}/albums, categories/{id}/albums-with-musics, albums/category/{slug}, hymnal/{id}

### RF-05: Remover endpoints dinâmicos do PR #28
**User Story:** como mantenedor da API, quero remover os endpoints dinâmicos que batem no banco, para forçar o uso de JSONs estáticos.

**Critérios de Aceite (EARS):**
- WHEN o PR é mergeado THE SYSTEM SHALL NÃO ter rotas `/{lang}/categories/{id}/albums`, `/{lang}/categories/{id}/albums-with-musics`, `/{lang}/albums/category/{slug}`, `/{lang}/collections/online`, `/{lang}/hymnal/{id}` como endpoints dinâmicos
- IF um endpoint precisar ser migrado para JSON estático THE SYSTEM SHALL manter a rota mas servir o JSON pré-gerado ao invés de consultar o banco

**Decisão pendente:** O Mayco disse "não deve se comunicar com a API". Isso significa:
- **Opção A:** Remover as rotas públicas completamente — o app só lê JSONs locais, nunca chama a API exceto para checar versão
- **Opção B:** Manter as rotas públicas mas refatorar para servir JSON estático (DatabaseJsonController padrão) — o app pode tanto ler local quanto baixar da API

### RF-06: Gerar JSONs para endpoints do PR #28
**User Story:** como administrador, quero que a task de geração crie JSONs para os dados que antes eram dinâmicos.

**Critérios de Aceite (EARS):**
- WHEN a geração roda THE SYSTEM SHALL criar:
  - `public/db/json/categories.json` — lista de categorias
  - `public/db/json/categories_{id}_albums.json` — álbuns por categoria (para cada ID)
  - `public/db/json/categories_{id}_albums_with_musics.json` — álbuns com músicas por categoria
  - `public/db/json/albums_category_{slug}.json` — álbuns por slug de categoria
  - `public/db/json/collections_online.json` — coletâneas online
  - `public/db/json/hymnal.json` — hinários (lista)
  - `public/db/json/hymnal_{id}.json` — hino específico

## 3. Requisitos Não-Funcionais

| Categoria | Requisito | Métrica |
|-----------|-----------|---------|
| Performance | Servir JSON estático | < 50ms (file read vs DB query) |
| Compatibilidade | Backward compat | JSONs devem ter o mesmo shape que os endpoints dinâmicos retornavam |
| Cache | Headers de cache nos JSONs estáticos | ETag + Last-Modified |
| Segurança | Geração só via admin/task | Protegido por Api-Token |

## 4. Fora de Escopo

- Primeiro boot do Electron (16k requests) — resolvido via bundle + leitura local
- Implementar IA/sugestão de hinos (FR-007 da SPEC principal)
- Mudar a stack do app desktop (continua Electron)
- Migrar para CDN/Cloudflare para servir JSONs — pode ser futuro

## 5. Decisões Arquiteturais

### Padrão: DatabaseJsonController

Todos os endpoints de leitura de dados estáticos devem seguir o padrão existente do `DatabaseJsonController`:

```
GET /db/manifest              → manifest com versão + lista de arquivos + hashes
GET /db/{table}               → JSON de uma tabela (já existe)
GET /db/{table}/categories    → categorias de uma tabela (já existe)
GET /db/{file}.json           → JSON individual (novo — mapear nomes amigáveis)
GET /db/bundle                → ZIP com todos os JSONs (PR #28, já existe)
GET /tasks/generate_static_jsons → gera/atualiza todos os JSONs (novo)
```

### Naming Convention dos Arquivos JSON

| Endpoint Dinâmico (removido) | Arquivo JSON Estático |
|------------------------------|----------------------|
| `/{lang}/categories/{id}/albums` | `categories_{id}_albums.json` |
| `/{lang}/categories/{id}/albums-with-musics` | `categories_{id}_albums_with_musics.json` |
| `/{lang}/albums/category/{slug}` | `albums_category_{slug}.json` |
| `/{lang}/collections/online` | `collections_online.json` |
| `/{lang}/hymnal` | `hymnal.json` |
| `/{lang}/hymnal/{id}` | `hymnal_{id}.json` |

### Rota de lookup amigável

Para mapear de endpoint legível para arquivo JSON, adicionar:

```
GET /db/categories/{id}/albums           → serve categories_{id}_albums.json
GET /db/categories/{id}/albums-with-musics → serve categories_{id}_albums_with_musics.json
GET /db/albums/category/{slug}            → serve albums_category_{slug}.json
GET /db/collections/online                 → serve collections_online.json
GET /db/hymnal/{id}                       → serve hymnal_{id}.json
```

Todas essas rotas servem arquivos estáticos do `public/db/json/`.

## 6. Dependências

### Técnicas
- `DatabaseJsonController` (já existe — base do padrão)
- `TaskController` (já existe — base para tasks de geração)
- `VersionController` (já existe — referência para versionamento)
- Redis/Cache (já configurado)

### Blocadores
- **Decisão do Mayco:** Confirmar Opção A (remover rotas) ou Opção B (manter rotas servindo JSON estático)

## 7. Riscos

| Risco | Probabilidade | Impacto | Mitigação |
|-------|--------------|---------|-----------|
| Geração de JSONs demorar muito (16k+ arquivos) | Média | Médio | Gerar apenas arquivos compostos (por categoria/slug), não por registro individual |
| Quebrar app Electron existente | Média | Alto | JSONs manter mesmo shape dos endpoints dinâmicos |
| Mayco querer rotas públicas dinâmicas de qualquer forma | Baixa | Alto | Confirmar antes de implementar |

## 8. Critério de Pronto (Definition of Done)

- [ ] Task de geração `generate_static_jsons` implementada e funcional
- [ ] Manifest inclui hashes para verificação de versão
- [ ] Rotas de lookup amigável (`/db/categories/{id}/albums`, etc.) servem JSONs estáticos
- [ ] Bundle ZIP funciona e inclui os novos JSONs
- [ ] Endpoints dinâmicos do PR #28 removidos OU refatorados para servir estático
- [ ] Shape dos JSONs é idêntico ao que os endpoints dinâmicos retornavam
- [ ] Testes PHPUnit para task de geração e rotas de lookup
- [ ] Documentação OpenAPI atualizada
- [ ] SPEC marcada como Implemented

## 9. Change Log

| Data | Autor | Mudança |
|------|-------|---------|
| 2026-07-07 | Rafael | Versão inicial — draft para aprovação |
