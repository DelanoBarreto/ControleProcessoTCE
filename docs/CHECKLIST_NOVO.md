# Checklist de Início de Projeto (ControleProcessoTCE)

Use este checklist para validar as implementações no novo projeto:

## Fase 0 — Preparação
- [x] Novo repositório/pasta criada: `C:\Antigravity\ControleProcessoTCE\`
- [ ] `npx create-next-app@latest ./ --typescript --tailwind --app --src-dir` executado
- [ ] Dependências instaladas (`@supabase/supabase-js`, `@tanstack/react-query`, `lucide-react`, `framer-motion`)
- [ ] `.env.local` criado com as variáveis do Supabase
- [ ] `.env.example` criado (sem segredos) e commitado
- [x] Pasta `.agent/` copiada do PortalGov para o novo projeto

## Fase 1 — Design System
- [ ] `tailwind.config.ts` atualizado com os tokens de cor V4 Elite
- [ ] Fonte Inter importada no `layout.tsx` (Google Fonts)
- [ ] `globals.css` com variáveis CSS base
- [ ] Nenhuma cor roxa/violeta usada em qualquer arquivo

## Fase 2 — Banco de Dados
- [ ] Projeto Supabase criado (ou usar o existente)
- [ ] Tabelas criadas com os campos base (id, created_at, updated_at, status, created_by)
- [ ] Trigger `update_updated_at_column` aplicado em todas as tabelas
- [ ] RLS habilitado em todas as tabelas
- [ ] Bucket de Storage criado (se houver upload de arquivos)
- [ ] `MODELAGEM_DADOS.md` preenchido com o schema real do projeto

## Fase 3 — Estrutura de Código
- [ ] `middleware.ts` configurado para proteger rotas `/admin`
- [ ] Clientes Supabase (`client.ts` e `server.ts`) configurados
- [ ] Componentes UI base copiados do PortalGov (`DataTableV2`, `ConfirmDeleteModal`, etc.)
- [ ] Hooks copiados (`useIsDirty`, `useWarnIfUnsaved`)
- [ ] Sidebar configurada com os módulos do novo domínio

## Fase 4 — Primeiro Módulo CRUD
- [ ] Tela de Listagem (`page.tsx`) com tabela, filtros e bulk actions
- [ ] Tela de Criação (`new/page.tsx`) com formulário dual-column
- [ ] Tela de Edição (`[id]/edit/page.tsx`) com fluxo `isDirty` completo
- [ ] Modal de Confirmação de Exclusão implementado (sem `window.confirm()`)
- [ ] Storage cleanup implementado (se o módulo tiver arquivos)
- [ ] Paginação funcionando

## Fase 5 — Verificação Final
- [ ] `npm run lint` passou sem erros
- [ ] `npm run build` passou sem erros
- [ ] Fluxo isDirty testado manualmente
- [ ] beforeunload testado
- [ ] Deleção com limpeza de storage testada manualmente
- [ ] Sidebar bloqueada em rotas `/edit` e `/new`
