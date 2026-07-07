# SPEC: Endpoint — Bundle ZIP para Download Offline Completo

> **Status:** Draft
> **Author:** Rafael Zendron (rafaumeu)
> **Created:** 2026-07-04
> **RF-ID:** F3-T2 (PLAN.md), FR-010 (SPEC.md)
> **Referência:** SPEC.md §4, snapshot-endpoint SPEC (louvorja repo)

## 1. Contexto

O endpoint de snapshot (`GET /json_db` / `GET /db/manifest`) retorna JSON individual por arquivo. O Diego (@Ajegado) precisa baixar TODO o banco (JSON + arquivos de mídia: áudio, imagens) em um único artifact para sincronização offline completa no app Electron. Hoje são necessários múltiplos downloads: 7 JSONs + centenas de arquivos de mídia. Um endpoint de bundle ZIP resolve isso em uma chamada, com suporte a versionamento (delta vs full).

## 2. Requisitos Funcionais

### RF-01: Rota `GET /db/bundle`

**User Story:**
> Como Electron app, quero baixar um ZIP com todo o banco (JSON + mídia) em uma única requisição, para sincronizar o conteúdo offline completo com 1 round trip.

**Critérios de Aceite (EARS):**
- WHEN o cliente faz `GET /db/bundle` THE SYSTEM SHALL iniciar stream de um arquivo ZIP contendo todos os JSONs do banco + arquivos de mídia
- WHEN o cliente faz `GET /db/bundle?version=3.2.1` THE SYSTEM SHALL retornar apenas arquivos alterados desde a versão informada (delta bundle)
- WHEN o cliente faz `GET /db/bundle?type=json` THE SYSTEM SHALL incluir apenas arquivos JSON (sem mídia)
- WHEN o cliente faz `GET /db/bundle?type=media` THE SYSTEM SHALL incluir apenas arquivos de mídia (sem JSON)
- WHEN o bundle é gerado THE SYSTEM SHALL setar headers:
  - `Content-Type: application/zip`
  - `Content-Disposition: attachment; filename="louvorja-bundle-{version}.zip"`
  - `X-Bundle-Version: {version}`
  - `X-Bundle-File-Count: {count}`
  - `X-Bundle-Type: full|delta`
- WHEN o cliente envia `Accept-Encoding: gzip` THE SYSTEM SHALL comprimir o stream do ZIP
- IF uma versão delta for solicitada mas não houver alterações THE SYSTEM SHALL retornar `200` com ZIP vazio e header `X-Bundle-Type: delta-empty`

### RF-02: Versionamento do bundle

**Critérios de Aceite:**
- THE SYSTEM SHALL extrair a versão atual do banco de `config.json` (campo `version`)
- WHEN gerando delta bundle THE SYSTEM SHALL comparar timestamps de modificação dos arquivos com a versão base
- THE SYSTEM SHALL incluir arquivo `manifest.json` dentro do ZIP listando todos os arquivos incluídos com seus hashes

### RF-03: Streaming (não carregar tudo em memória)

**Critérios de Aceite:**
- THE SYSTEM SHALL usar streaming response (chunked transfer) para não exceder `memory_limit`
- THE SYSTEM SHALL usar `ZipStream` (ou equivalente PHP streaming) em vez de `ZipArchive` (que materializa em disco)
- WHEN o bundle exceder tempo limite THE SYSTEM SHALL continuar o stream (set_time_limit já configurado no DatabaseJsonController)

## 3. Requisitos Não-Funcionais

| Categoria | Requisito | Métrica |
|-----------|-----------|---------|
| Performance | Tempo de geração full bundle | < 30s (aprox. 5000 arquivos) |
| Performance | Tempo de geração delta bundle | < 5s |
| Memória | Pico de memória | < 50MB (streaming) |
| Cache | Cache do manifest por 1h | Não cachear ZIP (gerado on-demand) |
| Segurança | Api-Token obrigatório | Rate limit especial: 1 bundle / 5 min por token |
| Tamanho | Full bundle | < 500MB (estimado com mídia) |
| Tamanho | JSON-only bundle | < 10MB |
| Compatibilidade | Nova rota, não afeta `/db/*` | - |
| Cobertura | Smoke test: bundle JSON-only | PHPUnit |

## 4. Fora de Escopo

- Resume de download parcial (HTTP Range) — futuro
- Notificação push quando bundle delta estiver pronto (futuro)
- Pre-building de bundles em background job (futuro, F3-T3)
- Criptografia do ZIP (futuro)
- Bundle por categoria específica (futuro)

