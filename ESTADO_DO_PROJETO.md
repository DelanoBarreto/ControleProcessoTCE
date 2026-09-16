# Estado do Projeto

> **Leia este arquivo primeiro** ao abrir o projeto em outra máquina ou iniciar um chat novo com IA.
> Ele responde: onde o projeto parou, o que já foi decidido e qual é o próximo passo.

**Última atualização:** 16/09/2026 (Fase 0 — spike técnico concluído, decisão **GO**)
**Branch:** `main` · **Remote:** `https://github.com/DelanoBarreto/ControleProcessoTCE.git`

---

## 🔄 Ao trocar de máquina

```bash
# ANTES de começar a trabalhar
git pull origin main

# DEPOIS de terminar (mesmo inacabado)
git add -A
git commit -m "tipo(escopo): descricao"
git push origin main
```

> Sempre atualize a seção **"Onde paramos"** abaixo antes do push. É o que a outra máquina vai ler.

---

## 📍 Onde paramos

**Fase atual:** **Fase 0 concluída — decisão GO.** Pronto para a Fase 1 (fundação), ainda **pré-código**.

**Feito:** toda a documentação de fundação (arquitetura, modelagem, conformidade, plano de MVP, propostas comerciais), a revisão técnica de segurança que corrigiu 7 falhas de design, e agora o **spike técnico da Fase 0** — todas as 5 investigações foram executadas contra a API real do TCE-CE em 16/09/2026. Nenhuma linha de código de aplicação foi escrita ainda.

> ⚠️ **Antes de implementar, leia "Correções da revisão técnica" e "Achados da Fase 0" abaixo.** São decisões de segurança e comportamentos reais da API que mudam trechos de `ARQUITETURA.md`, `MODELAGEM_DADOS.md` e `API_TCE.md` — implementar pela versão antiga desses documentos reintroduz falhas já identificadas.

**Decisão go/no-go: GO.** Nenhum achado invalida a arquitetura Vercel + Supabase. Os ajustes necessários são de implementação, não de replanejamento.

**Próximo passo:** **Fase 1 — Fundação** (ver [docs/PLANO_MVP.md](docs/PLANO_MVP.md)): projeto Next.js + Supabase, schema completo, RLS, Supabase Auth, seed dos 184 municípios.

Duas coisas ficaram pendentes da Fase 0, nenhuma bloqueante:
- Classificar manualmente as 60 ações coletadas em relevante/rotineira — insumo da Fase 3, não da Fase 1.
- Investigar 10 processos de Horizonte que não caem em nenhum `exercicio` de 2005–2026 (ver pendência 11).

---

## 🔬 Achados da Fase 0 (16/09/2026)

Spike executado contra a API real. Detalhe completo em [docs/API_TCE.md](docs/API_TCE.md) — resumo do que **muda a implementação**:

| # | Achado | Consequência |
| :--- | :--- | :--- |
| 1 | As 11 tabelas auxiliares "faltantes" **não exigiam POST** — estavam em **outro host** (`contexto-api`, não `api-processos`) | Todas mapeadas. `interessado` é um stub inútil (10 registros fixos, ignora todo parâmetro) — **não integrar** |
| 2 | 🔴 **`qtd` é ignorado** — a API sempre devolve 10 itens/página, testado até `qtd: 500` | Sync de Horizonte = **244 páginas fixas**, não 25. Dimensionar chunking por isso |
| 3 | 🔴 `exibirDocumento` **nunca foi `true`** em 564 documentos — só `null` ou `false` | Filtro de privacidade precisa ser **allowlist (`=== true`)**. `=== false` deixa passar `null`; `!exibirDocumento` bloqueia tudo |
| 4 | 🔴 `bloqueioVisualizacao` **não é booleano** — é `null` ou ID (`102203`, `102204`) | `=== true` nunca dispara e **libera documento bloqueado**. Checar `!= null` |
| 5 | 🟠 `id` das tabelas auxiliares é **int** em `api-processos` e **string** em `contexto-api` | Normalizar tipo no `TceClient` antes de persistir |
| 6 | 🟠 `numeros` + `filtros: null` → **HTTP 500**; e lote por `numeros` **não traz `tramites`** | Só funciona com `filtros: {}`. Não existe atalho de batching — `porNumero` individual é inevitável |
| 7 | ✅ `tramites[].id` **estável** (10/10 recoletas idênticas) | Deduplicação por `tramite_id_tce UNIQUE` confirmada |
| 8 | ✅ `porLista` já traz `dtUltimoEncaminhamento` | Sync diário compara essa data e só detalha o que mudou — evita 2.431 chamadas/dia |
| 9 | 🟠 `filtros.exercicio` funciona mas **não fecha a conta** (2.421 de 2.431) | **Não usar para particionar o sync** — perderia 10 processos silenciosamente |
| 10 | 🟠 Mesma ação com `acao.id` diferente por variação de caixa | Agrupar por `descricao.trim().toUpperCase()`, nunca por `acao.id`. `acao` pode vir `null` |

