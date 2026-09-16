# Estado do Projeto

> **Leia este arquivo primeiro** ao abrir o projeto em outra máquina ou iniciar um chat novo com IA.
> Ele responde: onde o projeto parou, o que já foi decidido e qual é o próximo passo.

**Última atualização:** 16/09/2026
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

**Fase atual:** Documentação concluída — **pré-código**

**Feito:** toda a documentação de fundação do projeto (arquitetura, modelagem, conformidade, plano de MVP, propostas comercial revisadas). Nenhuma linha de código de aplicação foi escrita ainda.

**Próximo passo:** **Fase 0 — Spike técnico** (ver [docs/PLANO_MVP.md](docs/PLANO_MVP.md))

Tarefas da Fase 0, em ordem:

1. 🔴 **Localizar os Termos de Uso do Portal Contexto do TCE** — *bloqueante*. Se restringirem uso automatizado, formalizar pedido de acesso a dados abertos antes de qualquer desenvolvimento.
2. Mapear as 11 tabelas auxiliares restantes da API (GET retornou 404; testar POST)
3. Medir o custo real de um sync completo de Horizonte (2.431 processos)
4. Validar que `tramites[].id` é estável entre coletas
5. Levantar amostra de `acao.descricao` para escrever as primeiras regras de classificação

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

---

## ✅ Decisões tomadas (não reabrir sem motivo)

| Decisão | Escolha | Razão |
| :--- | :--- | :--- |
| Infraestrutura | Vercel + Supabase (serverless) | API pública elimina necessidade de VPS |
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
| 1 | **Termos de Uso do TCE** — bloqueante | Fase 0 | 🔴 aberto |
| 2 | Mapear 11 tabelas auxiliares | Fase 0 | 🔴 aberto |
| 3 | Parecer jurídico LGPD | Antes do lançamento | ⏳ |
| 4 | Parecer sobre OAB | Antes do lançamento | ⏳ |
| 5 | Política de Privacidade e Termos | Antes do lançamento | ⏳ |
| 6 | Definir DPO e canal do titular | Antes do lançamento | ⏳ |
| 7 | Provedor de WhatsApp (Cloud API vs. BSP) | Fase 3 | ⏳ |
| 8 | Gateway de pagamento | Fase 5 | ⏳ |
| 9 | **Nome comercial** — o atual é de repositório | Antes do lançamento | ⏳ |
| 10 | Pricing final | Reunião comercial | ⏳ |

---

## 📋 Roadmap

| Fase | Duração | Entrega | Status |
| :--- | :--- | :--- | :--- |
| 0 | 1 sem | Spike técnico, go/no-go | ⬜ próxima |
| 1 | 2 sem | Auth, schema, RLS | ⬜ |
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

Leia ESTADO_DO_PROJETO.md na raiz — ele tem onde paramos, as decisões
já tomadas e o próximo passo. Depois leia os documentos em docs/ que
forem relevantes para a tarefa.

Tarefa de hoje: [DESCREVA AQUI]
```

Isso evita que a IA refaça análise já feita ou reabra decisão já tomada.

---

## 📝 Manutenção deste arquivo

Atualize **sempre que**:

- Terminar uma fase ou tarefa relevante
- Tomar uma decisão que muda o rumo
- Descobrir algo técnico que não pode se perder
- **Antes de todo `git push`** — é o que a outra máquina vai ler

Seções que mudam com frequência: **Onde paramos**, **Pendências**, **Roadmap**.

Mantenha curto. Este é um índice de estado, não um diário — o detalhe mora em `docs/` e no histórico do Git.
