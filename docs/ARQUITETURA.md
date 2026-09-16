# Arquitetura — Plataforma TCE

## Tipo de projeto

Aplicação WEB multi-tenant (SaaS) — Next.js App Router, com coleta agendada serverless.

---

## Visão geral

```
                    ┌─────────────────────────────┐
                    │   api-processos.tce.ce.gov.br│
                    │   (API pública, sem auth)    │
                    └──────────────┬──────────────┘
                                   │ porLista → porNumero
                                   │ throttle 1 req/s
┌──────────────────┐        ┌──────▼──────┐
│  Vercel Cron     │───────►│  TceClient  │  filtro de privacidade
│  (diário)        │        └──────┬──────┘  (sigiloso / preservado)
└──────────────────┘               │
                                   ▼
                    ┌──────────────────────────────┐
                    │     Supabase PostgreSQL      │
                    │  espelho TCE + dados tenant  │
                    │  RLS em toda tabela          │
                    └──────────────┬───────────────┘
                                   │ diff por tramites[].id
                                   ▼
                    ┌──────────────────────────────┐
                    │   Classificação de trâmite   │
                    │   crítico / relevante / rotina│
                    └──────────────┬───────────────┘
                                   │ só crítico e relevante notificam
                                   ▼
                    ┌──────────────────────────────┐
                    │   Fila de notificações       │
                    │   Resend · WhatsApp Cloud API│
                    └──────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    Next.js App Router                        │
│  /admin/*    Painel do Escritório     (perfil no tenant)    │
│  /gestor/*   Painel do Gestor Público (perfil no tenant)    │
│  /interno/*  Console de Operação      (is_superadmin)       │
└─────────────────────────────────────────────────────────────┘
```

---

## Decisões estruturais

### 1. Serverless, viabilizado pela API pública

A investigação (ver [API_TCE.md](API_TCE.md)) confirmou que o TCE-CE expõe **API REST pública retornando JSON**. Sem scraping, não há browser headless — e o principal argumento contra serverless desaparece.

Vercel Cron + Supabase é, portanto, a escolha **correta**, não um compromisso: sem servidor para manter, custo proporcional ao uso, deploy trivial.

*Se a coleta exigisse Playwright, a decisão seria outra — worker em VPS.*

### 2. Coleta por município, não por assinante

Sincronizar Horizonte custa o mesmo com 1 ou 50 escritórios clientes. As tabelas-espelho (`processos`, `tramites`) são **dados públicos compartilhados** entre todos os tenants; o vínculo privado fica em `processos_monitorados`.

Consequência de produto: o custo marginal por cliente é quase zero, o que sustenta municípios ilimitados em todos os planos.

### 3. `TceClient` isola a fonte de dados

Toda comunicação com o TCE passa por uma única abstração (`lib/tce/`), responsável por:

- Montar os payloads (com os tipos corretos de `numero` vs `numeros`)
- Throttle de 1 req/s e `User-Agent` identificável
- Retry com backoff
- **Validar o shape da resposta** e falhar alto se o contrato mudar — a API não é versionada
- **Filtro de privacidade** — descartar `sigiloso`, omitir nome `preservado`

O filtro vive aqui e em nenhum outro lugar: o dado proibido nunca entra no sistema, então nenhuma camada acima precisa se defender dele.

Trocar por uma API oficial futura, ou estender a outro Tribunal de Contas, é reimplementar esta interface.

### 4. Chunking com cursor persistido

Funções serverless têm limite de execução. Um sync de 2.431 processos não cabe numa invocação.

Cada execução processa um lote e grava o progresso em `sync_runs.cursor`. A invocação seguinte retoma dali. O sync é **idempotente**: reexecutar não duplica nada, porque a deduplicação usa `tramite_id_tce UNIQUE`.

### 5. Um service, dois gatilhos

O cron e o botão "sincronizar agora" do console interno chamam **o mesmo service**. A tela não reimplementa a coleta (regra 06 — clean architecture).

