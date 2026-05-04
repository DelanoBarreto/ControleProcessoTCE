# 🧬 Template de Bootstrap — Novo Sistema Administrativo
> **DNA do Padrão V4 Elite | Versão 1.0 | Maio 2026**
>
> Este é o ponto de partida obrigatório para qualquer **novo sistema** criado a partir do ecossistema PortalGov.
> Todo agente de IA e desenvolvedor humano deve ler este arquivo **antes de criar qualquer pasta, arquivo ou banco de dados**.

---

## 📌 1. Contexto e Origem deste Template

Este template foi criado a partir do **PortalGov ExtracaoDadosPortalWeb_V2**, um sistema administrativo completo com os seguintes módulos implementados e validados em produção:

| Módulo | Telas | Complexidade |
| :--- | :--- | :--- |
| **Notícias** | Listagem, Criação, Edição com Rich Text e Upload de Imagem | Alta |
| **Secretarias** | Listagem, Criação, Edição com CNPJ e Horários | Média |
| **Portarias** | Listagem, Edição com Gerenciador de PDFs | Alta |
| **LRF** | Listagem, Edição com Múltiplos Documentos Fiscais | Alta |
| **PCG** | Listagem, Edição com Prestação de Contas | Alta |
| **Gestores** | Listagem, Edição com Foto e Cargo | Média |
| **Municípios** | Gerenciamento de Tenants | Baixa |
| **Login Admin** | Split-panel, Supabase Auth | Baixa |

### 🔑 O que o novo sistema HERDA
- Todo o layout (cores, tipografia, grid, bordas, sombras)
- Todos os componentes UI (tabelas, formulários, modais, badges, toasts)
- Todos os hooks e padrões de segurança de dados (`isDirty`, `isNavigatingAway`)
- Toda a arquitetura de autenticação e proteção de rotas
- Toda a lógica de Storage Cleanup ao excluir registros

### 🔄 O que o novo sistema SUBSTITUI
- Os campos e tabelas específicos do domínio (Notícias → Processos, Secretarias → Clientes, etc.)
- O nome da aplicação e o logo/identidade visual
- O esquema de banco de dados (novas tabelas para o novo domínio)
- Os módulos e itens do menu lateral (Sidebar)

---

## 🏗️ 2. Stack de Tecnologia (Padrão Fixo)

> ⚠️ **Regra:** Não mudar esta stack sem uma justificativa arquitetural documentada em um ADR.

| Camada | Tecnologia | Versão Mínima | Justificativa |
| :--- | :--- | :--- | :--- |
| **Framework** | Next.js (App Router) | 14+ | SSR/SSG, roteamento de arquivos, layouts aninhados |
| **Linguagem** | TypeScript | 5+ | Tipagem obrigatória para projetos críticos |
| **Estilização** | Tailwind CSS | 3.4+ | Utilitários, design tokens configuráveis |
| **Banco de Dados** | Supabase (PostgreSQL) | — | Auth integrado, Storage, RLS por Row Level Security |
| **Estado do Servidor** | TanStack Query (React Query) | 5+ | Cache, invalidação e mutações com estados de loading |
| **Ícones** | Lucide React | latest | Regra de Ouro #1: Nunca emojis como ícones |
| **Animações** | Framer Motion | 10+ | Modais, transições de cards, micro-animações |
| **Rich Text** | TipTap | 2+ | Apenas para módulos com conteúdo editorial |
| **Linting** | ESLint + Prettier | — | Obrigatório desde o commit 1 |
| **Testes E2E** | Playwright | — | Ativado antes do primeiro deploy |

### Dependências de Instalação (comando único)
```bash
npm install @supabase/supabase-js @tanstack/react-query lucide-react framer-motion
npm install -D @types/node typescript eslint prettier
```

---

## 🎨 3. Design System (Tokens Obrigatórios)

> 🔴 **Proibição absoluta:** Nunca use tons de roxo/violeta em nenhum componente.

### 3.1 Paleta de Cores (tailwind.config.ts)

