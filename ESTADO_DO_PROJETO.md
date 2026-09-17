# Estado do Projeto

> **Leia este arquivo primeiro** ao abrir o projeto em outra máquina ou iniciar um chat novo com IA.
> Ele responde: onde o projeto parou, o que já foi decidido e qual é o próximo passo.

**Última atualização:** 16/09/2026 (Fase 1 em andamento — schema do banco criado e aplicado)
**Branch:** `feat/fase-1-fundacao` (não mergeada em `main`) · **Remote:** `https://github.com/DelanoBarreto/ControleProcessoTCE.git`

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

**Fase atual:** **Fase 1 (Fundação) em andamento.** O banco de dados está criado, aplicado e com seed. O projeto Next.js **ainda não existe** — é o próximo passo.

**Feito nesta sessão (16/09/2026):**
- Criado o projeto Supabase **`Plataforma-Sistemas`** (ref `lwvwuhkwdrbmvwymbpwe`, `sa-east-1`), próprio, sem compartilhar com o PortalGov.
- **7 migrations** escritas e aplicadas com sucesso em `supabase/migrations/`: schema `plataforma` (identidade multi-sistema) + schema `tce` (espelho da API, operação, tenant) + RLS completa + seed.
- Seed aplicado: sistemas, papéis do TCE, **184 municípios do Ceará** (copiados de `plataforma.catalogo_municipios` do PortalGov), Horizonte ativo, 4 planos.
- Tudo commitado na branch `feat/fase-1-fundacao` (commit `d22010f`), **ainda não mergeado em `main`**, **ainda não empurrado para o GitHub** (verificar `git push` antes de trocar de máquina/IA).

> ⚠️ **Antes de continuar, leia "Decisão arquitetural: banco compartilhado multi-sistema" abaixo.** Esta sessão tomou uma decisão que **diverge de `docs/MODELAGEM_DADOS.md`**: a identidade (`escritorios`/`usuarios`) não é exclusiva do TCE — é um schema `plataforma` compartilhado com outros sistemas que vierem a existir (clínicas, gerencial, tarefas). Ler `MODELAGEM_DADOS.md` sozinho, sem esta seção, leva a reimplementar tabelas que já existem com nome diferente.

> ⚠️ Continua valendo ler "Correções da revisão técnica" e "Achados da Fase 0" abaixo antes de mexer na ingestão (Fase 2) — nada disso mudou.

**Próximo passo concreto:** criar o projeto Next.js 14 (App Router + TypeScript + Tailwind) na raiz, conectar ao Supabase via `@supabase/ssr`, montar o middleware de proteção de rota, e então dar entrada nos critérios de aceite da Fase 1 (login nos três níveis, teste de dois tenants, 403 em `/interno` sem `is_superadmin`).

**Pendente antes de seguir:**
- Preencher `SUPABASE_SECRET_KEY` no `.env.local` (pegar no painel: Settings → API → Secret keys → Reveal). Está em branco de propósito — não foi gerado/copiado por segurança.
- Decidir se a `service_role` do projeto é usada para operações administrativas gerais, ou se **só** a role dedicada `tce_ingestor` (criada na migration de RLS) deve tocar no espelho do TCE. Ver a seção de decisão abaixo.
- Rodar `npm install` (o `package.json` já existe, mas `node_modules` não foi instalado nesta sessão).

Duas coisas ficaram pendentes da Fase 0, nenhuma bloqueante:
- Classificar manualmente as 60 ações coletadas em relevante/rotineira — insumo da Fase 3, não da Fase 1.
- Investigar 10 processos de Horizonte que não caem em nenhum `exercicio` de 2005–2026 (ver pendência 11).

---

## 🏗️ Decisão arquitetural: banco compartilhado multi-sistema (16/09/2026)

