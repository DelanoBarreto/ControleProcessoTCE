# PROPOSTA DE PROJETO
## Plataforma de Monitoramento e Gestão de Processos do TCE
### MVP Piloto — Tribunal de Contas do Estado do Ceará (TCE-CE)

Um sistema que acompanha automaticamente tudo o que acontece com o processo de um gestor municipal no TCE, avisa quem precisa saber e organiza o trabalho de defesa — em um só lugar.

---

## 1. O problema que resolvemos

Gestores municipais — prefeitos, secretários, ordenadores de despesa — têm processos tramitando no TCE e, na maioria das vezes, não sabem em que fase o processo está, se já foi julgado, se há prazo correndo ou se a defesa apresentada foi suficiente.

Isso gera:

- **Perda de prazos de defesa** por falta de aviso a tempo;
- **Falta de transparência** entre o gestor e o advogado responsável pelo caso;
- **Escritórios jurídicos e contábeis sem ferramenta própria** para controlar, em um só lugar, todos os processos de seus clientes no TCE;
- **Gestores que só descobrem que estão sendo julgados quando já é tarde demais.**

---

## 2. O que é a plataforma

Uma plataforma web (SaaS, por assinatura) com duas frentes de uso que conversam entre si:

### Versão Gestor Público
O prefeito ou secretário acompanha pelo celular ou computador o andamento do seu processo, recebe explicações em linguagem simples e pode aprovar ou pedir ajustes na petição do seu próprio advogado.

### Versão Escritório Jurídico/Contábil
Painel completo de gestão processual: documentos, despachos, prazos, petições, tarefas e histórico de todos os processos de todos os clientes do escritório no TCE.

---

## 3. Como funciona, na prática

### 3.1 Monitoramento automático diário

A plataforma verifica diariamente a movimentação pública dos processos no TCE — por município, ano ou número de processo — identificando qualquer novidade: novo despacho, prazo aberto, julgamento, decisão.

> **Viabilidade técnica confirmada.** O TCE-CE disponibiliza os dados processuais por meio de um serviço público estruturado de consulta. O monitoramento é feito sobre informação oficial e aberta, sem qualquer acesso restrito.

### 3.2 Só o que importa vira alerta

Nem toda movimentação merece um aviso. A maior parte dos registros é trâmite administrativo interno, sem impacto para o gestor.

A plataforma classifica cada movimentação em três níveis:

| Nível | Exemplos | O que acontece |
| :--- | :--- | :--- |
| **Crítico** | Citação, audiência, prazo aberto, julgamento | Aviso imediato por WhatsApp e e-mail + tarefa criada |
| **Relevante** | Distribuição a relator, parecer | E-mail e destaque no painel |
| **Rotina** | Encaminhamentos internos | Fica no histórico, sem aviso |

É isso que diferencia um sistema útil de um gerador de notificações ignoradas.

### 3.3 Controle de prazos com regras do TCE

Prazos de Tribunal de Contas têm regras de contagem próprias, diferentes das da Justiça comum. A plataforma calcula a data-limite automaticamente e **mostra a memória do cálculo** — marco inicial, dias considerados e feriados descontados —, para que o advogado confira, e não apenas confie.

### 3.4 Controle jurídico completo para o escritório

- Cadastro de clientes e processos, com documentos e despachos organizados;
- Controle de prazos e alertas de vencimento;
- Elaboração e histórico de petições e defesas;
- Gestão de tarefas da equipe, com quadros e responsáveis;
- Visão consolidada de todos os processos, por status.

### 3.5 Transparência e aprovação pelo gestor

O gestor entra na sua área exclusiva e vê o que o advogado já fez: se respondeu, se protocolou, em que fase está.

Quando o escritório prepara uma defesa, o gestor **lê, comenta e aprova — ou solicita ajustes — dentro da plataforma**. Cada versão fica registrada, e a aprovação é documentada com data e hora.

> Isso encerra a troca de e-mails soltos e ligações, e **protege o escritório**: há registro formal de que o cliente aprovou aquela versão da peça.

---

## 4. Alerta gratuito: informação pública que chega a quem importa

O TCE publica os processos, mas **não avisa o gestor**. A informação existe e não chega a quem é afetado por ela.

A plataforma oferece um **serviço gratuito de alerta**: o gestor que tem processo em andamento é informado de que existe movimentação em seu nome, com orientação inicial sobre o que aquilo significa.

**O que isso produz:**

- Utilidade pública real — o gestor passa a saber o que antes só descobria tarde;
- Demonstração de valor **antes** de qualquer contratação;
- O gestor que decide buscar assessoria já conhece a plataforma e o escritório que a utiliza;
- Um canal de relacionamento sustentável, baseado em serviço prestado e não em abordagem comercial.

> **O alerta é informativo e institucional.** Não é oferta de serviço jurídico, não é assinado por advogado ou escritório, e traz opção de descadastramento em toda comunicação. Quem decide procurar assessoria é o gestor.

