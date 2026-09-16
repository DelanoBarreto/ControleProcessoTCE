# Template — ESTADO_DO_PROJETO.md

Copiar para a raiz do projeto como `ESTADO_DO_PROJETO.md` e preencher. Remover qualquer seção que não fizer sentido para o projeto (nem todo projeto tem "pendências jurídicas", por exemplo) — o valor está nas seções que sobram serem verdadeiras e atuais, não em seguir a lista inteira.

````markdown
# Estado do Projeto

> **Leia este arquivo primeiro** ao abrir o projeto em outra máquina, iniciar um chat novo com IA, ou invocar /onde-paramos.

**Última atualização:** DD/MM/AAAA
**Branch:** `main` · **Remote:** `<url do repositório>`

---

## 🔄 Ao trocar de máquina

```bash
git pull origin main          # ANTES de começar

git add -A                    # DEPOIS de terminar (mesmo inacabado)
git commit -m "tipo(escopo): descricao"
git push origin main
```

> Atualize "Onde paramos" antes do push — é o que a outra máquina (ou a próxima sessão de IA) vai ler.

---

## 📍 Onde paramos

**Fase atual:** <uma frase>

**Feito:** <o que foi concluído nesta fase ou sprint>

**Em andamento:** <o que ficou pela metade — e onde exatamente, com arquivo/linha se ajudar>

**Próximo passo:**
1. <tarefa concreta e acionável>
2. <tarefa concreta e acionável>

---

## 🎯 O que é o projeto

<2-4 linhas. Assuma que quem lê não conhece nada do projeto ainda.>

---

## ⚡ Descobertas que não podem se perder

<Comportamento de API, armadilha de configuração, workaround, comando de
verificação que funciona — qualquer coisa que custou tempo real para
descobrir e que seria caro redescobrir. Inclua o comando/trecho exato,
não só a descrição.>

---

## ✅ Decisões tomadas (não reabrir sem motivo novo)

| Decisão | Escolha | Razão |
| :--- | :--- | :--- |
| | | |

A coluna "Razão" não é opcional — decisão sem razão registrada é reaberta
na semana seguinte pela próxima pessoa (ou IA) que passar por aqui.

---

## 📚 Mapa da documentação

| Preciso de… | Leia |
| :--- | :--- |
| | |

---

## 🚧 Pendências

| # | Pendência | Quando | Status |
| :--- | :--- | :--- | :--- |
| 1 | | | 🔴 bloqueante / ⏳ aberto / ✅ resolvido |

---

## 📋 Roadmap

| Fase | Entrega | Status |
| :--- | :--- | :--- |
| | | ⬜ não iniciado / 🔄 em andamento / ✅ concluído |

---

## 🤖 Ao iniciar um chat novo com IA

```
Projeto: <nome> (<caminho ou URL>)

Leia ESTADO_DO_PROJETO.md na raiz inteiro — ele tem onde paramos, as
decisões já tomadas (com a razão) e o próximo passo. Não reabra essas
decisões sem motivo novo. Depois leia os documentos em docs/ (ou
equivalente) que forem relevantes para a tarefa de hoje.

Tarefa de hoje: [DESCREVA]
```

Ou, mais simples, se a skill `onde-paramos` estiver instalada no projeto: digitar `/onde-paramos`.

---

## 📝 Manutenção deste arquivo

Atualizar ao terminar uma tarefa relevante, tomar uma decisão que muda o
rumo, descobrir algo que não pode se perder, e **antes de todo `git push`**.

Mudanças cirúrgicas — tocar só a seção relevante à sessão atual. Não
reescrever o arquivo inteiro nem "melhorar" texto que não mudou.
````

---

## Notas de preenchimento

**"Onde paramos" é a seção que mais importa.** Se só houver tempo para atualizar uma coisa antes de fechar a sessão, é essa.

**Seções específicas de domínio** (conformidade jurídica, integração externa, particularidades de infraestrutura) podem ser adicionadas livremente — o template acima é o mínimo comum, não um teto. O `ESTADO_DO_PROJETO.md` do projeto `ControleProcessoTCE` tem, por exemplo, uma seção "Correções da revisão técnica" que não está aqui porque é específica daquele momento do projeto.

**Não usar este arquivo como diário.** Detalhe técnico profundo (schema completo, especificação de API, arquitetura) mora em outros documentos do projeto (`docs/`, `README.md`). Aqui fica só o que uma nova sessão precisa para não perder tempo refazendo o que já foi feito.
