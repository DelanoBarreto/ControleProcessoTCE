# Documentação — Plataforma TCE

Índice dos documentos do projeto. O ponto de entrada geral é o [README da raiz](../README.md).

---

## Técnicos

| Documento | Quando ler |
| :--- | :--- |
| [ARQUITETURA.md](ARQUITETURA.md) | Antes de escrever código. Camadas, fluxo de dados, decisões estruturais |
| [MODELAGEM_DADOS.md](MODELAGEM_DADOS.md) | Ao mexer em schema, query ou RLS |
| [API_TCE.md](API_TCE.md) | Ao trabalhar na coleta. Endpoints, campos e armadilhas verificadas |
| [CONSOLE_INTERNO.md](CONSOLE_INTERNO.md) | Ao mexer em `/interno/*`, permissões ou suporte |

## Conformidade

| Documento | Quando ler |
| :--- | :--- |
| [CONFORMIDADE.md](CONFORMIDADE.md) | **Obrigatório** antes de alterar coleta, notificação ou tratamento de dado pessoal |

## Produto

| Documento | Conteúdo |
| :--- | :--- |
| [PLANO_MVP.md](PLANO_MVP.md) | Roadmap por fases, guia Vercel/Supabase, análise competitiva |
| [proposta/PROPOSTA_PUBLICA.md](proposta/PROPOSTA_PUBLICA.md) | Proposta comercial — versão que circula |
| [proposta/PROPOSTA_INTERNA.md](proposta/PROPOSTA_INTERNA.md) | 🔒 Versão interna — piloto nominal, custos, riscos |

## Padrões de código

| Documento | Conteúdo |
| :--- | :--- |
| [PADRAO_V4_ELITE.md](PADRAO_V4_ELITE.md) | Padrão de UI: formulários, listagens, estados |
| [TEMPLATE_NOVO_SISTEMA.md](TEMPLATE_NOVO_SISTEMA.md) | Template de novo módulo |
| [COMANDOS.md](COMANDOS.md) | Comandos frequentes |
| [CHECKLIST_NOVO.md](CHECKLIST_NOVO.md) | Checklist de nova funcionalidade |

---

## Por onde começar

**Novo no projeto?** [README da raiz](../README.md) → [ARQUITETURA.md](ARQUITETURA.md) → [MODELAGEM_DADOS.md](MODELAGEM_DADOS.md)

**Vai mexer na coleta?** [API_TCE.md](API_TCE.md) → [CONFORMIDADE.md](CONFORMIDADE.md)

**Vai implementar uma fase?** [PLANO_MVP.md](PLANO_MVP.md)

---

## Arquivos originais

Os `.docx` e `.pdf` nesta pasta são as versões originais da proposta, anteriores à revisão. Mantidos como histórico. A versão vigente está em [proposta/](proposta/).