**Custo medido (throttle 1 req/s, sequencial):** carga inicial de Horizonte ≈ **78 min** (244 páginas + 2.431 detalhes a 606ms médios). Excede o limite de uma função serverless — confirma a necessidade do chunking com auto-continuação já previsto na arquitetura.

**Download de documento:** `GET https://api-add.tce.ce.gov.br/arquivos/documento?documento_id={id}` — sem autenticação, devolve PDF direto. Mas, pelo achado 3, nenhum download deve ser oferecido no MVP até se confirmar que `exibirDocumento: true` de fato ocorre em produção.

---

## 🛠️ Correções da revisão técnica (17/09/2026)

Uma segunda IA revisou a especificação e apontou 7 problemas reais. Todos corrigidos nos documentos-fonte — resumo do que mudou e **onde ler o detalhe**:

| # | Problema | Correção | Onde |
| :--- | :--- | :--- | :--- |
| 1 | 🔴 RLS do gestor não isolava — `OR` entre policies permitia ver todos os clientes do escritório | Condição de perfil movida para **dentro** da mesma policy (`AND`), nunca policy adicional | [MODELAGEM_DADOS.md § Gestor público](docs/MODELAGEM_DADOS.md) |
| 2 | 🔴 Iron Session ≠ `auth.uid()` — RLS dependia de identidade que a sessão não fornecia | **Supabase Auth** é a identidade única; Iron Session removido de toda a doc | [ARQUITETURA.md § Segurança](docs/ARQUITETURA.md) |
| 3 | 🟠 Policy `FOR ALL` dava ao suporte poder de deletar, contradizendo o texto | Policies **por operação** (`SELECT`/`INSERT`/`UPDATE`/`DELETE`); suporte nunca entra na de `DELETE` | [MODELAGEM_DADOS.md § Padrão para tabela de tenant](docs/MODELAGEM_DADOS.md) |
| 4 | 🟠 Cron diário não continuava lotes no mesmo ciclo — sync de Horizonte leva ~40min só de `porNumero` | Auto-continuação por autoinvocação + lock otimista + `carga_inicial` (não notifica na primeira sync) | [ARQUITETURA.md § Chunking com auto-continuação](docs/ARQUITETURA.md) |
| 5 | 🟠 Fila de notificação sem chave de entrega nem aquisição exclusiva — risco de duplicar envio | `UNIQUE (tramite_id, destinatario_id, canal)` + `FOR UPDATE SKIP LOCKED` | [MODELAGEM_DADOS.md § notificacoes](docs/MODELAGEM_DADOS.md) |
| 6 | 🟠 `raw` (jsonb) guardava a resposta crua, vazando nome de interessado `preservado` por um caminho lateral | Filtro de privacidade sanitiza `raw` também; + reconciliação para processo que vira sigiloso depois de coletado | [MODELAGEM_DADOS.md § raw / Reconciliação](docs/MODELAGEM_DADOS.md) |
| 7 | 🟠 Aprovação podia referenciar versão inexistente; `CASCADE` apagava a "prova imutável" junto com a peça | FK composta `(peca_id, versao)`; `CASCADE` removido de `pecas_aprovacoes`/`pecas_comentarios`; imutabilidade garantida por ausência de policy de `UPDATE`/`DELETE` | [MODELAGEM_DADOS.md § Peças e aprovação](docs/MODELAGEM_DADOS.md) |

Também corrigido: inconsistência de cronograma (proposta pública dizia 13 semanas; soma real das Fases 0–5 é **14**).

**Decisão explícita tomada durante essa revisão:** a mesma segunda IA sugeriu compartilhar o projeto Supabase com o PortalGov (schemas `tce_app`/`tce_dados`/`tce_operacao`). **Rejeitado.** `service_role` não respeita schema — ignora RLS do projeto inteiro. Compartilhar acopla o blast radius de dois produtos diferentes. **O TCE usa projeto Supabase próprio**, separado do PortalGov.

---

## 🎯 O que é o projeto

SaaS que monitora processos do **TCE-CE**, detecta movimentações relevantes e avisa gestores públicos e escritórios jurídicos por WhatsApp e e-mail.

Dois painéis: **gestor público** (acompanha seu processo, aprova peças) e **escritório jurídico** (gestão completa de processos, prazos e clientes).

**Piloto:** Horizonte/CE. **Nicho:** ninguém monitora Tribunais de Contas — o líder de mercado (Astrea, 120k usuários) cobre só Justiça comum.