**Contexto que motivou a mudança:** durante a Fase 1, foi descoberto que um `.env.local` já existia no projeto com chaves reais — mas apontando para o **banco de produção do PortalGov** (`PortalGov-Producao`), não para um banco do TCE. Nenhuma escrita foi feita nele (só leitura de metadados para diagnóstico). O usuário então explicou a intenção real: o banco do TCE não vai hospedar só o TCE — vai hospedar **múltiplos sistemas futuros** (clínicas, gerencial, planejamento de tarefas, etc.), no mesmo padrão que o `PortalGov-Producao` já usa para hospedar PortalGov + TCE Gerencial.

**Investigação do padrão existente:** o projeto `PortalGov-Producao` foi inspecionado (somente leitura) para entender como aquele compartilhamento funciona de fato. Achado: não é RLS por tabela — é um schema `plataforma` com `usuarios_sistema` (coluna `sistema`) e `organizacoes`, e **toda** autorização passa por funções RPC `SECURITY DEFINER` que verificam o papel em PL/pgSQL. As tabelas de `plataforma` no PortalGov estão **com RLS desabilitada de propósito**, confiando inteiramente nas RPCs.

**Decisão tomada:** criar um projeto Supabase **novo e separado** — `Plataforma-Sistemas` (ref `lwvwuhkwdrbmvwymbpwe`) — replicando esse padrão, mas **não** reaproveitando o projeto do PortalGov nem o `APITCE` existente (que é de outro escopo: dados abertos do SIM/orçamento, não processos). Um projeto por "família" de produtos vinculados ao usuário, não um projeto único para tudo.

**Diferença deliberada em relação ao PortalGov:**
- Aqui a **RLS fica ligada** em todas as tabelas de `plataforma`, mesmo as de identidade — ao contrário do PortalGov, que desliga e confia só na RPC. Razão: um caminho de acesso futuro que não passe pela RPC falha fechado em vez de expor a base de usuários.
- Foi adicionado `is_suporte` (boolean, independente do papel) em `usuarios_sistema` — o PortalGov não tem esse conceito. O TCE precisa de sessão de suporte técnico auditada (`plataforma.sessoes_suporte`), prevista desde `MODELAGEM_DADOS.md`.
- Foi criada uma **role de banco dedicada `tce_ingestor`** (não-login, `GRANT` só nas tabelas do schema `tce`) para o cron de sincronização. **Não usa `service_role`** do projeto: `service_role` alcançaria qualquer schema futuro (clínicas, gerencial), então uma chave vazada ou um bug no cron do TCE não deve conseguir tocar em dados de outro sistema hospedado no mesmo projeto. Isso é mais restrito que o padrão do PortalGov, que usa `service_role` normalmente nas RPCs administrativas.

**Mapeamento de nomes — MODELAGEM_DADOS.md → schema real:**

| `MODELAGEM_DADOS.md` (documento original) | Onde está de fato agora |
| :--- | :--- |
| `escritorios` | `plataforma.organizacoes` (genérico, não exclusivo do TCE) |
| `usuarios` | `plataforma.usuarios_sistema` (com `sistema = 'tce'`) |
| `usuarios.perfil` | `plataforma.usuarios_sistema.papel` (mesmos valores: `admin_escritorio`/`advogado`/`gestor_publico`) |
| `usuarios.is_superadmin` | `plataforma.papeis.nivel_plataforma = true` para o papel `superadmin` |
| `usuarios.is_suporte` | `plataforma.usuarios_sistema.is_suporte` (extensão nova, não existe no PortalGov) |
| Todo o resto (`processos`, `tramites`, `clientes`, `prazos`, `pecas`, kanban, etc.) | Igual ao documento, só que dentro do schema `tce.*` em vez de `public.*`, e toda referência a `usuarios`/`escritorios` virou referência a `plataforma.usuarios_sistema`/`plataforma.organizacoes` |

**`plataforma.catalogo_municipios`** (184 municípios do Ceará) foi **copiado** do PortalGov, não recriado do zero — é dado estável e já validado lá. É diferente de `tce.municipios`, que guarda o `id` de localidade **da API do TCE** (Horizonte = `72`), que **não é o mesmo número** que `catalogo_municipios.codigo` (Horizonte = `'068'`). As duas tabelas são ligadas por `tce.municipios.codigo_ibge`.

