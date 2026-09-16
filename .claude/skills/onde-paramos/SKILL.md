---
name: onde-paramos
description: Use no início de QUALQUER conversa sobre um projeto que tenha um arquivo ESTADO_DO_PROJETO.md (ou equivalente) na raiz — ou quando o usuário perguntar "onde paramos", "em que pé está o projeto", "o que falta fazer aqui", pedir para "retomar" um projeto, ou digitar /onde-paramos. Lê o estado real do projeto (arquivo de estado + git), resume onde o trabalho parou e qual é a próxima ação, sem o usuário precisar reexplicar o histórico. Funciona em qualquer projeto, de qualquer computador, chamada por qualquer IA — não é específica de um projeto. Também orienta a atualizar o arquivo de estado ao final da sessão e a criá-lo do zero em projeto que ainda não tenha um.
---

# Onde Paramos

Skill **global e portátil** — funciona em qualquer projeto, em qualquer computador, chamada por qualquer sessão de IA (Claude Code, outro chat, outra máquina). Não depende de nomes de arquivo, decisões ou histórico específicos de um projeto: ela lê o que existir e se adapta.

**Problema que resolve:** o usuário trabalha em várias máquinas e abre um chat novo a cada tarefa. Sem isso, cada nova sessão de IA reconstrói o contexto do zero, perde decisões já tomadas, ou pior — reabre debates já fechados e reintroduz bugs já corrigidos.

**Como resolve:** um arquivo `ESTADO_DO_PROJETO.md` na raiz do projeto é a fonte única de verdade sobre onde o trabalho parou. Esta skill sabe ler esse arquivo, confrontá-lo com o `git log`/`git status` reais, resumir para o usuário, e sabe também criar esse arquivo do zero em projeto que ainda não tenha um.

---

## Ao ser invocada no início de uma conversa

### 1. Localizar o arquivo de estado

Procurar, nesta ordem, na raiz do projeto atual (diretório de trabalho):

1. `ESTADO_DO_PROJETO.md`
2. `docs/ESTADO_DO_PROJETO.md`
3. Um arquivo que o próprio `README.md` aponte como "fonte de verdade" ou "estado do projeto"
4. Se nenhum existir → ir direto para a seção **"Projeto sem arquivo de estado"** abaixo

Não adivinhar nome de arquivo específico de projeto (ex.: não presumir `docs/17-PLANO-X.md` de outro projeto). O contrato é sempre `ESTADO_DO_PROJETO.md` na raiz — é o que torna a skill portátil entre projetos diferentes.

### 2. Ler o arquivo de estado por completo

Arquivos de estado bem escritos são curtos (ver "Formato de referência" abaixo) — ler o inteiro é barato e evita perder uma seção de "correções recentes" ou "não reabrir sem motivo" que ficaria fora de um resumo.

Prestar atenção especial a:
- A seção de **"onde paramos" / "estado atual" / "próximo passo"** (o nome varia por projeto, o conteúdo é sempre este)
- Qualquer seção de **decisões já tomadas** — não trazê-las de volta como novidade
- Qualquer seção de **correções ou achados recentes** — o código ainda pode não refletir a correção; não presumir que já foi aplicada sem checar
- Data da última atualização — se for antiga (>2 semanas), tratar o conteúdo com mais cautela e confrontar com o git com mais rigor

### 3. Confrontar com a realidade do repositório

```bash
git status --short
git log -5 --oneline
git log -1 --format="%ci"   # data do último commit
```

Se o projeto usa branches de trabalho, também:
```bash
git branch --show-current
git fetch -q && git rev-list --left-right --count HEAD...origin/$(git branch --show-current)
```

**Se houver divergência** entre o que o arquivo de estado diz e o que o git mostra (ex.: o arquivo diz "não commitado ainda" mas o log mostra commit recente; ou há mudanças não commitadas que o arquivo não menciona) — **avisar o usuário antes de prosseguir**. Não presumir qual versão está certa nem silenciosamente escolher uma.

### 4. Resumir para o usuário, em poucas linhas

Formato:
- Onde o projeto está agora (fase/status).
- O que está feito e o que está em andamento ou bloqueado (com o motivo, se houver).
- Decisões relevantes já tomadas que afetam a tarefa de hoje (só as relevantes — não recitar a tabela inteira).
- Qual é a próxima ação concreta, segundo o próprio arquivo.
- Qualquer divergência achada no passo 3.