---

## ⚡ Descobertas que não podem se perder

### O TCE-CE tem API pública

`https://api-processos.tce.ce.gov.br` — **REST, sem autenticação, JSON estruturado**. Não é necessário scraping.

Isso elimina Playwright/headless e torna a stack serverless (Vercel + Supabase) a escolha certa.

Teste rápido para confirmar que ainda funciona:

```bash
curl -X POST "https://api-processos.tce.ce.gov.br/processos/porLista" \
  -H "Content-Type: application/json" \
  -H "Origin: https://www.tce.ce.gov.br" \
  -d '{"numeros":[],"filtros":{"localidade":["72"]},"pagina":1,"qtd":5}'
```

### ⚠️ Armadilha: `numero` vs `numeros`

- `porNumero` → campo **`numero`** (singular)
- `porLista` → campo **`numeros`** (plural)

Errar retorna `lista: []` com **HTTP 200** — falha silenciosa, sem erro. Custou tempo para descobrir; só foi resolvido lendo o bundle JS do app do TCE.

### Números do piloto

| Item | Valor |
| :--- | :--- |
| Horizonte/CE | `localidade id = 72` |
| Processos | **2.431** |
| Municípios acessíveis | 184 |
| Rate limit | Nenhum detectado (usar throttle de 1 req/s mesmo assim) |

Detalhes completos em [docs/API_TCE.md](docs/API_TCE.md).

### Existe outra API oficial do TCE-CE — mas não é esta

`https://api-dados-abertos.tce.ce.gov.br/sim/` é uma API de dados abertos **oficial, documentada via Swagger**, do sistema **SIM** (licitações, orçamento, folha, patrimônio municipal). **Não cobre processos/trâmites** — não substitui a API do Contexto que o projeto usa. Não confundir as duas.

Relevante mesmo assim: a política de uso dela mostra que o TCE-CE **incentiva publicamente automação de consulta a dados abertos** — ("*use para criar aplicações, automatizar consultas*"), o que reforça a leitura de boa-fé sobre o uso da API do Contexto. Ver [docs/CONFORMIDADE.md](docs/CONFORMIDADE.md).

### Base normativa do sigilo: Resolução Administrativa nº 05/2024/TCE-CE

O próprio bundle do Contexto cita essa resolução (junto com LGPD e Lei de Acesso à Informação) como base do sigilo de documentos. As flags `sigiloso`/`exibirDocumento` da API já refletem essa norma — o filtro de privacidade do projeto só respeita o que o TCE já sinaliza. Texto integral não localizado publicado; requerer via LAI se necessário.

---

## ✅ Decisões tomadas (não reabrir sem motivo)

| Decisão | Escolha | Razão |
| :--- | :--- | :--- |
| Infraestrutura | Vercel + Supabase (serverless) | API pública elimina necessidade de VPS |
| Projeto Supabase | **Próprio do TCE**, não compartilhado com PortalGov | `service_role` ignora RLS de todo o projeto; compartilhar acopla o blast radius de dois produtos |
| Identidade | **Supabase Auth** (não Iron Session) | RLS depende de `auth.uid()`, que só existe com JWT do Supabase na requisição |
| Coleta | Por **município**, não por assinante | Custo marginal por cliente ≈ zero |
| Piloto | Só Horizonte, arquitetura multi-município | Expansão vira toggle, não refactor |
| Dados sigilosos | **Nunca persistidos** | Indefensável perante LGPD |
| Superadmin × suporte | **Flags independentes**, fora de `perfil` | Acessos quase opostos; fundir concentra poder |
| Acesso de suporte | Sessão temporária auditada, visível ao cliente | Defensável e vira argumento de venda |
| Municípios por plano | **Ilimitados** | Custo marginal zero; diferencial competitivo |
| Estouro de quota | Bloqueia o novo, preserva o existente | Cliente nunca perde o que já tinha |
| Prospecção (§4) | Alerta **institucional e informativo** | Contorna vedação de captação da OAB |
| Financeiro do escritório | Fora de escopo | Projeto do tamanho do MVP |

---

## 📚 Mapa da documentação

| Preciso de… | Leia |
| :--- | :--- |
| Visão geral, setup, stack | [README.md](README.md) |
| Como o sistema funciona | [docs/ARQUITETURA.md](docs/ARQUITETURA.md) |
| Schema, tabelas, RLS | [docs/MODELAGEM_DADOS.md](docs/MODELAGEM_DADOS.md) |
| Endpoints e campos do TCE | [docs/API_TCE.md](docs/API_TCE.md) |
| LGPD, OAB, política de coleta | [docs/CONFORMIDADE.md](docs/CONFORMIDADE.md) |
| Console `/interno`, suporte | [docs/CONSOLE_INTERNO.md](docs/CONSOLE_INTERNO.md) |
| Fases, guia Vercel/Supabase | [docs/PLANO_MVP.md](docs/PLANO_MVP.md) |
| Proposta para cliente | [docs/proposta/](docs/proposta/) |

