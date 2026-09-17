# Plano de MVP — Plataforma TCE

Roadmap por fases, com escopo, dependências e critérios de aceite.

**Piloto vendável ao fim da Fase 5** (~14 semanas de desenvolvimento — Fases 0 a 5: 1+2+3+2+3+3). Fases 6–7 são expansão de valor, não pré-requisito para vender.

---

## Visão das fases

| Fase | Duração | Entrega | Bloqueia? |
| :--- | :--- | :--- | :--- |
| 0 — Spike técnico | 1 sem | Decisão go/no-go | ✅ tudo |
| 1 — Fundação | 2 sem | Auth, schema, RLS | ✅ tudo |
| 2 — Ingestão + Console | 3 sem | Dados reais no banco | ✅ 3–7 |
| 3 — Detecção + Notificação | 2 sem | **O produto funciona** | ✅ 5 |
| 4 — Painel Escritório | 3 sem | Cliente usa sozinho | ✅ 5 |
| 5 — Painel Gestor + Peças | 3 sem | **Piloto vendável** | — |
| 6 — Atividades + Ajuda | 2–3 sem | Kanban, Central de Ajuda | — |
| 7 — Indicadores + IA | 3 sem | Relatórios, modelos, IA | — |

---

## Fase 0 — Spike técnico (1 semana)

Investigação antes de escrever código de produção. **Pode invalidar premissas** — por isso vem primeiro.

### Escopo

1. ✅ ~~**Termos de Uso do Portal Contexto**~~ — pesquisado em 17/09/2026: nenhum termo dedicado publicado, nenhuma restrição a uso automatizado. Ver [CONFORMIDADE.md § Pesquisa de termos de uso](CONFORMIDADE.md). Resta formalizar contato institucional com o TCE-CE antes do lançamento (não bloqueia o desenvolvimento).
2. ✅ ~~**Mapear as 11 tabelas auxiliares restantes**~~ — resolvido em 16/09/2026: não era o método (GET funciona), era o host. As 11 rotas estão em `contexto-api.tce.ce.gov.br`, não em `api-processos`. Detalhe completo, incluindo a rota `interessado` que deve ser ignorada, em [API_TCE.md](API_TCE.md).
3. ✅ ~~**Medir o custo real de um sync de Horizonte**~~ — medido em 16/09/2026: `qtd` é ignorado pela API (sempre 10/página); carga inicial completa (244 páginas + 2.431 detalhes, throttle 1 req/s) ≈ **78 minutos**, exige chunking com auto-continuação. Sync diário deve evitar detalhar todo processo comparando `dtUltimoEncaminhamento` já presente na listagem — ver [API_TCE.md § Volume](API_TCE.md).
4. ✅ ~~**Validar a deduplicação**~~ — confirmado em 16/09/2026: 10/10 processos recoletados tiveram `tramites[].id` idênticos. Estável.
5. ✅ ~~**Levantar amostra de `acao.descricao`**~~ — coletadas **60 ações distintas** (após normalização) em 583 trâmites de 100 processos de Horizonte, amostrando páginas recentes e antigas. Achados para a Fase 3: a mesma ação aparece com `acao.id` diferente por variação de caixa (`EMITIR CERTIDÃO/EXTRATO DE JULGAMENTO` tem dois ids) — **agrupar por `descricao.trim().toUpperCase()`, nunca por `acao.id`**; `acao` pode vir `null` e `descricao` pode vir vazia. Processos antigos têm histórico muito mais longo (média de 7,4 trâmites, máximo de 60) que os recentes (média 2,1) — dimensionar a classificação para processos com dezenas de trâmites, não a média geral.

### Aceite

- [x] Relatório técnico com as respostas acima — resultados incorporados a [API_TCE.md](API_TCE.md)
- [x] Decisão **go / no-go**: **GO.** Nenhum achado invalida a arquitetura Vercel + Supabase; os ajustes necessários (chunking por 244 páginas fixas, delta por `dtUltimoEncaminhamento`, normalização de `id` entre hosts, allowlist estrita em `exibirDocumento`) são de implementação, não de replanejamento.
- [x] Amostra de ações classificadas manualmente (insumo da Fase 3) — 77 ações distintas coletadas; classificação manual (relevante/rotineira) ainda não feita, fica para o início da Fase 3.

