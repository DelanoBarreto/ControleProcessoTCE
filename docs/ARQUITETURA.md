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

### 4. Chunking com auto-continuação — não apenas cursor

Funções serverless têm limite de execução. Um sync de Horizonte (2.431 processos, `porLista` + `porNumero` por processo, a 1 req/s) leva **~40 minutos só de `porNumero`**, sem contar listagem e retries — muito além de qualquer timeout serverless, e muito além do que um cron `0 3 * * *` (uma vez ao dia) cobre em uma única invocação.

**Ter um cursor não basta.** Cursor persistido responde "de onde continuar"; falta responder **"o que dispara a próxima invocação"**. Sem isso, o sync trava no primeiro lote todo santo dia, e a promessa de alerta em menos de 24h não se sustenta — a segunda página do dia só rodaria no dia seguinte.

**Mecanismo real:** cada invocação, ao terminar seu lote dentro do próprio orçamento de tempo (`maxDuration`, com margem), verifica se `sync_runs.status` ainda é `em_andamento` e, em caso positivo, **dispara a si mesma novamente** via `fetch` assíncrono para a mesma rota, antes de retornar. A cadeia de autoinvocações continua até `cursor_pagina >= total_paginas`, quando marca `status = 'concluido'`.

```
Cron (1x/dia) → invocação 1 (lote 1) → dispara invocação 2 → lote 2 → dispara invocação 3 → ...
                                                                              ↓
                                                        até esgotar as páginas do município ativo
```

Concorrência: antes de processar, a rota adquire lock otimista em `sync_runs` (`UPDATE ... WHERE status = 'em_andamento' AND locked_until < now()`); uma segunda invocação disparada por engano (retry da própria Vercel, por exemplo) encontra o lock e sai sem reprocessar.

Recuperação: se a cadeia for interrompida (deploy, erro, timeout da rede), a run fica `em_andamento` com `locked_until` no passado. Um cron de **verificação** separado, a cada 15-30 min, retoma qualquer run travada nesse estado — sem isso, uma cadeia quebrada trava até o próximo disparo diário.

Idempotência: reexecutar um lote não duplica nada, porque a deduplicação usa `tramite_id_tce UNIQUE`. Isso cobre reprocessamento de dado, **não** cobre o problema de continuação — os dois mecanismos resolvem coisas diferentes.

> **Carga inicial não deve gerar alerta.** A primeira sincronização de um município encontra milhares de trâmites "novos" simplesmente porque nunca foram vistos — nenhum deles é uma movimentação recente. `sync_runs` marca `carga_inicial: boolean`; enquanto verdadeiro, trâmites são gravados e classificados, mas **não entram na fila de notificação**. Só a partir da segunda execução — quando o comparativo é contra o que já está no banco — um trâmite novo é, de fato, uma novidade.

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

### Identidade: Supabase Auth (decisão revisada)

**A autenticação é o Supabase Auth.** Não usar Iron Session, nem qualquer sessão paralela, para identificar o usuário perante o banco.

Razão — e este é um erro que a primeira versão desta arquitetura cometeu: as policies de RLS dependem de `auth.uid()`, que só existe quando a consulta chega ao Postgres **com o JWT do usuário**. Com uma sessão externa (Iron Session), `auth.uid()` retorna `NULL`, toda a RLS falha fechada, e a saída prática seria usar `service_role` nas consultas de usuário — o que **ignora RLS por completo** e anula o modelo de isolamento multi-tenant inteiro.

> A regra `rule-01` do kit do projeto prescreve `getIronSession`. Ela foi escrita para um contexto **sem RLS do Supabase**. Onde a autorização vive no banco, a identidade precisa chegar ao banco. Esta arquitetura documenta a exceção deliberada.

| Camada | Credencial | Alcance |
| :--- | :--- | :--- |
| Consultas de usuário (`/admin`, `/gestor`, `/interno`) | JWT do usuário via Supabase Auth | Sujeito a RLS |
| Ingestão, cron, tarefas internas | `service_role` em módulo servidor | **Ignora RLS** — nunca em caminho de request de usuário |

Regras:

- `SUPABASE_SERVICE_ROLE_KEY` só em rotas de cron e serviços internos, nunca para servir dados a um usuário autenticado
- Rota de API que lê ou escreve dado de tenant **usa o cliente com o JWT do requisitante**
- Nenhum hash de senha próprio, nenhum fluxo de login paralelo

### Demais controles

- **RLS:** toda tabela de negócio, com policies **por operação** (`SELECT`/`INSERT`/`UPDATE`/`DELETE`) e por perfil — nunca uma única `FOR ALL` permissiva; ver [MODELAGEM_DADOS.md](MODELAGEM_DADOS.md#6-row-level-security)
- **Sessão de suporte:** expiração verificada **na policy do banco**, não na aplicação — sessão vencida para de funcionar mesmo que a UI falhe
- **Rotas de cron:** protegidas por `CRON_SECRET`
- **Headers:** CSP e `frame-ancestors 'none'` nas áreas autenticadas
- **Auditoria:** `logs_auditoria` registra ação sensível com usuário, papel, IP e timestamp; imutável para usuários

---

## Referências

- [MODELAGEM_DADOS.md](MODELAGEM_DADOS.md) — schema e policies
- [API_TCE.md](API_TCE.md) — endpoints e campos
- [CONSOLE_INTERNO.md](CONSOLE_INTERNO.md) — operação
- [CONFORMIDADE.md](CONFORMIDADE.md) — LGPD e política de coleta
- [PADRAO_V4_ELITE.md](PADRAO_V4_ELITE.md) — padrão de UI