```ts
// tailwind.config.ts — extensão da paleta de cores padrão
colors: {
  'city-hall-blue':   '#004c99',   // Cor primária (botão Salvar, acentos)
  'city-hall-accent': '#004c99',   // Idêntico — alias semântico
  'bg-main':          '#f8f9fc',   // Fundo do dashboard
  'border-color':     '#e2e8f0',   // Bordas de cards e inputs
  'text-primary':     '#1a202c',   // Texto base
}
```

### 3.2 Tipografia
- **Fonte:** Inter (Google Fonts) — sem fontes nativas do navegador
- **Hierarquia de Títulos:**
  - `h1` de listagem: `text-[22px] font-black text-slate-900 tracking-tight`
  - `h2` de formulário: `text-xl font-black text-slate-900 tracking-tight`
  - Labels: `text-[13px] font-semibold text-slate-700`
  - Metadados: `text-[11px] font-bold text-slate-400 uppercase`

### 3.3 Tokens de Forma
- Raio de borda padrão: `rounded-xl` (12px)
- Raio de modal: `rounded-[32px]`
- Sombra de card: `shadow-[0_1px_3px_rgba(0,0,0,0.05)]`
- Sombra de botão primário: `shadow-lg shadow-blue-100`

---

## 📁 4. Estrutura de Arquivos do Novo Projeto

Ao criar um novo projeto, **replicar exatamente esta estrutura**:

```
[nome-do-sistema]/
├── .agent/                          # Regras e agentes de IA (COPIAR do PortalGov)
│   ├── agents/
│   ├── skills/
│   ├── scripts/
│   └── workflows/
├── docs/                            # Documentação do projeto (CRIAR DO ZERO)
│   ├── README.md                    # ← Preencher conforme Seção 5
│   ├── ARQUITETURA.md               # ← Preencher conforme Seção 6
│   ├── COMANDOS.md                  # ← Preencher conforme Seção 7
│   ├── PADRAO_V4_ELITE.md           # ← COPIAR do PortalGov (sem modificar)
│   ├── CHECKLIST_NOVO.md            # ← Preencher conforme Seção 9
│   └── MODELAGEM_DADOS.md           # ← Preencher conforme Seção 8
├── src/
│   └── app/
│       ├── (admin)/
│       │   ├── layout.tsx           # Layout com Sidebar + Header
│       │   ├── dashboard/
│       │   │   └── page.tsx
│       │   └── [modulo]/            # Um por entidade (ex: clientes/)
│       │       ├── page.tsx         # Listagem
│       │       ├── new/
│       │       │   └── page.tsx     # Criação
│       │       └── [id]/
│       │           └── edit/
│       │               └── page.tsx # Edição
│       ├── login/
│       │   └── page.tsx
│       └── layout.tsx               # Root layout (fonts, providers)
├── src/
│   ├── components/
│   │   ├── ui/                      # Componentes genéricos (COPIAR do PortalGov)
│   │   │   ├── DataTableV2.tsx
│   │   │   ├── BulkActionDropdown.tsx
│   │   │   ├── ConfirmDeleteModal.tsx
│   │   │   ├── StatusBadge.tsx
│   │   │   └── Toast.tsx
│   │   └── admin/                   # Componentes de layout (COPIAR do PortalGov)
│   │       ├── Sidebar.tsx
│   │       ├── AdminHeader.tsx
│   │       └── DashboardCard.tsx
│   ├── hooks/                       # Hooks reutilizáveis (COPIAR do PortalGov)
│   │   ├── useIsDirty.ts            # Proteção de formulários
│   │   └── useWarnIfUnsaved.ts      # beforeunload listener
│   ├── lib/
│   │   ├── supabase/
│   │   │   ├── client.ts            # Cliente browser
│   │   │   └── server.ts            # Cliente server (SSR/API)
│   │   └── utils.ts
│   └── types/
│       └── index.ts                 # Tipos globais + tipos do domínio
├── middleware.ts                    # Proteção de rotas /admin
├── next.config.ts
├── tailwind.config.ts               # ← COPIAR + ajustar tokens se necessário
├── tsconfig.json
└── package.json
```