**Impacto em `docs/MODELAGEM_DADOS.md`:** o documento **não foi reescrito ainda** — continua descrevendo `escritorios`/`usuarios` como tabelas próprias do TCE. Isso é intencional por ora (evitar reescrever um documento extenso no meio de uma sessão), mas **precisa ser atualizado** antes que alguém implemente algo lendo só aquele arquivo. Até lá, esta seção do `ESTADO_DO_PROJETO.md` é a fonte de verdade sobre onde cada tabela mora de fato.

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

## ⚠️ Armadilhas da Fase 1 (descobertas testando)

Duas coisas que custaram tempo e não estão em nenhum documento de arquitetura:

**1. Schema fora de `public` não é visível pela API REST até ser exposto no painel.**
Criar as tabelas em `tce` não basta: o PostgREST só serve schemas listados em **Settings → API → Exposed schemas** (padrão: só `public`). Sem isso, toda query volta `PGRST106 — Invalid schema: tce`, e o efeito prático é a aplicação se comportar como se o usuário não tivesse permissão (redireciona para login, contagens zeradas) em vez de dar erro claro. **`tce` está exposto; `plataforma` não** — e é deliberado: a camada de identidade é alcançada apenas pelas funções wrapper em `tce.*` (`meu_contexto`, `meu_papel`, `tenho_acesso`…), nunca direto pelo cliente.

**2. Inserir usuário direto em `auth.users` quebra o login com HTTP 500.**
O GoTrue lê `confirmation_token`, `recovery_token`, `email_change`, `phone_change`, `reauthentication_token` e similares como string não-nula. Um `INSERT` manual deixa esses campos `NULL` e o login falha com `Scan error on column index 3, name "confirmation_token": converting NULL to string is unsupported` — que aparece na tela como "e-mail ou senha incorretos", mandando quem depura para o lado errado. Ou preencher com `''`, ou (preferível) criar usuário pela API de admin do Supabase.

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
| Schema, tabelas, RLS (desenho original — nomes divergem do banco real, ver seção acima) | [docs/MODELAGEM_DADOS.md](docs/MODELAGEM_DADOS.md) |
| Schema **como está de fato no banco** | `supabase/migrations/*.sql` (7 arquivos, 16/09/2026) |
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
| 1 | 2 sem | Auth, schema, RLS | 🔶 em andamento — schema/RLS/seed feitos; falta o projeto Next.js e Auth |
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
tabelas auxiliares), "Correções da revisão técnica" (7 problemas
de segurança já corrigidos: RLS do gestor, autenticação, fila de
notificação, privacidade, integridade entre tenants) e "Decisão
arquitetural: banco compartilhado multi-sistema" (o schema real no
banco diverge de MODELAGEM_DADOS.md — usuarios/escritorios viraram
plataforma.usuarios_sistema/plataforma.organizacoes). Não reabra
essas decisões nem re-teste a API sem motivo novo.

O código do schema já está aplicado no Supabase (projeto
Plataforma-Sistemas) e commitado em supabase/migrations/ na branch
feat/fase-1-fundacao (ainda não mergeada em main — confira
`git status` e `git log --oneline -5` antes de presumir o que já
foi enviado ao GitHub). Para saber o schema real, leia os arquivos
.sql em supabase/migrations/, não MODELAGEM_DADOS.md sozinho.

Depois leia os documentos em docs/ que forem relevantes para a tarefa,
sempre a versão atual do arquivo (não se guie por PLAN.md, PLAN1.md ou
qualquer análise solta — a fonte de verdade é docs/, supabase/migrations/
e este arquivo).

Tarefa de hoje: [DESCREVA AQUI — ex: "criar o projeto Next.js da Fase 1"
ou "atualizar MODELAGEM_DADOS.md para refletir o schema real"]
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
