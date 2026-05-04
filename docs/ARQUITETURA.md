# Arquitetura do Sistema - ControleProcessoTCE

## Tipo de Projeto
WEB — Next.js App Router (SSR + Client Components)

## Diagrama de Camadas

```
[Browser] → [Next.js App Router] → [Supabase Client/Server]
                                         ↓
                              [PostgreSQL] + [Storage] + [Auth]
```

## Padrões Obrigatórios
1. Formulários → Padrão V4 Elite (dual-column, isDirty, header sticky)
2. Listagens → DataTableV2 com status tabs, bulk actions, paginação
3. Deleção → Storage cleanup ANTES do delete no banco
4. Cache → invalidateQueries após toda mutação

## Agentes de IA Disponíveis
- `@frontend-specialist` — UI, componentes, design
- `@backend-specialist` — API routes, lógica de servidor
- `@database-architect` — Schema SQL, migrations
- `@security-auditor` — RLS, validações, autenticação

## Referência Canônica de Código
- Design: `docs/PADRAO_V4_ELITE.md`
- Templates: `docs/TEMPLATE_NOVO_SISTEMA.md`
