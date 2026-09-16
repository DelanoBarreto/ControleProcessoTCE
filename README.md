# Plataforma TCE — Monitoramento e Gestão de Processos

Monitora automaticamente processos do Tribunal de Contas do Estado do Ceará (TCE-CE), detecta movimentações relevantes e avisa gestores públicos e escritórios jurídicos por WhatsApp e e-mail.

> **Status:** 🚧 MVP em desenvolvimento — fase pré-código. A documentação abaixo reflete decisões tomadas e a investigação técnica já validada contra a API real do TCE.

---

## Índice

| Documento | Conteúdo |
| :--- | :--- |
| [docs/ARQUITETURA.md](docs/ARQUITETURA.md) | Camadas, fluxo de dados, decisões técnicas |
| [docs/MODELAGEM_DADOS.md](docs/MODELAGEM_DADOS.md) | Schema completo com RLS |
| [docs/API_TCE.md](docs/API_TCE.md) | Endpoints da API do TCE-CE (referência técnica) |
| [docs/CONSOLE_INTERNO.md](docs/CONSOLE_INTERNO.md) | Console de operação (`/interno/*`) |
| [docs/CONFORMIDADE.md](docs/CONFORMIDADE.md) | LGPD, ética profissional, política de coleta |
| [docs/PLANO_MVP.md](docs/PLANO_MVP.md) | Roadmap por fases + guia Vercel/Supabase |
| [docs/PADRAO_V4_ELITE.md](docs/PADRAO_V4_ELITE.md) | Padrão de UI (formulários, listagens) |

---

## Stack

- **Next.js 14+** (App Router) + TypeScript + Tailwind CSS
- **Supabase** — PostgreSQL + Auth + Storage + RLS
- **Vercel** — hospedagem + Cron Jobs (coleta agendada)
- **Resend** (e-mail) + **WhatsApp Cloud API** (notificações)
- TanStack Query · Framer Motion · Lucide React

---

## Arquitetura

```
[Vercel Cron diário]
      │
      ▼
[/api/cron/sync] ──► TceClient ──► api-processos.tce.ce.gov.br
      │                            (porLista → porNumero)
      ▼
[Supabase Postgres] ◄── diff por tramites[].id → detecta movimentação nova
      │
      ▼
[/api/cron/notify] ──► Resend (e-mail) + WhatsApp Cloud API
      │
      ▼
[Next.js App Router]
   ├── /admin/*    → Painel do Escritório (cliente pagante)
   ├── /gestor/*   → Painel do Gestor Público
   └── /interno/*  → Console de Operação (apenas is_superadmin)
```

A coleta é **por município**, não por assinante: sincronizar um município custa o mesmo com 1 ou 50 escritórios clientes.

---

## API do TCE-CE

O TCE-CE expõe uma **API REST pública, sem autenticação**, retornando JSON estruturado. **Não é necessário scraping de HTML.**

Base: `https://api-processos.tce.ce.gov.br` · Header obrigatório: `Origin: https://www.tce.ce.gov.br`

| Endpoint | Método | Retorna |
| :--- | :--- | :--- |
| `/processos/porLista` | POST | Lista paginada com filtros (localidade, espécie…) |
| `/processos/porNumero` | POST | Detalhe completo: trâmites, documentos, julgamentos, interessados |
| `/protocolos/porLista` · `/protocolos/porNumero` | POST | Idem, para protocolos |
| `/tabelas-auxiliares/localidade` | GET | 184 municípios |
| `/tabelas-auxiliares/especie` | GET | Espécies processuais |

### ⚠️ Armadilha: `numero` vs `numeros`

`porNumero` usa **`numero` (singular)**; `porLista` usa **`numeros` (plural)**. Passar o campo errado retorna `{"data":{"lista":[]}}` com **HTTP 200** — falha silenciosa, sem mensagem de erro.

### Verificar que a API responde