---

## 📄 5. Conteúdo do README.md (Modelo)

```markdown
# [Nome do Sistema] — Painel Administrativo

> Sistema de gestão [domínio] construído com Next.js, Supabase e Padrão V4 Elite.

## 🚀 Quick Start (< 5 minutos)

\`\`\`bash
# 1. Clonar o repositório
git clone [url] && cd [pasta]

# 2. Instalar dependências
npm install

# 3. Configurar variáveis de ambiente
cp .env.example .env.local
# Preencher NEXT_PUBLIC_SUPABASE_URL e NEXT_PUBLIC_SUPABASE_ANON_KEY

# 4. Rodar localmente
npm run dev
# Acesse: http://localhost:3000/admin/login
\`\`\`

## 📦 Módulos Disponíveis

| Módulo | Rota | Descrição |
| :--- | :--- | :--- |
| [Listar aqui os módulos do sistema] | | |

## 🛠️ Stack
- Next.js 14 + TypeScript + Tailwind CSS
- Supabase (PostgreSQL + Auth + Storage)
- TanStack Query + Framer Motion + Lucide React

## 🤖 Desenvolvimento com IA
Este projeto usa o Antigravity Kit. Leia `.agent/` e `docs/PADRAO_V4_ELITE.md` antes de codar.
```

---

## 🏛️ 6. Conteúdo do ARQUITETURA.md (Modelo)

```markdown
# Arquitetura do Sistema

## Tipo de Projeto
WEB — Next.js App Router (SSR + Client Components)

## Diagrama de Camadas

\`\`\`
[Browser] → [Next.js App Router] → [Supabase Client/Server]
                                         ↓
                              [PostgreSQL] + [Storage] + [Auth]
\`\`\`

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
- Listagem: `src/app/(admin)/[primeiro-modulo]/page.tsx`
- Edição: `src/app/(admin)/[primeiro-modulo]/[id]/edit/page.tsx`
- Design: `docs/PADRAO_V4_ELITE.md`
```

---

## 🗄️ 8. Modelagem de Dados (MODELAGEM_DADOS.md)

### 8.1 Schema Base (Todo Módulo CRUD)

Toda tabela de conteúdo gerenciável **deve ter estes campos**:

```sql
-- Campos obrigatórios em TODA tabela do sistema
id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
created_at   timestamptz NOT NULL DEFAULT now(),
updated_at   timestamptz NOT NULL DEFAULT now(),
created_by   uuid        REFERENCES auth.users(id),
status       text        NOT NULL DEFAULT 'rascunho'
                         CHECK (status IN ('rascunho', 'publicado', 'arquivado')),

-- Adicionar conforme o sistema:
-- tenant_id / escritorio_id / empresa_id  → para sistemas multi-tenant
-- [campos_do_dominio]                      → específicos do módulo
```

### 8.2 Trigger Automático de updated_at

```sql
-- Rodar UMA VEZ no Supabase SQL Editor (vale para todas as tabelas)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Aplicar para cada tabela:
CREATE TRIGGER set_updated_at
BEFORE UPDATE ON [nome_da_tabela]
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### 8.3 Row Level Security (RLS) — Padrão

```sql
-- Habilitar RLS em toda tabela
ALTER TABLE [nome_da_tabela] ENABLE ROW LEVEL SECURITY;

-- Política básica: usuários autenticados leem tudo
CREATE POLICY "Autenticados podem ler" ON [nome_da_tabela]
FOR SELECT TO authenticated USING (true);

-- Política básica: usuários autenticados podem criar
CREATE POLICY "Autenticados podem criar" ON [nome_da_tabela]
FOR INSERT TO authenticated WITH CHECK (auth.uid() = created_by);

