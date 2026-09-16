# PROPOSTA — VERSÃO INTERNA
## Plataforma de Monitoramento e Gestão de Processos do TCE

> 🔒 **USO INTERNO.** Contém município-piloto nominal, dados de viabilidade, estrutura de custos e riscos. Para circular externamente, use [PROPOSTA_PUBLICA.md](PROPOSTA_PUBLICA.md).

---

## 1. Resumo executivo

SaaS de monitoramento de processos do TCE-CE, com dois painéis (gestor público e escritório jurídico), alertas automáticos e gestão processual completa.

**Diferencial central:** ninguém monitora Tribunais de Contas. Todas as ferramentas jurídicas de mercado — inclusive o líder Astrea, com 120 mil usuários — cobrem apenas a Justiça comum.

**Viabilidade técnica: confirmada.** Ver seção 3.

---

## 2. Piloto: Horizonte/CE

| Item | Dado |
| :--- | :--- |
| Município | **Horizonte/CE** — `localidade id = 72` na API do TCE |
| Processos disponíveis | **2.431** (verificado em 16/09/2026) |
| Páginas de listagem | 244 (10 por página) |
| Expansão | 184 municípios acessíveis pela mesma API |

A arquitetura nasce multi-município: ativar outro município é um toggle no console interno, não desenvolvimento.

---

## 3. Viabilidade técnica — o que a investigação revelou

Investigação conduzida em **16/09/2026** sobre o Portal Contexto do TCE-CE.

### A descoberta principal

**O TCE-CE expõe uma API REST pública, sem autenticação, retornando JSON estruturado.**

Consequências diretas:

| Antes se supunha | Realidade |
| :--- | :--- |
| Raspagem de HTML | API estruturada |
| Playwright / browser headless | Requisição HTTP simples |
| Quebra a cada mudança de layout | Contrato estável de dados |
| Servidor dedicado (VPS) | **Serverless viável** |
| Semanas para a camada de coleta | Dias |

Isso reduz drasticamente custo, prazo e risco técnico do projeto.

### O que a API entrega

| Endpoint | Retorna |
| :--- | :--- |
| `POST /processos/porLista` | Listagem paginada com filtros (município, espécie, relator…) |
| `POST /processos/porNumero` | **Detalhe completo**: trâmites, documentos, julgamentos, interessados |
| `GET /tabelas-auxiliares/localidade` | 184 municípios |

`tramites[].id` é numérico e crescente → chave natural de deduplicação. **É o mecanismo de detecção de movimentação nova.**

### Condições operacionais

- **Sem rate limit detectado** — 5 requisições consecutivas, todas bem-sucedidas, 2–5s cada
- **robots.txt não bloqueia** a API nem o portal de consulta
- Sem Swagger/documentação oficial publicada

> ⚠️ **Risco a mitigar:** a API não é versionada e não tem documentação pública. Pode mudar sem aviso. O `TceClient` valida o formato da resposta e falha alto se o contrato mudar, em vez de gravar dado corrompido.

Detalhamento completo em [API_TCE.md](../API_TCE.md).

---

## 4. Seção 4 da proposta pública: o risco e como foi tratado

A prospecção ativa de gestores é o maior ativo comercial **e a maior exposição jurídica** do projeto. Três frentes:

### 4.1 LGPD

Dado público não é dado livre. A finalidade original (transparência) não autoriza automaticamente a finalidade nova (prospecção).

**Tratamento:** base de legítimo interesse (Art. 7º, IX), com teste de balanceamento documentado, opt-out funcional e permanente, e origem do dado declarada no primeiro contato.

### 4.2 Ética profissional (OAB)

O Código de Ética veda captação de clientela. Escritório abordando gestor com "vi que você tem processo no TCE" pode configurar infração disciplinar.

**Tratamento — a decisão que viabiliza o modelo:**

| ❌ Não fazemos | ✅ Fazemos |
| :--- | :--- |
| Escritório aborda oferecendo serviço | **Plataforma** envia alerta informativo gratuito |
| Alerta assinado por advogado | Alerta institucional, da plataforma |
| Lista de prospecção entregue ao escritório | Escritório **não** recebe lista de não-clientes |

> **Regra crítica:** entregar lista de gestores não-clientes ao escritório transfere o risco disciplinar para o cliente e recria exatamente o problema que o posicionamento evita. **Não fazer, em nenhuma hipótese.**

### 4.3 Termos de uso do TCE

**Pesquisado em 17/09/2026 — resolvido, sem bloqueio.** Não existe termo de uso dedicado ao Portal Contexto ou à sua API, publicado ou vinculado (verificado no site, rodapé, central de ajuda e busca externa).