---

## 5. Conformidade e transparência

O tratamento de dados foi desenhado desde o início para atender à LGPD e às normas da advocacia.

**Origem dos dados.** Exclusivamente informação pública de transparência do TCE-CE. Nenhum acesso a sistema restrito, nenhum dado obtido por meio irregular.

**Respeito ao sigilo.** Processos marcados como sigilosos pelo próprio TCE **não são coletados nem armazenados**. Nomes de pessoas com sigilo preservado não são registrados. O filtro atua antes de qualquer gravação.

**Base legal e direito de oposição.** O contato informativo com gestores tem base em legítimo interesse, com análise de balanceamento documentada. Toda comunicação traz descadastramento de efeito imediato e permanente.

**Isolamento entre escritórios.** Cada escritório acessa exclusivamente os próprios dados, com isolamento aplicado na camada de banco de dados — não apenas na interface.

**Acesso de suporte controlado.** Quando a equipe de suporte precisa acessar a conta de um cliente para ajudá-lo, abre uma **sessão temporária com prazo, motivo registrado e trilha de auditoria** — e **o cliente é avisado** enquanto o acesso está ativo. Não há acesso permanente de terceiros aos dados de nenhum escritório.

**Coleta responsável.** Consulta com ritmo limitado e identificação transparente, ainda que o serviço público não imponha restrição técnica.

---

## 6. Modelo de negócio

| Plano | Para quem | Inclui |
| :--- | :--- | :--- |
| **Gratuito** | Gestores em geral | Consulta básica de status |
| **Gestor** | Gestor individual | Acompanhamento completo, alertas por WhatsApp e e-mail, acesso à atuação do advogado |
| **Escritório** | Escritórios jurídicos/contábeis | Gestão completa de processos e clientes, tarefas, prazos e aprovação de peças |
| **Escritório Plus** | Escritórios maiores | Maior volume de processos, usuários e recursos avançados |

Os planos escalam por volume de processos monitorados, usuários e recursos.

> **Municípios ilimitados em todos os planos.** O escritório acompanha clientes em quantos municípios precisar, sem custo adicional por abrangência — vantagem que decorre diretamente da arquitetura da plataforma.

Teste gratuito, sem necessidade de cartão de crédito.

---

## 7. Escopo do projeto piloto

- **Abrangência:** Tribunal de Contas do Estado do Ceará (TCE-CE);
- **Formato:** piloto controlado, com grupo reduzido de municípios e clientes para validação;
- Coleta automática dos dados públicos de processos;
- Painel do gestor e painel do escritório;
- Classificação inteligente de movimentações e controle de prazos;
- Notificações automáticas por e-mail e WhatsApp;
- Base pronta para expansão a outros municípios do Ceará e, depois, a outros Tribunais de Contas.

### Critérios de sucesso

O piloto será considerado validado se, ao seu término:

| Indicador | Meta |
| :--- | :--- |
| Processos monitorados com sucesso | Município-piloto integralmente coberto |
| Tempo entre movimentação e aviso | Menos de 24 horas |
| Precisão da classificação | Nenhuma movimentação crítica não notificada |
| Adoção pelo escritório | Uso efetivo do painel na rotina, sem planilha paralela |
| Aprovação de peças pelo gestor | Ciclo completo realizado ao menos uma vez |

### Prazo estimado

Aproximadamente **13 semanas** até a versão utilizável em produção, distribuídas em fases com entregas verificáveis. Recursos complementares — relatórios gerenciais, modelos de documento e assistente de IA — seguem em fases posteriores.

---

## 8. Por que agora é o momento certo

**Não existe hoje plataforma especializada em Tribunais de Contas.** As ferramentas jurídicas de mercado cobrem processos da Justiça comum — nenhuma monitora o TCE. O nicho está aberto.

**O TCE-CE disponibiliza os dados publicamente e de forma estruturada**, o que torna o monitoramento viável, legal e confiável.

**A estrutura de custos favorece a escala.** O monitoramento é feito por município e aproveitado por todos os assinantes — ampliar a cobertura não multiplica o custo. É isso que permite oferecer municípios ilimitados.

**Começar pelo Ceará, com piloto controlado, valida o modelo** antes de expandir para outros municípios e estados.

---

## 9. Próximos passos propostos

1. **Reunião de alinhamento** para validar o escopo do piloto e o cronograma;
2. **Definição do modelo comercial** — investimento, prazos e formato de parceria;
3. **Início do desenvolvimento**, começando pela validação técnica e formalização junto ao TCE quanto ao uso dos dados públicos.

---

*Documento preparado para apresentação e discussão de viabilidade comercial. A análise de conformidade apresentada na seção 5 reflete o desenho técnico adotado e será submetida a validação jurídica formal antes do lançamento comercial.*