---

## Fase 1 — Fundação (2 semanas)

### Escopo

- Projeto Next.js 14 (App Router) + TypeScript + Tailwind
- Projeto Supabase, migrations versionadas
- Schema completo de [MODELAGEM_DADOS.md](MODELAGEM_DADOS.md) — **todas as tabelas, inclusive as das fases 5–7**
- RLS e funções auxiliares (`auth_escritorio_id`, `auth_is_superadmin`, `auth_tem_suporte_ativo`)
- Auth com **Supabase Auth** (não Iron Session — RLS depende de `auth.uid()`, que só existe com o JWT do Supabase na requisição)
- Middleware protegendo `/admin`, `/gestor`, `/interno`
- Seed dos 184 municípios (só Horizonte `ativo = true`)
- Seed dos planos

> **O schema inteiro entra agora, mesmo para funcionalidade que só chega na Fase 7.** Tabela criada cedo custa quase nada; adicionar `escritorio_id` e quota depois, com o código escrito, obriga a mexer em dezenas de lugares.

### Aceite

- [ ] Login funcional nos três níveis
- [ ] **Teste com dois tenants**: escritório A não lê dado do escritório B
- [ ] Usuário sem `is_superadmin` recebe 403 em `/interno/*`, inclusive por URL direta
- [ ] Migrations aplicam em banco limpo sem erro

---

## Fase 2 — Ingestão + Console (3 semanas)

### Escopo

**`TceClient`** (`lib/tce/`):
- Tipos separados para `porNumero` (`numero`, singular) e `porLista` (`numeros`, plural)
- Throttle 1 req/s, `User-Agent` identificável
- Retry com backoff
- Validação do shape da resposta — falhar alto se o contrato mudar
- **Filtro de privacidade** (`sigiloso`, `preservado`)

**Sync** (`/api/cron/sync`):
- Chunking com `sync_runs.cursor_pagina`
- Idempotente via `tramite_id_tce UNIQUE`
- Protegido por `CRON_SECRET`

**Console** (`/interno`): dashboard, `/sync`, `/municipios`, `/inspetor`

### Aceite

- [ ] Horizonte sincronizado — 2.431 processos no banco
- [ ] Reexecutar o sync **não duplica** nada
- [ ] Sync disparável pela tela, retomando de onde parou
- [ ] **Teste com fixture**: processo `sigiloso: true` não chega ao banco; interessado `preservado: true` fica com `nome = NULL`
- [ ] Inspetor mostra resposta crua vs. banco — e não renderiza processo sigiloso

---

## Fase 3 — Detecção + Notificação (2 semanas)

**A fase em que o produto passa a existir.**

### Escopo

- Detecção de trâmite novo por diff de `tramite_id_tce`
- **Classificação** (crítico / relevante / rotina) com `regras_classificacao` + `/interno/classificacao`
- Fila `notificacoes`, consumida por cron separado
- E-mail via Resend; WhatsApp Cloud API
- Opt-out funcional
- `/interno/notificacoes` com reenvio

### Ordem importa

Classificação **antes** de notificação. Sem ela, todo trâmite vira alerta — e o cliente desliga a notificação em uma semana, que é a morte do produto.

### Aceite

- [ ] Trâmite novo gera alerta em < 24h
- [ ] **Fixture com trâmite crítico (citação) e de rotina ("PARA ANÁLISE"): só o crítico notifica**
- [ ] Opt-out funciona e é permanente
- [ ] Quota de WhatsApp esgotada → **degrada para e-mail**, não silencia
- [ ] Falha de envio reenviável pelo console

---

## Fase 4 — Painel Escritório + Suporte (3 semanas)

### Escopo

- Listagem e detalhe de processos ([PADRÃO V4 ELITE](PADRAO_V4_ELITE.md))
- Vincular processo monitorado a cliente e responsável
- CRUD de clientes
- Prazos + **calculadora do TCE** com memória de cálculo
- **Permissões granulares**
- **Sessões de suporte** + banner no cliente + `logs_auditoria`
- Enforcement de quotas com `QUOTA_EXCEEDED` + tela de upgrade