-- Política básica: quem criou pode editar
CREATE POLICY "Autor pode editar" ON [nome_da_tabela]
FOR UPDATE TO authenticated USING (auth.uid() = created_by);
```

### 8.4 Limpeza de Storage ao Deletar

```ts
// PADRÃO OBRIGATÓRIO — sempre que houver arquivos associados ao registro
async function deleteRecord(id: string) {
  // 1. Buscar URLs ANTES de deletar
  const { data: record } = await supabase
    .from('tabela')
    .select('foto_url, arquivo_url')
    .eq('id', id)
    .single();

  // 2. Extrair paths do storage
  const paths = [record?.foto_url, record?.arquivo_url]
    .filter(Boolean)
    .map(url => url.split('/storage/v1/object/public/[bucket]/')[1]);

  // 3. Deletar arquivos do storage
  if (paths.length > 0) {
    await supabaseAdmin.storage.from('[bucket]').remove(paths);
  }

  // 4. Deletar o registro do banco
  await supabase.from('tabela').delete().eq('id', id);
}
```

---

## ✅ 9. Checklist de Início de Projeto (CHECKLIST_NOVO.md)

Use este checklist antes de escrever a primeira linha de código do novo sistema:

### Fase 0 — Preparação
- [ ] Novo repositório Git criado no GitHub
- [ ] Pasta do projeto criada: `c:\Antigravity\[NomeDoProjeto]\`
- [ ] `npx create-next-app@latest ./ --typescript --tailwind --app --src-dir` executado
- [ ] Dependências instaladas (`supabase-js`, `tanstack-query`, `lucide-react`, `framer-motion`)
- [ ] `.env.local` criado com as variáveis do Supabase
- [ ] `.env.example` criado (sem segredos) e commitado
- [ ] Pasta `.agent/` copiada do PortalGov para o novo projeto

### Fase 1 — Design System
- [ ] `tailwind.config.ts` atualizado com os tokens de cor V4 Elite
- [ ] Fonte Inter importada no `layout.tsx` (Google Fonts)
- [ ] `globals.css` com variáveis CSS base
- [ ] Nenhuma cor roxa/violeta usada em qualquer arquivo

### Fase 2 — Banco de Dados
- [ ] Projeto Supabase criado (ou usar o existente)
- [ ] Tabelas criadas com os campos base (id, created_at, updated_at, status, created_by)
- [ ] Trigger `update_updated_at_column` aplicado em todas as tabelas
- [ ] RLS habilitado em todas as tabelas
- [ ] Bucket de Storage criado (se houver upload de arquivos)
- [ ] `MODELAGEM_DADOS.md` preenchido com o schema real do projeto

### Fase 3 — Estrutura de Código
- [ ] Estrutura de pastas criada (conforme Seção 4 deste documento)
- [ ] `middleware.ts` configurado para proteger rotas `/admin`
- [ ] Clientes Supabase (`client.ts` e `server.ts`) configurados
- [ ] Componentes UI base copiados do PortalGov (`DataTableV2`, `ConfirmDeleteModal`, etc.)
- [ ] Hooks copiados (`useIsDirty`, `useWarnIfUnsaved`)
- [ ] Sidebar configurada com os módulos do novo domínio

### Fase 4 — Primeiro Módulo CRUD
- [ ] Tela de Listagem (`page.tsx`) com tabela, filtros e bulk actions
- [ ] Tela de Criação (`new/page.tsx`) com formulário dual-column
- [ ] Tela de Edição (`[id]/edit/page.tsx`) com fluxo `isDirty` completo
- [ ] Modal de Confirmação de Exclusão implementado (sem `window.confirm()`)
- [ ] Storage cleanup implementado (se o módulo tiver arquivos)
- [ ] Paginação funcionando

### Fase 5 — Verificação Final
- [ ] `npm run lint` passou sem erros
- [ ] `npm run build` passou sem erros
- [ ] Fluxo isDirty testado manualmente (editar → tentar sair → deve bloquear)
- [ ] beforeunload testado (editar → F5 → deve perguntar)
- [ ] Deleção com limpeza de storage testada manualmente
- [ ] Sidebar bloqueada em rotas `/edit` e `/new`
- [ ] Responsividade testada em 1280px e 1920px

---

## 🧠 10. Instruções para o Agente de IA (Contexto da Nossa Conversa)

> **Este bloco é para o agente lembrar das decisões estratégicas tomadas em 03/05/2026.**

### Decisões de Arquitetura Confirmadas

1. **Reuso do Padrão V4 Elite:** O novo sistema herda **100% do layout e dos comportamentos** do PortalGov. Cores, grid dual-column, fluxo isDirty, header sticky, modais de confirmação — tudo é idêntico.

2. **Separação de Campos vs. Estilo:** O que muda entre sistemas é apenas o **domínio** (campos, tabelas, módulos, nome). O que permanece é tudo de **design e comportamento**.

3. **Abordagem de Boilerplate:** Para criar um novo sistema, o agente deve:
   - Copiar a estrutura de componentes base do PortalGov
   - Criar novas páginas CRUD seguindo exatamente a estrutura de `secretarias/[id]/edit/page.tsx` como referência canônica
   - Criar as tabelas Supabase com o schema padrão da Seção 8

4. **Proibições absolutas (Regras de Ouro — nunca violar):**
   - Jamais usar `alert()` ou `confirm()` nativo
   - Jamais usar emojis como ícones (usar exclusivamente Lucide)
   - Jamais usar cores roxas/violetas
   - Jamais usar formulários em modais para dados complexos (usar páginas dedicadas)
   - Jamais deletar do banco sem limpar o Storage primeiro
   - Jamais usar `transition: all` no CSS

5. **Referências Canônicas de Código (PortalGov):**
   - Listagem: `c:\Antigravity\ExtracaoDadosPortalWeb_V2\portal-admin\src\app\(admin)\noticias\page.tsx`
   - Edição: `c:\Antigravity\ExtracaoDadosPortalWeb_V2\portal-admin\src\app\(admin)\secretarias\[id]\edit\page.tsx`
   - Componentes: `c:\Antigravity\ExtracaoDadosPortalWeb_V2\portal-admin\src\components\`

### Como Criar um Novo Módulo CRUD (Receita Rápida)

Quando o usuário pedir para criar um novo módulo (ex: "Processos", "Clientes"), o agente deve:

1. **Perguntar quais são os campos do módulo** (nome, tipo, obrigatório, coluna onde ficará)
2. **Gerar o SQL da tabela** seguindo o schema base da Seção 8
3. **Criar os 3 arquivos de rota:**
   - `[modulo]/page.tsx` → Listagem com tabela e filtros
   - `[modulo]/new/page.tsx` → Formulário de criação
   - `[modulo]/[id]/edit/page.tsx` → Formulário de edição com isDirty
4. **Atualizar o Sidebar** para incluir o novo módulo
5. **Adicionar os tipos TypeScript** em `src/types/index.ts`

### Campos de Formulário por Tipo de Dado

| Tipo | Componente | Coluna do Grid |
| :--- | :--- | :--- |
| Texto curto (nome, título) | `<input type="text">` | Principal |
| Texto longo (descrição, obs) | `<textarea>` | Principal |
| Conteúdo editorial (HTML) | TipTap Editor | Principal |
| Data | `<input type="date">` | Principal ou Lateral |
| Select (status, categoria) | `<select>` | Lateral |
| Upload de imagem (foto, capa) | DropZone aspect-square | Lateral |
| Upload de PDF | Tabela gerenciável | Principal |
| ID do registro (readonly) | Texto desabilitado | Lateral |
| Botão de exclusão | Rodapé da Coluna Lateral | Lateral |

---

## 📝 11. Documentos que o Novo Projeto Precisa Ter

| Arquivo | Localização | Origem | Ação |
| :--- | :--- | :--- | :--- |
| `README.md` | `docs/` | Template Seção 5 | Criar e preencher |
| `ARQUITETURA.md` | `docs/` | Template Seção 6 | Criar e preencher |
| `COMANDOS.md` | `docs/` | Copiar do PortalGov | Copiar e adaptar |
| `PADRAO_V4_ELITE.md` | `docs/` | PortalGov | Copiar **sem modificar** |
| `CHECKLIST_NOVO.md` | `docs/` | Template Seção 9 | Criar e usar |
| `MODELAGEM_DADOS.md` | `docs/` | Template Seção 8 | Criar e preencher |
| `TEMPLATE_NOVO_SISTEMA.md` | `docs/` | Este arquivo | Copiar **sem modificar** |
| `.agent/` (pasta inteira) | raiz do projeto | PortalGov | Copiar inteira |
| `tailwind.config.ts` | raiz | PortalGov | Copiar e adaptar tokens |
| `middleware.ts` | raiz | PortalGov | Copiar e adaptar rotas |
| `.env.example` | raiz | — | Criar (sem segredos) |

---

## 🚦 12. Fluxo de Onboarding para Novo Projeto (Passo a Passo)

```
PASSO 1: Criar pasta e inicializar Next.js
    └── npx create-next-app@latest ./ --typescript --tailwind --app --src-dir