```bash
# Lista processos de Horizonte/CE (localidade 72)
curl -X POST "https://api-processos.tce.ce.gov.br/processos/porLista" \
  -H "Content-Type: application/json" \
  -H "Origin: https://www.tce.ce.gov.br" \
  -d '{"numeros":[],"filtros":{"localidade":["72"]},"pagina":1,"qtd":10}'

# Detalhe de um processo — note: "numero", singular
curl -X POST "https://api-processos.tce.ce.gov.br/processos/porNumero" \
  -H "Content-Type: application/json" \
  -H "Origin: https://www.tce.ce.gov.br" \
  -d '{"numero":"20909/2026-1","filtros":null,"pagina":0,"qtd":20}'

# Catálogo de municípios
curl "https://api-processos.tce.ce.gov.br/tabelas-auxiliares/localidade" \
  -H "Origin: https://www.tce.ce.gov.br"
```

Referência completa dos campos: [docs/API_TCE.md](docs/API_TCE.md).

---

## Quick Start

> Ainda não há código. Estes passos valem a partir da Fase 1 do [plano de MVP](docs/PLANO_MVP.md).

```bash
git clone https://github.com/DelanoBarreto/ControleProcessoTCE.git
cd ControleProcessoTCE

npm install

cp .env.example .env.local
# preencher as variáveis (abaixo)

npm run dev   # http://localhost:3000
```

### Variáveis de ambiente

| Variável | Uso |
| :--- | :--- |
| `NEXT_PUBLIC_SUPABASE_URL` | URL do projeto Supabase |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Chave pública (client) |
| `SUPABASE_SERVICE_ROLE_KEY` | Chave privilegiada — **apenas em rotas de API**, nunca em `/app` ou `/components` |
| `SESSION_SECRET` | Segredo do Iron Session (AES-256-GCM) |
| `TCE_API_BASE_URL` | `https://api-processos.tce.ce.gov.br` |
| `RESEND_API_KEY` | Envio de e-mail |
| `WHATSAPP_TOKEN` · `WHATSAPP_PHONE_ID` | WhatsApp Cloud API |
| `CRON_SECRET` | Protege `/api/cron/*` de chamada externa |

---

## Estrutura prevista

```
app/
  (auth)/              login, cadastro
  admin/               painel do escritório
  gestor/              painel do gestor público
  interno/             console de operação (is_superadmin)
  api/
    cron/sync/         coleta agendada
    cron/notify/       disparo de notificações
lib/
  tce/                 TceClient — cliente da API + filtro de privacidade
  services/            regra de negócio
  repositories/        acesso a dados
supabase/
  migrations/          schema versionado
docs/
```

---

## Regras do projeto

Fixadas em [.claude/rules/](.claude/rules/) e resumidas aqui:

- **Nunca** usar `SUPABASE_SERVICE_ROLE_KEY` em `/app` ou `/components`
- Frontend **não escreve** direto no Supabase — toda mutação passa por `/api/*` com sessão validada
- Toda query carrega `escritorio_id`, **sempre vindo da sessão**, nunca do body
- Toda tabela de negócio tem RLS ativa
- Regra de negócio em `services/`; rotas apenas validam e delegam
- Commits em [Conventional Commits](https://www.conventionalcommits.org/pt-br/)

---

## Conformidade

A plataforma trata dados de processos públicos e dados pessoais de terceiros. Antes de qualquer alteração na camada de coleta ou notificação, leia [docs/CONFORMIDADE.md](docs/CONFORMIDADE.md).

Regras que o código precisa garantir:

- Processo com `sigiloso: true` → **nunca persistido**
- Interessado com `preservado: true` → **nome nunca persistido nem exibido**
- Throttle de 1 req/s na coleta, com `User-Agent` identificável
- Opt-out em toda comunicação automática

---

## Roadmap

| Fase | Entrega |
| :--- | :--- |
| 0 | Spike técnico — mapear tabelas auxiliares, medir custo de sync |
| 1 | Fundação — Next.js, Supabase, schema, RLS, auth |
| 2 | Ingestão + console interno |
| 3 | Detecção de movimentação + notificações |
| 4 | Painel do escritório + sessões de suporte |
| 5 | Painel do gestor + aprovação de peças ← **piloto vendável** |
| 6 | Kanban, tarefas, Central de Ajuda |
| 7 | Indicadores, modelos de documento, IA |

Detalhamento em [docs/PLANO_MVP.md](docs/PLANO_MVP.md).