### Aceite

- [ ] CRUD completo, isolado por tenant
- [ ] Prazo calculado exibe a memória (marco, dias, feriados)
- [ ] **Sessão de suporte expirada perde acesso na policy do banco** (testar com a UI fora do caminho)
- [ ] Banner aparece para o cliente enquanto a sessão está ativa
- [ ] Limite de processos monitorados bloqueia o novo e preserva o existente

---

## Fase 5 — Painel Gestor + Colaboração (3 semanas)

**Fim desta fase = piloto vendável.**

### Escopo

- Painel do gestor: seus processos, em linguagem acessível
- Consulta pública freemium + captura de lead
- **Módulo de aprovação de peças**: versionamento, comentários, aprovar/pedir ajuste
- Registro de aprovação com data, hora e IP
- Notificação nos dois sentidos

### Aceite

- [ ] Gestor vê apenas os processos dele
- [ ] Ciclo completo: escritório sobe minuta → gestor comenta → aprova ou pede ajuste → nova versão
- [ ] **Aprovação gera registro imutável**; nova versão não sobrescreve a anterior
- [ ] Consulta pública funciona sem login

---

## Fase 6 — Atividades + Ajuda (2–3 semanas)

- Kanban: quadros, colunas, tarefas, etiquetas, drag-and-drop
- **Tarefa automática** a partir de trâmite crítico
- Visão por responsável (carga da equipe)
- Central de Ajuda e Central de Sugestões

**Aceite:** trâmite crítico gera tarefa vinculada ao processo; cliente envia sugestão e acompanha o status.

---

## Fase 7 — Indicadores + Modelos + IA (3 semanas)

- Indicadores: pessoal, geral, por cliente, **estratégico**
- Modelos de documento com variáveis do processo
- IA: traduzir trâmite, sugerir próximo passo, classificar trâmite sem regra

**Aceite:** indicador estratégico mostra prazos cumpridos vs. perdidos; IA é cacheada por tipo de trâmite, não por processo.

> O indicador estratégico quantifica o ROI da assinatura — "você cumpriu 47 prazos que descobriria tarde" é o argumento de renovação.

---

# Guia: Supabase + Vercel do zero

Passo a passo para quem nunca usou. Execute na ordem.

## Parte 1 — Supabase

### 1.1 Projeto já criado

> ✅ **Feito em 16/09/2026.** O projeto **`Plataforma-Sistemas`** (ref `lwvwuhkwdrbmvwymbpwe`, região `sa-east-1`) já existe e já tem o schema aplicado. Ver [ESTADO_DO_PROJETO.md § Decisão arquitetural](../ESTADO_DO_PROJETO.md) antes de criar qualquer coisa nova — este não é um projeto exclusivo do TCE, é compartilhado com outros sistemas (schema `plataforma` para identidade comum, schema `tce` para os dados deste sistema).
>
> Os passos abaixo (1.1 a 1.4 originais) ficam como referência para quando o projeto de **produção** for criado — repita o mesmo padrão de schemas, não crie `escritorios`/`usuarios` soltos em `public`.