PASSO 2: Copiar o "Core V4 Elite" do PortalGov
    └── .agent/ (pasta inteira)
    └── docs/PADRAO_V4_ELITE.md
    └── docs/TEMPLATE_NOVO_SISTEMA.md
    └── tailwind.config.ts (e adaptar tokens se necessário)
    └── src/components/ui/ (DataTableV2, ConfirmDeleteModal, etc.)
    └── src/hooks/ (useIsDirty, useWarnIfUnsaved)

PASSO 3: Preencher a documentação do novo domínio
    └── docs/README.md
    └── docs/ARQUITETURA.md
    └── docs/MODELAGEM_DADOS.md (schema das novas tabelas)
    └── docs/CHECKLIST_NOVO.md (marcar o que já foi feito)

PASSO 4: Criar o banco de dados no Supabase
    └── Novas tabelas com schema base (Seção 8)
    └── Triggers de updated_at
    └── RLS habilitado
    └── Buckets de Storage (se necessário)

PASSO 5: Construir o Layout Admin
    └── Sidebar com os módulos do novo domínio
    └── AdminHeader
    └── Rota de login
    └── middleware.ts configurado

PASSO 6: Construir os CRUDs (módulo a módulo)
    └── Para cada entidade: Listagem → Criação → Edição

PASSO 7: Verificação Final
    └── Usar CHECKLIST_NOVO.md (Seção 9)
    └── npm run lint && npm run build