---

## 🚧 Pendências

| # | Pendência | Quando | Status |
| :--- | :--- | :--- | :--- |
| 1 | Formalizar contato institucional com o TCE-CE sobre o uso (pesquisa de termos concluída, nenhum bloqueio encontrado) | Antes do lançamento | ⏳ |
| 2 | ~~Mapear 11 tabelas auxiliares~~ — resolvido na Fase 0: era host errado, não método | Fase 0 | ✅ |
| 3 | Parecer jurídico LGPD | Antes do lançamento | ⏳ |
| 4 | Parecer sobre OAB | Antes do lançamento | ⏳ |
| 5 | Política de Privacidade e Termos | Antes do lançamento | ⏳ |
| 6 | Definir DPO e canal do titular | Antes do lançamento | ⏳ |
| 7 | Provedor de WhatsApp (Cloud API vs. BSP) | Fase 3 | ⏳ |
| 8 | Gateway de pagamento | Fase 5 | ⏳ |
| 9 | **Nome comercial** — o atual é de repositório | Antes do lançamento | ⏳ |
| 10 | Pricing final | Reunião comercial | ⏳ |
| 11 | 10 processos de Horizonte fora de qualquer `exercicio` 2005–2026 — não impede o MVP (a varredura por página os alcança), mas explica por que `exercicio` não serve para particionar o sync | Quando otimizar o sync | ⏳ |
| 12 | Qual dos dois catálogos `tipo-documento` (809 itens em `api-processos` vs 569 em `contexto-api`) corresponde a `tipoAtoDocumento` dos documentos | Antes de modelar a tabela (Fase 1) | ⏳ |
| 13 | Confirmar em produção se `exibirDocumento: true` chega a ocorrer — nenhuma ocorrência em 564 documentos amostrados | Antes de liberar download (Fase 5) | ⏳ |
| 14 | Classificar as 60 ações coletadas em relevante/rotineira | Início da Fase 3 | ⏳ |

---

## 📋 Roadmap

| Fase | Duração | Entrega | Status |
| :--- | :--- | :--- | :--- |
| 0 | 1 sem | Spike técnico, go/no-go | ✅ **GO** (16/09/2026) |
| 1 | 2 sem | Auth, schema, RLS | ⬜ próxima |
| 2 | 3 sem | Ingestão + console interno | ⬜ |
| 3 | 2 sem | Detecção + notificação | ⬜ |
| 4 | 3 sem | Painel escritório + suporte | ⬜ |
| 5 | 3 sem | Painel gestor + peças → **vendável** | ⬜ |
| 6 | 2–3 sem | Kanban, Central de Ajuda | ⬜ |
| 7 | 3 sem | Indicadores, modelos, IA | ⬜ |

---

## 🤖 Ao iniciar um chat novo com IA

Cole isto no começo da conversa:

```
Projeto: Plataforma TCE (c:\Antigravity\Projetos\ControleProcessoTCE)

Leia ESTADO_DO_PROJETO.md na raiz inteiro, incluindo as seções
"Achados da Fase 0" (comportamentos reais da API, medidos — qtd
ignorado, flags de privacidade que não são booleanas, hosts das
tabelas auxiliares) e "Correções da revisão técnica" (7 problemas
de segurança já corrigidos: RLS do gestor, autenticação, fila de
notificação, privacidade, integridade entre tenants). Não reabra
essas decisões nem re-teste a API sem motivo novo.

Depois leia os documentos em docs/ que forem relevantes para a tarefa,
sempre a versão atual do arquivo (não se guie por PLAN.md, PLAN1.md ou
qualquer análise solta — a fonte de verdade é docs/ e este arquivo).

Tarefa de hoje: [DESCREVA AQUI — ex: "iniciar a Fase 0" ou
"criar o projeto Next.js e Supabase da Fase 1"]
```

Isso evita que a IA refaça análise já feita, reabra decisão já tomada, ou reintroduza um bug de RLS já corrigido.

---

## 📝 Manutenção deste arquivo

Atualize **sempre que**:

- Terminar uma fase ou tarefa relevante
- Tomar uma decisão que muda o rumo
- Descobrir algo técnico que não pode se perder
- **Antes de todo `git push`** — é o que a outra máquina vai ler

Seções que mudam com frequência: **Onde paramos**, **Pendências**, **Roadmap**.

Mantenha curto. Este é um índice de estado, não um diário — o detalhe mora em `docs/` e no histórico do Git.