## 5. Dependências

### Técnicas
- `maennchen/zip-stream-php` (composer) — streaming ZIP generation sem disco
  - Alternativa: `react/stream-zip` se ZipStream não funcionar em Lumen/ARM64
- `App\Http\Controllers\DatabaseJsonController` (reaproveitar `__construct` com memory/time settings)
- Redis para rate limiting customizado (1 bundle / 5 min)

### Blocadores
- **F3-T1**: Sistema de versionamento do banco deve estar implementado (campo `version` em `config.json` + version_log)
- Confirmar se `maennchen/zip-stream-php` é compatível com PHP 8.3 + ARM64 (testar install antes)

## 6. Arquitetura

```
Cliente → GET /db/bundle?type=json&version=3.2.1
         → Api-Token middleware
         → RateLimit (custom: 1/5min)
         → DatabaseJsonController@bundle($request)
           → ler config.json → $currentVersion
           → if version param: listar arquivos alterados (delta)
              else: listar todos (full)
           → iniciar ZipStream response
           → foreach arquivo:
               ZipStream::addFileFromPath($name, $path)
             adicionar manifest.json com hashes
           → headers: Content-Type, Content-Disposition, X-Bundle-*
         → Stream 200
```

## 7. Implementação

**Método** `bundle()` em `DatabaseJsonController` (já tem `__construct` com memory/time settings).

Passos:
1. Validar `type` param (default: `all`, valores: `json`, `media`, `all`)
2. Ler versão atual de `config.json`
3. Se `version` param informado: comparar com version_log para delta
4. Instanciar ZipStream com opção `sendHeaders(true)`
5. Adicionar arquivos via `addFileFromPath()` (streaming)
6. Adicionar `manifest.json` com lista de arquivos + hashes MD5
7. Finalizar stream

**Dependência composer:**
```bash
composer require maennchen/zip-stream-php
```

**Rota:** `routes/web.php` dentro do grupo `rate_limit`:
```php
$router->get('/db/bundle', 'DatabaseJsonController@bundle');
```

**Rate limiting custom:** Adicionar lógica no `RateLimitMiddleware` ou middleware dedicado `BundleRateLimit` que limita a 1 bundle / 5 min por Api-Token.

## 8. Riscos

| Risco | Probabilidade | Impacto | Mitigação |
|-------|--------------|---------|-----------|
| ZipStream incompatível com PHP 8.3 ARM64 | Média | Alto | Testar install em ambiente antes; fallback para `ZipArchive` + arquivo temp |
| Timeout em bundles grandes (> 500MB) | Alta | Alto | `set_time_limit(0)` já no constructor; nginx/PHP-FPM timeout config |
| Memória em bundles com muitos arquivos | Média | Alto | ZipStream streaming (não carrega tudo); validar pico < 50MB |
| Conflito de rota `/db/bundle` vs `/db/{table}` | Alta | Médio | Registrar `/db/bundle` ANTES de `/db/{table}` para Lumen matching correto |
| Rate limit insuficiente (DDoS de bundles) | Média | Alto | Middleware custom 1/5min + CDN cache (futuro) |
| Disco cheio se usar ZipArchive fallback | Baixa | Alto | Preferir ZipStream (zero disco) |

## 9. Critério de Pronto

- [ ] `maennchen/zip-stream-php` instalado e testado em ARM64
- [ ] Método `bundle()` implementado com streaming
- [ ] Suporte a `type=json`, `type=media`, `type=all` (default)
- [ ] Suporte a `version=X.Y.Z` para delta bundle
- [ ] `manifest.json` incluído no ZIP com hashes
- [ ] Headers corretos (Content-Type, Content-Disposition, X-Bundle-*)
- [ ] Rate limit custom 1/5min implementado
- [ ] Rota registrada **antes** de `/db/{table}`
- [ ] OpenAPI annotation
- [ ] Smoke test: `GET /db/bundle?type=json` retorna ZIP válido com JSONs
- [ ] Smoke test: `GET /db/bundle?type=json&version=0.0.1` retorna delta (quase full)
- [ ] Smoke test: memory peak < 50MB durante geração
- [ ] Rotas `/db/*` existentes não quebradas
- [ ] PR < 120 linhas
- [ ] Code review aprovado (Mayco)

## 10. Change Log

| Data | Autor | Mudança |
|------|-------|---------|
| 2026-07-04 | Rafael Zendron | Versão inicial |