1. Acesse [supabase.com](https://supabase.com) e crie conta
2. **New Project**
   - Name: `Plataforma-Sistemas-Prod` (ou equivalente — nunca reaproveitar o projeto de dev)
   - Database Password: gere uma forte e **guarde** — não dá para recuperar
   - Region: **South America (São Paulo)** — menor latência
   - Plan: Free
3. Aguarde ~2 minutos

> Crie **projetos separados** para dev e produção. Nunca conecte ambiente local ao banco de produção.

### 1.2 Pegar as chaves

**Project Settings → API**:

| Campo | Vai para |
| :--- | :--- |
| Project URL | `NEXT_PUBLIC_SUPABASE_URL` |
| `publishable` (nomenclatura nova; `anon` `public` em projetos antigos) | `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` |
| `secret` (nomenclatura nova; `service_role` em projetos antigos) | `SUPABASE_SECRET_KEY` |

> ⚠️ A chave secreta/`service_role` **ignora RLS**. Nunca em `/app`, `/components`, nem em variável com prefixo `NEXT_PUBLIC_`. Só em rotas de API.
>
> Para o cron de ingestão do TCE especificamente: **não** usar a chave secreta do projeto — ela alcançaria os schemas de outros sistemas hospedados aqui. Usar a role de banco dedicada `tce_ingestor` (criada na migration de RLS), conectando via connection string do Postgres, não via API REST.

### 1.3 CLI e migrations

```bash
npm install -g supabase
supabase login
supabase init                      # cria supabase/ no projeto (já existe neste repo)
supabase link --project-ref lwvwuhkwdrbmvwymbpwe

supabase migration new nome_da_mudanca
# escreva o SQL em supabase/migrations/<timestamp>_nome_da_mudanca.sql

supabase db push                   # aplica no projeto remoto
```

Alterou o schema? **Nova migration**, nunca editar uma já aplicada. As 7 migrations da Fase 1 (schema `plataforma` + `tce`, RLS, seed) já estão em `supabase/migrations/` e já foram aplicadas — não reaplicar do zero, só adicionar migrations novas por cima.

### 1.4 Conferir a RLS

**Table Editor** → cada tabela deve mostrar **"RLS enabled"**.

Tabela sem RLS com a chave `anon` exposta = dados públicos na internet. É o erro mais comum e mais caro.

---

## Parte 2 — Vercel

### 2.1 Conectar o repositório

1. [vercel.com](https://vercel.com) → login com GitHub
2. **Add New → Project** → selecione `ControleProcessoTCE`
3. Framework: Next.js (detectado)
4. **Não faça deploy ainda** — configure as variáveis primeiro

### 2.2 Variáveis de ambiente

**Settings → Environment Variables**. Marque os ambientes corretos:

| Variável | Ambientes |
| :--- | :--- |
| `NEXT_PUBLIC_SUPABASE_URL` | Production, Preview, Development |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Production, Preview, Development |
| `SUPABASE_SERVICE_ROLE_KEY` | **Production apenas** |
| `SESSION_SECRET` | todos |
| `CRON_SECRET` | todos |
| `TCE_API_BASE_URL` | todos |
| `RESEND_API_KEY` | Production, Preview |
| `WHATSAPP_TOKEN` · `WHATSAPP_PHONE_ID` | Production |

Gerar segredos:
```bash
openssl rand -base64 32
```

### 2.3 Cron Jobs

`vercel.json` na raiz:

```json
{
  "crons": [
    { "path": "/api/cron/sync",   "schedule": "0 3 * * *" },
    { "path": "/api/cron/notify", "schedule": "*/15 * * * *" }
  ]
}
```

- Sync às 3h (horário de menor carga no TCE)
- Notificações a cada 15 min

> Plano Free permite **2 cron jobs, 1x/dia**. Para `*/15` é preciso o plano Pro. No piloto, usar 1x/dia para ambos e revisar depois.

### 2.4 Proteger as rotas de cron

A Vercel envia `Authorization: Bearer <CRON_SECRET>`:

```ts
// app/api/cron/sync/route.ts
export async function GET(request: Request) {
  const auth = request.headers.get('authorization')
  if (auth !== `Bearer ${process.env.CRON_SECRET}`) {
    return new Response('Unauthorized', { status: 401 })
  }
  // ... chama o service
}
```

Sem isso, qualquer um dispara seu sync pela URL.

### 2.5 Limite de execução

| Plano | Timeout |
| :--- | :--- |
| Hobby | 10s (padrão) / 60s (configurável) |
| Pro | 300s |

```ts
export const maxDuration = 60
```

**É por isso que o chunking existe.** Cada invocação processa um lote e grava `sync_runs.cursor_pagina`; a seguinte retoma dali.

### 2.6 Testar o cron

O cron **não roda em preview**, só em produção. Para testar:

```bash
curl -X GET "https://<seu-deploy>.vercel.app/api/cron/sync" \
  -H "Authorization: Bearer <CRON_SECRET>"
```

Logs em **Deployments → Functions**.

---

## Parte 3 — Fluxo de trabalho

```bash
git checkout -b feat/ingestao-tce
# desenvolver
git commit -m "feat(tce): adiciona TceClient com filtro de privacidade"
git push origin feat/ingestao-tce
```

A Vercel cria **deploy de preview** por branch. Merge em `main` → produção.

### Custos no piloto

| Serviço | Free | Suficiente? |
| :--- | :--- | :--- |
| Supabase | 500 MB banco, 1 GB storage | ✅ para Horizonte |
| Vercel | 100 GB banda, 2 crons | ⚠️ cron de 15 min exige Pro |
| Resend | 3.000 e-mails/mês | ✅ |
| WhatsApp Cloud API | 1.000 conversas/mês | ✅ |

Piloto cabe em tier gratuito, exceto a frequência de notificação.

---

# Referência competitiva — Astrea (Aurum)

120 mil usuários, 4,8/5 em 2.800+ avaliações. **Cobre Justiça comum — não cobre Tribunais de Contas.** É referência de UX e pricing, não concorrente direto.

## Planos

| Plano | Preço/mês | Processos | Usuários | Storage | Quadros |
| :--- | ---: | ---: | ---: | ---: | ---: |
| Light | Grátis 1 ano | 40 | 1 | 1 GB | 2 |
| Up | R$ 209 | 150 | 2 | 10 GB | 3 |
| Smart | R$ 379 | 500 | 5 | 20 GB | 4 |
| Company | R$ 689 | 1.000 | 10 | 30 GB | 5 |
| VIP | R$ 1.249 | 2.000 | 30 | 50 GB | — |

Trial de 10 dias sem cartão. **Processos cadastrados ilimitados em todos** — só o monitoramento é limitado.

## O que foi adotado

| Prática | Por quê |
| :--- | :--- |
| Quotas escalando em paralelo | Padrão validado por 120k usuários |
| Cadastro ilimitado, monitoramento limitado | Cobra-se o que consome recurso recorrente |
| Trial sem cartão | Reduz atrito; compatível com o freemium |
| Portal do Cliente | Valida a "Versão Gestor" como padrão de mercado |
| Kanban com quota de quadros | Diferencia tier sem custo de infra |
| Etiquetas e comentários | Convenção que o usuário já conhece |

## O que foi rejeitado

| Módulo | Por quê |
| :--- | :--- |
| Financeiro do escritório | Projeto do tamanho do MVP. Escritório já tem sistema |
| Timesheet | Faz sentido em honorário por hora; o nicho TCE trabalha por caso |
| App nativo | PWA atende o piloto |

## Onde somos diferentes

**1. Nicho aberto.** Ninguém monitora Tribunais de Contas. As ferramentas jurídicas cobrem Justiça comum.

**2. Custo marginal quase zero.** O Astrea cobra por "nomes para captura" porque cada nome custa consulta. Aqui a coleta é por município e roda uma vez para todos os assinantes — por isso **municípios são ilimitados em todos os planos**, e nenhum concorrente que cobre por abrangência consegue igualar.

**3. Indicador de ROI.** "Prazos cumpridos vs. perdidos" não existe no Astrea e é o argumento de renovação.

**4. Conhecimento de domínio.** Calculadora de prazos do TCE e classificação de trâmites são barreira real — o resto é software.

## Pricing proposto

| Plano | Faixa | Posicionamento |
| :--- | :--- | :--- |
| Gratuito | R$ 0 | Consulta básica, captura de lead |
| Gestor | R$ 97–149 | Gestor individual |
| Escritório | R$ 349–599 | Equivale ao Smart, abaixo no preço |
| Escritório Plus | R$ 899–1.199 | Equivale ao Company/VIP |

Ancorado abaixo do Astrea por ser vertical mais estreito, com margem de upsell. **A validar na reunião comercial.**

---

## Decisões pendentes

| # | Decisão | Quando |
| :--- | :--- | :--- |
| 1 | Formalizar contato institucional com o TCE-CE (pesquisa de termos concluída, sem bloqueio) | Antes do lançamento |
| 2 | Provedor de WhatsApp: Cloud API oficial vs. BSP | Fase 3 |
| 3 | Pricing final | Reunião comercial |
| 4 | Nome do produto — `ControleProcessoTCE` é repositório, não marca | Antes do lançamento |
| 5 | Gateway de pagamento das assinaturas | Fase 5 |
