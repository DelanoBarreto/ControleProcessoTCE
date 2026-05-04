# ControleProcessoTCE — Painel Administrativo

> Sistema de gestão de Controle de Processos do TCE construído com Next.js, Supabase e Padrão V4 Elite.

## 🚀 Quick Start (< 5 minutos)

```bash
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
```

## 📦 Módulos Disponíveis

| Módulo | Rota | Descrição |
| :--- | :--- | :--- |
| **Processos** | `/admin/processos` | Gestão de processos do TCE, responsáveis, status e prazos. |
| **Clientes/Entidades** | `/admin/entidades` | Gestão das entidades vinculadas aos processos. |
| **Prazos e Tarefas** | `/admin/prazos` | Controle de prazos e tarefas de auditoria/defesa. |
| **Usuários** | `/admin/usuarios` | Gestão de perfis de acesso do painel. |

## 🛠️ Stack
- Next.js 14+ + TypeScript + Tailwind CSS
- Supabase (PostgreSQL + Auth + Storage)
- TanStack Query + Framer Motion + Lucide React

## 🤖 Desenvolvimento com IA
Este projeto usa o Antigravity Kit. Leia `.agent/` e `docs/PADRAO_V4_ELITE.md` antes de codar.