Não adicionar jargão do projeto que o usuário não usou primeiro. Adaptar a densidade ao que o próprio arquivo de estado sugere sobre o nível técnico do usuário.

### 5. Perguntar objetivamente

Perguntar se o usuário quer seguir a próxima ação recomendada pelo arquivo, ou se tem outra coisa em mente para esta sessão. Não assumir — ele pode estar abrindo o chat para uma tarefa pontual que não é a próxima da fila.

---

## Projeto sem arquivo de estado

Se não existir `ESTADO_DO_PROJETO.md` (nem equivalente apontado pelo README), **oferecer criar um agora**, usando o template em `references/template.md` desta skill.

Antes de escrever, levantar o mínimo necessário:
- `git log --oneline -10`, `git remote -v`, `git status --short`
- Ler `README.md` se existir, para o pitch do projeto
- Perguntar ao usuário, se não for óbvio pelo código: qual é a fase atual e qual é o próximo passo

Preencher o template com o que foi levantado — não deixar seções genéricas de exemplo no arquivo final. Ver a seção "Formato de referência" abaixo para os princípios de como escrever cada seção.

---

## Ao final de uma sessão de trabalho

Quando o usuário indicar que terminou algo nesta conversa (uma tarefa concluída, uma decisão tomada, um bloqueio encontrado) — ou **antes de qualquer `git push`**:

1. **Atualizar o arquivo de estado com o que de fato mudou:**
   - Atualizar a seção de "onde paramos" para refletir o novo estado real — não acrescentar sem revisar o que ficou obsoleto.
   - Se uma decisão nova foi tomada, registrá-la na tabela de decisões **com a razão** — decisão sem razão registrada é reaberta na semana seguinte.
   - Se algo foi descoberto que custou trabalho (comportamento de API, armadilha, workaround), registrar na seção de descobertas — é o tipo de conhecimento mais caro de perder.
   - Atualizar a data no topo do arquivo.

2. **Mudanças cirúrgicas, não reescrita.** Tocar só as seções relevantes à sessão atual. Não "melhorar" texto não relacionado, não reordenar seções sem motivo, não resumir/encurtar conteúdo operacional (comandos, exemplos, IDs) só para deixar o arquivo mais enxuto — esse conteúdo existe porque alguémvai precisar dele de novo.

3. **Não apagar conteúdo que ainda não foi verificado como obsoleto.** Se uma descoberta técnica ou decisão parece desatualizada mas não há confirmação de que mudou, marcar como "a confirmar" em vez de remover. Remover é uma escolha que exige certeza; manter com ressalva não custa nada.

4. **Lembrar o usuário do fluxo de git do projeto** antes de qualquer commit/push, se o próprio arquivo de estado documentar um (preservar arquivos não relacionados, não usar `git add .` sem revisar, não presumir autorização de push a partir de "terminei").

---

## Formato de referência para `ESTADO_DO_PROJETO.md`

Não é obrigatório que o arquivo do usuário siga esta estrutura exata — cada projeto adapta. Mas todo arquivo de estado eficaz tem estas propriedades:

- **Fica na raiz**, nome previsível — a IA acha sem perguntar.
- **Escrito para leitura fria** — quem lê não viu a conversa que gerou a decisão.
- **A seção mais importante é "onde paramos"** — se só houver tempo para atualizar uma seção, é essa.
- **Registra decisão E a razão** — sem a razão, a decisão é questionada de novo.
- **Curto** — índice de estado, não diário. Detalhe técnico profundo mora em outros documentos do projeto; aqui fica o que orienta a próxima sessão a não perder tempo.
- **Data de atualização visível** no topo.

Ver `references/template.md` para um esqueleto completo pronto para copiar.

---

## Princípios

- **Não presuma o que foi feito** — confira no `git log`/`git status` antes de confiar cegamente no arquivo de estado. Ele pode estar desatualizado; é sinal disso quando a data é antiga ou o git diverge.
- **Cada projeto é diferente** — não importe nomes de arquivo, decisões ou armadilhas de outro projeto. Esta skill lê o que o projeto atual tem.
- **O objetivo é permitir abrir uma conversa nova — em qualquer máquina, com qualquer IA — e continuar de onde parou**, sem o usuário precisar reexplicar nada nem a nova sessão redescobrir algo já corrigido.
