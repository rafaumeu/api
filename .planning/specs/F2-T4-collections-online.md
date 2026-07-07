# SPEC: Endpoint — Coleções Online ( vídeos / banners )

> **Status:** Draft
> **Author:** Rafael Zendron (rafaumeu)
> **Created:** 2026-07-04
> **RF-ID:** F2-T4 (PLAN.md), FR-007 (SPEC.md)
> **Referência:** SPEC.md §3

## 1. Contexto

A rota `GET /onlinevideos` já existe e retorna vídeos online brutos. Porém o app precisa de um endpoint formatado que agrupe conteúdo "online" (vídeos, banners, destaques) por categoria/tipo, pronto para renderizar na home e telas de coleção. Hoje o cliente tem que pós-processar `/onlinevideos` para estruturar os dados.

## 2. Requisitos Funcionais

### RF-01: Rota `GET /{lang}/collections/online`

**User Story:**
> Como app cliente, quero um endpoint que retorne coleções de conteúdo online já estruturadas (banners, vídeos em destaque), para renderizar a home sem pós-processamento client-side.

**Critérios de Aceite (EARS):**
- WHEN o cliente faz `GET /{lang}/collections/online` THE SYSTEM SHALL retornar JSON estruturado com seções de conteúdo online
- WHEN existirem vídeos online THE SYSTEM SHALL incluir seção `"videos"` com array de itens: `{ id, title, url, thumbnail, category, order }`
- WHEN existirem banners/destaques THE SYSTEM SHALL incluir seção `"banners"` com array de itens: `{ id, title, image_url, link_url, order }`
- IF não houver conteúdo online THE SYSTEM SHALL retornar `200` com `"videos": []` e `"banners": []`
- THE SYSTEM SHALL ordenar vídeos e banners por campo `order`
- WHEN cache disponível THE SYSTEM SHALL cachear por 10 minutos (conteúdo online muda com baixa frequência)

### RF-02: Compatibilidade com `/onlinevideos`

**Critérios de Aceite:**
- THE SYSTEM SHALL manter a rota `/onlinevideos` existente sem alterações (backward compatible)
- THE SYSTEM SHALL usar a mesma fonte de dados (tabela `online_videos`) mas com shape diferente

## 3. Requisitos Não-Funcionais

| Categoria | Requisito | Métrica |
|-----------|-----------|---------|
| Performance | Latência P95 | < 150ms |
| Cache | Redis 10 min | `collections.{lang}.online` |
| Segurança | Pública, sem JWT | Apenas Api-Token |
| Compatibilidade | Não alterar `/onlinevideos` | - |
| Cobertura | Smoke test verificando shape | PHPUnit |

## 4. Fora de Escopo

- Conteúdo offline / baixado (não é "online")
- Segmentação por usuário (futuro)
- A/B testing de banners (futuro)
- Scheduler de expiração de banner (usa campo `expires_at` se existir, mas não implementa scheduler)

## 5. Dependências

### Técnicas
- Tabela `online_videos` (já acessada por `OnlineVideosController`)
- `App\Helpers\Data`

### Blocadores
- **F1-T2**: Confirmar schema da tabela `online_videos` — quais campos existem (title, url, thumbnail, type, order, expires_at?). Necessário inspecionar migration/model antes de implementar.

## 6. Arquitetura

```
Cliente → GET /{lang}/collections/online
         → LangMiddleware
         → CollectionController@online($request)
           → OnlineVideo::where('id_language', $id_language)
                          ->where('active', true)
                          ->orderBy('order')
                          ->get()
           → particionar por type (video vs banner)
           → montar estrutura { videos: [], banners: [] }
         → JSON 200
```

## 7. Implementação

**Novo controller** `CollectionController` (ou método em controller existente se fizer sentido).

Lógica:
1. Buscar registros de `online_videos` ativos para o idioma
2. Particionar por `type` (ou campo equivalente) em `videos` e `banners`
3. Mapear campos para o shape de resposta

**Rota:** `routes/web.php` dentro do grupo `{lang}`:
```php
$router->get('/collections/online', 'CollectionController@online');
```

## 8. Riscos

| Risco | Probabilidade | Impacto | Mitigação |
|-------|--------------|---------|-----------|
| Schema de `online_videos` não tem campo `type` | Média | Médio | F1-T2 inspeciona schema; se não tiver, particionar por outro campo ou adicionar |
| Campo `expires_at` não existe | Média | Baixo | Filtro de expiração vira opcional |
| Conteúdo online volumoso | Baixa | Baixo | Cache 10min + paginação futura |

## 9. Critério de Pronto

- [ ] Schema de `online_videos` confirmado (F1-T2)
- [ ] `CollectionController@online()` implementado
- [ ] Rota registrada
- [ ] OpenAPI annotation com schema de resposta
- [ ] Smoke test: `GET /pt/collections/online` retorna 200 com `{ videos, banners }`
- [ ] Rota `/onlinevideos` original não quebrada
- [ ] Cache de 10 min configurado
- [ ] PR < 50 linhas
- [ ] Code review aprovado (Mayco)

## 10. Change Log

| Data | Autor | Mudança |
|------|-------|---------|
| 2026-07-04 | Rafael Zendron | Versão inicial |
