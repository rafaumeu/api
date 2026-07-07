# SPEC: HymnalController@show — Buscar hino por ID

> **Status:** Draft
> **Author:** Rafael Zendron (rafaumeu)
> **Created:** 2026-07-04
> **RF-ID:** F1-T3 (PLAN.md)
> **Referência:** SPEC.md §1.4, RF-008

## 1. Contexto

O `HymnalController` atualmente só tem o método `index()`, que lista todos os hinários. Não existe `show()` nem rota pública para buscar um hino específico por ID. O Diego (@Ajegado) precisa acessar hinos individuais do hinário via API para deep linking e reprodução direta no app.

## 2. Requisitos Funcionais

### RF-01: Método `show()` no HymnalController

**User Story:**
> Como app cliente, quero buscar um hino específico do hinário por ID, para exibir/reproduzir diretamente sem precisar listar todos.

**Critérios de Aceite (EARS):**
- WHEN o cliente faz `GET /{lang}/hymnal/{id}` THE SYSTEM SHALL retornar o hino correspondente ao `id_music` com todos os campos do `index()` (id, name, track, urls de imagem/áudio/ instrumental, versions)
- IF o `id` não corresponder a nenhum hino do hinário THE SYSTEM SHALL retornar `404` com `{"error": "Not found"}`
- IF o `id` não for numérico THE SYSTEM SHALL retornar `404` (Lumen route binding)
- WHEN o `lang` informado não existir THE SYSTEM SHALL retornar `404` (LangMiddleware)

## 3. Requisitos Não-Funcionais

| Categoria | Requisito | Métrica |
|-----------|-----------|---------|
| Performance | Latência P95 | < 100ms |
| Cache | Não aplicável (single record) | - |
| Segurança | Rota pública, sem JWT | Apenas Api-Token |
| Compatibilidade | Backward compatible | Nova rota, não afeta existentes |
| Cobertura | Testes PHPUnit | Smoke test mínimo |

## 4. Fora de Escopo

- Busca por número de hino (track) ao invés de ID (futuro)
- Filtro por hinário específico (Cantor Cristão vs Adventista 1996)
- Cache da resposta individual

## 5. Dependências

### Técnicas
- Laravel Lumen (PHP 8.3)
- `App\Helpers\Data` (já usado no `index()`)
- `App\Models\Music`

### Blocadores
- Nenhum

## 6. Arquitetura

```
Cliente → GET /{lang}/hymnal/{id}
         → LangMiddleware (extrai id_language)
         → HymnalController@show
           → Music::select(...)->where('id_music', $id)
                              ->where('categories.slug', 'hymnal')
                              ->where('musics.id_language', $id_language)
                              ->firstOrFail()
         → JSON 200 | 404
```

## 7. Implementação

**Arquivo:** `app/Http/Controllers/HymnalController.php`

Adicionar método `show(Request $request, $id)` reaproveitando a query do `index()` com `->where('musics.id_music', $id)->firstOrFail()`.

**Rota:** `routes/web.php` — dentro do grupo `{lang}`:
```php
$router->get('/hymnal/{id}', 'HymnalController@show');
```

## 8. Riscos

| Risco | Probabilidade | Impacto | Mitigação |
|-------|--------------|---------|-----------|
| ID existe em músicas mas não no hinário | Baixa | Baixo | Filtro duplo: id_music + slug='hymnal' |
| Conflito de rota com `/hymnal` | Baixa | Baixo | Lumen distingue `/hymnal` de `/hymnal/{id}` |

## 9. Critério de Pronto

- [ ] Método `show()` implementado
- [ ] Rota registrada em `routes/web.php`
- [ ] OpenAPI annotation `#[OA\Get(path: '/{lang}/hymnal/{id}')]` adicionada
- [ ] Smoke test: `GET /pt/hymnal/1` retorna 200 com dados
- [ ] Smoke test: `GET /pt/hymnal/999999` retorna 404
- [ ] PR < 20 linhas
- [ ] Code review aprovado (Mayco)

## 10. Change Log

| Data | Autor | Mudança |
|------|-------|---------|
| 2026-07-04 | Rafael Zendron | Versão inicial |