### 6. Duas dimensões de autorização

| Dimensão | Campo | Enxerga |
| :--- | :--- | :--- |
| Papel no tenant | `usuarios.perfil` | Apenas o próprio `escritorio_id` |
| Poder de plataforma | `usuarios.is_superadmin` | Máquina de coleta — nunca dado de escritório |
| Poder de suporte | `usuarios.is_suporte` | Nada por padrão; só o que uma sessão ativa liberar |

`is_superadmin` e `is_suporte` são **flags independentes**, fora de `perfil`. Fundir os dois numa coluna só é a origem clássica de vazamento multi-tenant — superadmin e suporte precisam de acessos quase opostos.

Detalhes em [CONSOLE_INTERNO.md](CONSOLE_INTERNO.md).

---

## Camadas

```
app/api/*/route.ts     → valida input, chama service, formata resposta
lib/services/          → regra de negócio (quotas, classificação, notificação)
lib/repositories/      → acesso a dados, sempre com escritorio_id da sessão
lib/tce/               → TceClient
```

Regras (ver [.claude/rules/](../.claude/rules/)):

- Rota **não** contém regra de negócio — valida e delega
- `escritorio_id` **sempre da sessão**, nunca do body
- `SUPABASE_SERVICE_ROLE_KEY` só em rotas de API, nunca em `/app` ou `/components`
- Frontend não escreve direto no Supabase
- Lógica usada em mais de um lugar é centralizada em service

---

## Fluxo de detecção de movimentação

1. `porLista` descobre processos dos municípios com `ativo = true`
2. Para cada processo, `porNumero` traz o detalhe com `tramites[]`
3. Comparação do conjunto de `tramites[].id` com o que está no banco
4. Trâmite novo → classificado (`crítico` / `relevante` / `rotina`)
5. Classificação define a ação:

| Classificação | Ação |
| :--- | :--- |
| Crítico | WhatsApp + e-mail imediato + tarefa automática no Kanban |
| Relevante | E-mail; aparece no painel |
| Rotina | Só histórico; sem notificação |

A classificação usa regras determinísticas sobre `acao.descricao`, `especie` e `subEspecie`, editáveis pelo console sem deploy. Trâmite não coberto por regra vai para IA, que sugere — e o superadmin promove a regra fixa.

**Sem esta etapa o produto falha:** a maior parte dos trâmites é ruído administrativo ("PARA ANÁLISE", "DISTRIBUIR/REDISTRIBUIR"). Notificar tudo treina o cliente a ignorar o alerta.

---

## Notificações

Fila em tabela (`notificacoes`), consumida por cron separado do sync — coleta lenta não atrasa alerta, e falha de envio não perde movimentação já detectada.

- Retry com backoff; `tentativas` registrado
- Quota de WhatsApp esgotada → **degrada para e-mail**, não silencia
- Opt-out em toda comunicação
- Reenvio manual pelo console interno

---

## Segurança

- **Sessão:** `getIronSession` com AES-256-GCM; cookie `httpOnly`, `secure` em produção, `sameSite: lax`
- **RLS:** toda tabela de negócio; policies aceitam também sessão de suporte ativa, com **expiração verificada na policy do banco** — sessão vencida para de funcionar mesmo que a UI falhe
- **Rotas de cron:** protegidas por `CRON_SECRET`
- **Headers:** CSP e `frame-ancestors 'none'` nas áreas autenticadas
- **Auditoria:** `logs_auditoria` registra ação sensível com usuário, papel, IP e timestamp

---

## Referências

- [MODELAGEM_DADOS.md](MODELAGEM_DADOS.md) — schema e policies
- [API_TCE.md](API_TCE.md) — endpoints e campos
- [CONSOLE_INTERNO.md](CONSOLE_INTERNO.md) — operação
- [CONFORMIDADE.md](CONFORMIDADE.md) — LGPD e política de coleta
- [PADRAO_V4_ELITE.md](PADRAO_V4_ELITE.md) — padrão de UI
