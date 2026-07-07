# CONTEXT — LouvorJA API

## Handoff

Esta documentação foi gerada em 2026-07-01 como parte do SDD (Spec-Driven Development) completo para o `louvorja/api`.

### Objetivo
Mapear a API inteira, documentar gaps/bugs, planejar correções e novos endpoints solicitados pelo Diego, e criar guia para futuros devs.

### Status Atual
- 31 endpoints públicos (sem JWT)
- 27 endpoints admin (com JWT + access control)
- 8 tasks administrativas
- 21 tabelas no banco
- 22 controllers
- 11 middlewares
- 80+ testes PHPUnit (199+ assertions)
- 9 PRs abertos aguardando Mayco

### O que resolver primeiro
1. F1-T1: Popular `type` nas categorias Doxologia e Infantis (dados)
2. F2-T1 a F2-T4: Endpoints que o Diego pediu (Doxologia, Kids, Coletâneas Online)
3. F3-T1: Melhorar manifest com metadados (versão, data, tamanho)

### O que NÃO fazer
- ❌ Não mexer em bootstrap/app.php (múltiplas PRs conflitam)
- ❌ Não sugerir CI/CD para louvorja/api (Mayco não usa)
- ❌ Não criar PR grande (> 50 linhas)
- ❌ Não enviar mensagem no Telegram sem comando explícito

### Arquivos criados
- `SPEC.md` — Especificação completa (baseline, bugs, features, NFs, fora de escopo)
- `PLAN.md` — Plano de implementação em 5 fases, 16 tasks
- `AGENTS.md` — Guia para agentes de AI e devs novos
- `CONTEXT.md` — Este arquivo (resumo para handoff)

### Skills carregadas
- `spec-driven-development` — Metodologia SDD
- `project-excellence` — Quality gates, RF-IDs
- `louvorja-api` — Conhecimento de domínio da API
- `louvorja-chatbot-knowledge` — Contexto adicional do LouvorJA
- `github-pr-workflow` — Fluxo de PR com fork

### Próximos passos sugeridos
1. Revisar SPEC.md com o Diego/Mayco
2. Executar F1-T1 (popular dados de categorias)
3. Implementar F2-T1 a F2-T4 (endpoints públicos faltantes)
4. Mergar PRs abertos (#6, #27)
5. Rodar testes de regressão