Dois achados favoráveis durante a pesquisa:

- O TCE-CE mantém e **divulga publicamente** uma API de dados abertos institucional (o **SIM**, para dados de licitação/orçamento/folha — sistema distinto do Contexto), com política de uso que **incentiva explicitamente** automação de consulta a dados públicos. Não autoriza a API do Contexto por si só, mas evidencia postura institucional favorável.
- A norma de sigilo aplicável — **Resolução Administrativa nº 05/2024/TCE-CE** — já está refletida tecnicamente nas flags que a própria API retorna (`sigiloso`, `exibirDocumento`), que o `TceClient` respeita.

**Não bloqueia mais o desenvolvimento.** Resta, como item de governança antes do lançamento comercial (não antes de codar): formalizar contato institucional com o TCE-CE (Ouvidoria ou TI) para comunicar o uso e obter posicionamento oficial.

Análise completa em [CONFORMIDADE.md § Pesquisa de termos de uso](../CONFORMIDADE.md#pesquisa-de-termos-de-uso-17092026).

---

## 5. Cronograma e investimento

### Fases

| Fase | Duração | Entrega |
| :--- | :--- | :--- |
| 0 — Spike técnico | 1 sem | Validação e decisão go/no-go |
| 1 — Fundação | 2 sem | Auth, schema, RLS |
| 2 — Ingestão + Console | 3 sem | Horizonte sincronizado |
| 3 — Detecção + Notificação | 2 sem | **O produto funciona** |
| 4 — Painel Escritório | 3 sem | Cliente opera sozinho |
| 5 — Painel Gestor + Peças | 3 sem | **Piloto vendável** |
| **Subtotal** | **14 sem** | **Produto comercializável** |
| 6 — Atividades + Ajuda | 2–3 sem | Kanban, Central de Ajuda |
| 7 — Indicadores + IA | 3 sem | Relatórios, modelos, IA |

**Marco comercial: fim da Fase 5.** Fases 6–7 são expansão de valor — vendáveis como evolução, não pré-requisito.

### Custos de infraestrutura no piloto

| Serviço | Plano | Custo |
| :--- | :--- | :--- |
| Supabase | Free (500 MB) | R$ 0 |
| Vercel | Free / Pro | R$ 0 a ~US$ 20 |
| Resend | Free (3.000 e-mails/mês) | R$ 0 |
| WhatsApp Cloud API | 1.000 conversas/mês grátis | R$ 0 |

**O piloto cabe em tier gratuito**, exceto se a notificação precisar rodar a cada 15 minutos (exige Vercel Pro).

> Custo de infraestrutura é irrelevante nesta fase. O investimento é desenvolvimento.

### A economia estrutural

A coleta é **por município**, não por assinante. Sincronizar Horizonte custa o mesmo com 1 ou 50 escritórios clientes.

**Custo marginal por cliente é próximo de zero.** É a vantagem que sustenta preço agressivo e municípios ilimitados — e que o Astrea, que cobra por "nomes para captura", não consegue replicar.

---

## 6. Análise competitiva — Astrea

| Plano | Preço/mês | Processos | Usuários | Storage |
| :--- | ---: | ---: | ---: | ---: |
| Light | Grátis 1 ano | 40 | 1 | 1 GB |
| Up | R$ 209 | 150 | 2 | 10 GB |
| Smart | R$ 379 | 500 | 5 | 20 GB |
| Company | R$ 689 | 1.000 | 10 | 30 GB |
| VIP | R$ 1.249 | 2.000 | 30 | 50 GB |

120 mil usuários, 4,8/5. Trial de 10 dias sem cartão.

**Astrea não cobre Tribunais de Contas.** Referência de UX e pricing, não concorrente direto.

### Pricing proposto

| Plano | Faixa | Processos | Usuários | Storage | WhatsApp/mês |
| :--- | ---: | ---: | ---: | ---: | ---: |
| Gratuito | R$ 0 | 5 | 1 | 100 MB | 0 |
| Gestor | R$ 97–149 | 25 | 2 | 1 GB | 100 |
| Escritório | R$ 349–599 | 300 | 5 | 10 GB | 1.000 |
| Escritório Plus | R$ 899–1.199 | 1.000 | 15 | 30 GB | 5.000 |

**Municípios ilimitados em todos.**

Ancoragem: "Escritório" abaixo do Smart (R$ 379) por ser vertical mais estreito, com espaço de upsell.

> **Quota de WhatsApp existe para proteger margem.** A Cloud API cobra por conversa; sem teto, cliente com muitos processos gera prejuízo. Quota esgotada **degrada para e-mail**, nunca silencia o alerta.

---

## 7. Riscos

| Risco | Impacto | Mitigação |
| :--- | :--- | :--- |
| Termos de uso do TCE restringem automação | 🟢 Baixo (pesquisado) | Nenhum termo dedicado encontrado (17/09); formalizar contato institucional antes do lançamento |
| **API muda sem aviso** | 🟠 Alto | `TceClient` valida shape e falha alto; alerta no console |
| **Questionamento ético (OAB)** | 🟠 Alto | Alerta institucional, sem oferta de serviço; parecer antes do lançamento |
| **Classificação ruim de trâmites** | 🟠 Alto | Sem ela o cliente desliga o alerta. Regras editáveis + curadoria ativa no piloto |
| TCE fecha a API | 🟡 Médio | Consulta manual assistida como degradação; negociar acesso institucional |
| Baixa adesão do gestor a WhatsApp | 🟡 Médio | E-mail como canal primário; WhatsApp complementar |
| Concorrente entra no nicho | 🟢 Baixo | Barreira é conhecimento de domínio (prazos, classificação), não software |

### O risco mais subestimado

**A classificação de trâmites.** A maior parte dos registros do TCE é ruído administrativo. Notificar tudo faz o cliente desligar o alerta em uma semana — e um produto de alerta que ninguém lê não tem valor.

Tratamento: regras determinísticas editáveis sem deploy + curadoria ativa durante o piloto. É trabalho contínuo, não entrega única.

---

## 8. Decisões tomadas

| Decisão | Escolha | Razão |
| :--- | :--- | :--- |
| Infraestrutura | Vercel + Supabase (serverless) | API pública elimina necessidade de VPS |
| Abrangência do piloto | Só Horizonte, arquitetura multi-município | Piloto barato, expansão por toggle |
| Dados sigilosos | Nunca persistidos | Indefensável perante LGPD |
| Superadmin vs. suporte | Flags independentes | Acessos quase opostos; fundir concentra poder |
| Acesso de suporte | Sessão temporária auditada, visível ao cliente | Defensável e vira argumento de venda |
| Estouro de quota | Bloqueia o novo, preserva o existente | Previsível; cliente nunca perde o que tinha |
| Municípios | Ilimitados | Custo marginal zero; diferencial competitivo |
| Financeiro do escritório | Fora de escopo | Projeto do tamanho do MVP |

---

## 9. Pendências

| # | Pendência | Prazo |
| :--- | :--- | :--- |
| 1 | Formalizar contato institucional com o TCE-CE (pesquisa concluída, sem bloqueio) | Antes do lançamento |
| 2 | Mapear 11 tabelas auxiliares restantes | Fase 0 |
| 3 | Parecer jurídico LGPD (teste de balanceamento) | Antes do lançamento |
| 4 | Parecer sobre posicionamento OAB | Antes do lançamento |
| 5 | Política de Privacidade e Termos de Uso | Antes do lançamento |
| 6 | Definir DPO e canal do titular | Antes do lançamento |
| 7 | Gateway de pagamento | Fase 5 |
| 8 | Provedor WhatsApp: Cloud API vs. BSP | Fase 3 |
| 9 | **Nome comercial** — `ControleProcessoTCE` é repositório, não marca | Antes do lançamento |
| 10 | Pricing final | Reunião comercial |

---

## 10. Recomendação

**Prosseguir.** A pesquisa de termos de uso (17/09/2026) não encontrou restrição publicada — deixa de ser condição bloqueante da Fase 0.

A descoberta da API pública elimina o maior risco técnico e reduz prazo e custo de forma significativa. O nicho está comprovadamente aberto — o líder de mercado, com 120 mil usuários, não atende Tribunais de Contas.

O risco remanescente é **jurídico, não técnico**, e está concentrado na estratégia de prospecção. O reposicionamento do alerta como serviço informativo institucional endereça a parte principal, mas exige validação profissional antes do lançamento comercial.

**A formalização de contato institucional com o TCE-CE segue recomendada antes do lançamento comercial**, como boa prática de relacionamento — não mais como bloqueio ao desenvolvimento.

---

## Documentação de referência

- [API_TCE.md](../API_TCE.md) — endpoints e campos verificados
- [ARQUITETURA.md](../ARQUITETURA.md) — decisões técnicas
- [MODELAGEM_DADOS.md](../MODELAGEM_DADOS.md) — schema e RLS
- [CONFORMIDADE.md](../CONFORMIDADE.md) — LGPD, OAB, política de coleta
- [CONSOLE_INTERNO.md](../CONSOLE_INTERNO.md) — operação e suporte
- [PLANO_MVP.md](../PLANO_MVP.md) — fases e guia Vercel/Supabase