```

---

## 🔖 Referência Rápida — Arquivos Modelo no PortalGov

> 💡 Sempre que tiver dúvida sobre COMO implementar algo, abra estes arquivos como referência:

| O que implementar | Arquivo de referência |
| :--- | :--- |
| **Tela de listagem** com tabela, filtros, bulk actions | `portal-admin/src/app/(admin)/noticias/page.tsx` |
| **Tela de edição** com dual-column, isDirty, header sticky | `portal-admin/src/app/(admin)/secretarias/[id]/edit/page.tsx` |
| **Módulo com upload de PDF** gerenciável | `portal-admin/src/app/(admin)/pcg/[id]/edit/page.tsx` |
| **Modal de confirmação de exclusão** | `portal-admin/src/components/ui/ConfirmDeleteModal.tsx` |
| **Componente de tabela** com seleção e paginação | `portal-admin/src/components/ui/DataTableV2.tsx` |
| **Hook de proteção** de formulário | `portal-admin/src/hooks/useIsDirty.ts` |
| **Autenticação** e split-panel de login | `portal-admin/src/app/login/page.tsx` |
| **Sidebar** com bloqueio em `/edit` e `/new` | `portal-admin/src/components/admin/Sidebar.tsx` |

---

*Documento gerado em 03/05/2026 com base no ecossistema PortalGov V4 Elite.*
*Mantido por: Delano Barreto | Antigravity Kit*
