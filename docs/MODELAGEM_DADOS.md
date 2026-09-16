# Modelagem de Dados — Plataforma TCE

PostgreSQL via Supabase. Toda tabela de negócio tem Row Level Security ativa.

---

## Decisão central: o que é compartilhado e o que é privado

As tabelas dividem-se em três grupos, e confundi-los é a origem de vazamento entre tenants:

| Grupo | Tabelas | `escritorio_id`? | RLS |
| :--- | :--- | :--- | :--- |
| **Espelho do TCE** | `processos`, `tramites`, `documentos_processo`, `julgamentos`, `interessados`, `municipios` | ❌ não | Leitura para autenticado; escrita só service role |
| **Operação da plataforma** | `sync_runs`, `notificacoes`, `regras_classificacao`, `planos`, `logs_auditoria` | ❌ não | Só `is_superadmin` |
| **Dados do tenant** | todas as demais | ✅ **sim** | Isolamento por `escritorio_id` |

**Por que o espelho do TCE não leva `escritorio_id`:** são dados públicos, coletados uma vez por município e compartilhados entre todos os assinantes. Duplicá-los por escritório multiplicaria armazenamento e custo de coleta sem ganho algum.

O vínculo privado — *quem acompanha o quê* — fica em `processos_monitorados`, essa sim com `escritorio_id` e RLS.

---

## Convenções

```sql
id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
created_at  timestamptz NOT NULL DEFAULT now(),
updated_at  timestamptz NOT NULL DEFAULT now(),
created_by  uuid        REFERENCES auth.users(id)
```

- Nomes de tabela no plural, snake_case
- Datas da API do TCE chegam como `DD/MM/AAAA` (string) → converter para `date` na ingestão
- Valores monetários em `numeric(14,2)`, nunca `float`

---

## 1. Identidade e tenant

```sql
CREATE TABLE escritorios (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nome        text NOT NULL,
    cnpj        text UNIQUE,
    email       text NOT NULL,
    telefone    text,
    ativo       boolean NOT NULL DEFAULT true,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE usuarios (
    id             uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    escritorio_id  uuid REFERENCES escritorios(id) ON DELETE CASCADE,
    nome           text NOT NULL,
    email          text NOT NULL,
    telefone       text,

    -- papel DENTRO do tenant
    perfil         text NOT NULL DEFAULT 'advogado'
                   CHECK (perfil IN ('admin_escritorio','advogado','gestor_publico')),

    -- poderes DE PLATAFORMA (independentes do perfil e entre si)
    is_superadmin  boolean NOT NULL DEFAULT false,
    is_suporte     boolean NOT NULL DEFAULT false,

    ativo          boolean NOT NULL DEFAULT true,
    ultimo_acesso  timestamptz,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);
```

> `escritorio_id` é nullable porque superadmin de plataforma não pertence a escritório nenhum.

### Permissões granulares

```sql
CREATE TABLE permissoes (
    id         text PRIMARY KEY,          -- 'processos.editar', 'pecas.aprovar'
    descricao  text NOT NULL,
    categoria  text NOT NULL
);

CREATE TABLE usuario_permissoes (
    usuario_id    uuid REFERENCES usuarios(id) ON DELETE CASCADE,
    permissao_id  text REFERENCES permissoes(id) ON DELETE CASCADE,
    concedida     boolean NOT NULL DEFAULT true,
    PRIMARY KEY (usuario_id, permissao_id)
);
```

`perfil` funciona como **preset** que concede um conjunto; `usuario_permissoes` ajusta individualmente. Permissão é sempre **dentro do tenant** — não interage com `is_superadmin`/`is_suporte`.

### Sessões de suporte

```sql
CREATE TABLE sessoes_suporte (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_suporte_id  uuid NOT NULL REFERENCES usuarios(id),
    escritorio_id       uuid NOT NULL REFERENCES escritorios(id) ON DELETE CASCADE,
    motivo              text NOT NULL,
    iniciada_em         timestamptz NOT NULL DEFAULT now(),
    expira_em           timestamptz NOT NULL DEFAULT (now() + interval '60 minutes'),
    encerrada_em        timestamptz,
    ip                  inet,
    user_agent          text
);

CREATE INDEX idx_sessoes_suporte_ativa
    ON sessoes_suporte (escritorio_id, expira_em)
    WHERE encerrada_em IS NULL;
```

```sql
CREATE TABLE logs_auditoria (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id     uuid REFERENCES usuarios(id),
    escritorio_id  uuid REFERENCES escritorios(id),
    papel          text NOT NULL,   -- 'usuario' | 'suporte' | 'superadmin'
    acao           text NOT NULL,
    entidade       text,
    entidade_id    uuid,
    dados          jsonb,
    ip             inet,
    created_at     timestamptz NOT NULL DEFAULT now()
);
```

---

## 2. Espelho do TCE

Sem `escritorio_id` — dados públicos compartilhados.

```sql
CREATE TABLE municipios (
    id           integer PRIMARY KEY,      -- id da localidade no TCE
    descricao    text NOT NULL,
    ativo        boolean NOT NULL DEFAULT false,   -- entra no sync?
    ultimo_sync  timestamptz,
    created_at   timestamptz NOT NULL DEFAULT now()
);
```

> Só Horizonte (`id = 72`) fica `ativo = true` no piloto. Expandir é `UPDATE`, feito pelo console interno.

```sql
CREATE TABLE processos (
    id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nr_processo               text UNIQUE NOT NULL,
    nr_protocolo              text,
    exercicio                 integer,
    dt_autuacao               date,
    dt_ultimo_encaminhamento  date,
    assunto                   text,
    eletronico                boolean,
    mensagem_aviso            text,

    municipio_id              integer REFERENCES municipios(id),
    entidade_id               integer,
    entidade_descricao        text,
    entidade_sigla            text,
    especie_id                integer,
    especie_descricao         text,
    subespecie_id             integer,
    subespecie_descricao      text,
    setor_id                  integer,
    setor_descricao           text,
    relator_nome              text,

    raw                       jsonb,        -- resposta original SANITIZADA — nunca a resposta crua da API
    sincronizado_em           timestamptz NOT NULL DEFAULT now(),
    created_at                timestamptz NOT NULL DEFAULT now(),
    updated_at                timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_processos_municipio ON processos (municipio_id);
CREATE INDEX idx_processos_ultimo_enc ON processos (dt_ultimo_encaminhamento DESC);
```

> ⚠️ **`raw` também passa pelo filtro de privacidade — erro real da primeira versão desta modelagem.** A resposta da API traz `interessados[].nminteressado` mesmo quando `preservado: true`; gravar essa resposta crua em `raw` reintroduz, por um caminho lateral, exatamente o nome que a coluna `interessados.nome` corretamente omite. `TceClient` deve remover recursivamente qualquer campo coberto pelo filtro de privacidade (nome de interessado preservado, corpo de documento sob `bloqueioVisualizacao`) **antes** de persistir em `raw` — não só antes de popular as colunas estruturadas. Vale também para qualquer payload salvo em log ou fila de diagnóstico. Ver [CONFORMIDADE.md § Filtro de privacidade](CONFORMIDADE.md).

### Reconciliação: processo que se torna sigiloso depois de coletado

O filtro de privacidade, como descrito até aqui, cobre a **entrada** — decide o que gravar na primeira vez que um processo é visto. Falta cobrir o que acontece quando o TCE muda a classificação de um processo **já persistido**: um processo público pode ser marcado sigiloso depois (decisão de sigilo, medida protetiva, etc.), e a cópia antiga na plataforma não desaparece sozinha.

Regra: toda sincronização, ao reler um processo já existente, verifica se `sigiloso` mudou de `false` para `true`. Se mudou:

- O processo é **removido** de `processos` (ou movido a uma tabela de auditoria de exclusões, se retenção for exigida por outra norma) — não basta marcar uma flag e continuar servindo os dados antigos
- `tramites`, `documentos_processo`, `julgamentos` e `interessados` vinculados são removidos em cascata
- `processos_monitorados` que apontava para ele é removido — o escritório para de vê-lo, sem notificação adicional que revele a mudança de sigilo a quem não deveria mais ter acesso
- A reconciliação **não** é reprocessamento oportunista — roda como parte de toda sincronização normal do município, comparando o `sigiloso` novo com o valor anterior antes de decidir gravar ou descartar

O mesmo vale para `exibirDocumento` e `bloqueioVisualizacao`: se um documento antes disponível passa a bloqueado, o registro correspondente deixa de ser servido a partir da próxima sincronização.

> **`sigiloso` não existe como coluna** — processo sigiloso nunca é persistido. O filtro age no `TceClient`, antes do banco.

```sql
CREATE TABLE tramites (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    processo_id       uuid NOT NULL REFERENCES processos(id) ON DELETE CASCADE,
    tramite_id_tce    bigint UNIQUE NOT NULL,     -- dedup: chave natural do TCE
    data              date NOT NULL,
    acao_id           integer,
    acao_descricao    text,
    setor_origem      text,
    setor_destino     text,
    ultimo_tramite    boolean NOT NULL DEFAULT false,

    classificacao     text CHECK (classificacao IN ('critico','relevante','rotina')),
    classificado_por  text CHECK (classificado_por IN ('regra','ia','manual')),
    regra_id          uuid,

    notificado_em     timestamptz,
    created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_tramites_processo ON tramites (processo_id, data DESC);
CREATE INDEX idx_tramites_pendentes
    ON tramites (classificacao, notificado_em)
    WHERE notificado_em IS NULL;
```

**`tramite_id_tce UNIQUE` é o mecanismo de deduplicação.** Reexecutar o sync não duplica: o insert conflita e é ignorado. Trâmite que entrou é trâmite novo → dispara detecção.

```sql
CREATE TABLE documentos_processo (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    processo_id        uuid NOT NULL REFERENCES processos(id) ON DELETE CASCADE,
    documento_id_tce   bigint,
    numero             integer,
    ano                integer,
    data_finalizacao   date,
    tipo_descricao     text,
    setor_descricao    text,
    exibir_documento   boolean NOT NULL DEFAULT false,
    created_at         timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE julgamentos (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    processo_id  uuid NOT NULL REFERENCES processos(id) ON DELETE CASCADE,
    raw          jsonb,
    created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE interessados (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    processo_id       uuid NOT NULL REFERENCES processos(id) ON DELETE CASCADE,
    interessado_id_tce integer NOT NULL,
    nome              text,          -- NULL quando preservado = true
    preservado        boolean NOT NULL DEFAULT false,
    created_at        timestamptz NOT NULL DEFAULT now(),
    UNIQUE (processo_id, interessado_id_tce)
);
```

> Interessado com `preservado: true` entra com `nome = NULL`. O id é mantido só para integridade referencial.

---

## 3. Operação

```sql
CREATE TABLE sync_runs (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    municipio_id         integer REFERENCES municipios(id),
    status               text NOT NULL DEFAULT 'em_andamento'
                         CHECK (status IN ('em_andamento','concluido','falhou','cancelado')),
    origem               text NOT NULL DEFAULT 'cron' CHECK (origem IN ('cron','manual')),
    disparado_por        uuid REFERENCES usuarios(id),

    carga_inicial        boolean NOT NULL DEFAULT false,   -- true: primeiro sync do município, sem notificar
    locked_until         timestamptz,                       -- lock otimista contra invocação concorrente

    cursor_pagina        integer NOT NULL DEFAULT 1,
    total_paginas        integer,
    processos_lidos      integer NOT NULL DEFAULT 0,
    processos_novos      integer NOT NULL DEFAULT 0,
    tramites_novos       integer NOT NULL DEFAULT 0,
    processos_ignorados  integer NOT NULL DEFAULT 0,   -- sigilosos descartados

    erro                 text,
    iniciado_em          timestamptz NOT NULL DEFAULT now(),
    finalizado_em        timestamptz
);
```

`cursor_pagina` guarda **de onde** retomar; `locked_until` e a auto-continuação descrita em [ARQUITETURA.md § Chunking com auto-continuação](ARQUITETURA.md#4-chunking-com-auto-continuação--não-apenas-cursor) resolvem **o que dispara** a próxima invocação — ter só o cursor não move o sync sozinho. `carga_inicial` impede que a primeira sincronização de um município (milhares de trâmites nunca vistos) seja lida como movimentação nova.

```sql
CREATE TABLE regras_classificacao (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nome            text NOT NULL,
    classificacao   text NOT NULL CHECK (classificacao IN ('critico','relevante','rotina')),
    prioridade      integer NOT NULL DEFAULT 100,   -- menor vence
    match_acao      text,          -- regex sobre acao_descricao
    match_especie   integer,
    match_subespecie integer,
    gera_tarefa     boolean NOT NULL DEFAULT false,
    tipo_prazo_id   uuid,
    ativa           boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE notificacoes (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    escritorio_id   uuid REFERENCES escritorios(id) ON DELETE CASCADE,
    destinatario_id uuid REFERENCES usuarios(id),
    tramite_id      uuid REFERENCES tramites(id) ON DELETE CASCADE,
    tarefa_id       uuid,
    peca_id         uuid,

    canal           text NOT NULL CHECK (canal IN ('email','whatsapp')),
    destino         text NOT NULL,      -- e-mail ou telefone
    assunto         text,
    corpo           text NOT NULL,

    status          text NOT NULL DEFAULT 'pendente'
                    CHECK (status IN ('pendente','processando','enviada','falhou','cancelada')),
    tentativas      integer NOT NULL DEFAULT 0,
    proxima_tentativa_em timestamptz NOT NULL DEFAULT now(),   -- backoff entre retries
    resultado_provedor   text,          -- id/status devolvido pelo Resend/WhatsApp; confirma entrega incerta
    erro            text,
    enviado_em      timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now(),

    -- idempotência de entrega: o mesmo evento não gera duas notificações
    -- para o mesmo destinatário no mesmo canal, mesmo se o worker rodar em duplicidade
    UNIQUE (tramite_id, destinatario_id, canal)
);

CREATE INDEX idx_notificacoes_fila
    ON notificacoes (status, proxima_tentativa_em)
    WHERE status IN ('pendente', 'falhou');
```

**Aquisição exclusiva do trabalho** (evita dois workers enviando a mesma notificação em paralelo):

```sql
-- Cada execução do consumidor da fila reivindica um lote assim, atomicamente:
UPDATE notificacoes
SET status = 'processando'
WHERE id IN (
    SELECT id FROM notificacoes
    WHERE status IN ('pendente', 'falhou')
      AND proxima_tentativa_em <= now()
    ORDER BY created_at
    LIMIT 50
    FOR UPDATE SKIP LOCKED   -- pula linhas já travadas por outra invocação concorrente
)
RETURNING *;
```

`FOR UPDATE SKIP LOCKED` é o mecanismo que falta para transformar a fila em algo seguro sob concorrência: duas invocações do cron de notificação disparadas ao mesmo tempo (retry da Vercel, sobreposição de horário) não competem pelo mesmo registro.

**Resultado incerto do provedor:** nem todo erro de envio é definitivo. Se o provedor retorna timeout ou 5xx, `resultado_provedor` registra a resposta bruta e o status vai para `falhou` com `proxima_tentativa_em` no futuro (backoff exponencial) — nunca `cancelada` direto, que só ocorre por opt-out ou por exceder o número máximo de tentativas.

---

## 4. Planos e quotas

```sql
CREATE TABLE planos (
    id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nome    text NOT NULL,
    slug    text UNIQUE NOT NULL,
    preco_mensal  numeric(10,2) NOT NULL DEFAULT 0,
    preco_anual   numeric(10,2) NOT NULL DEFAULT 0,
    ativo   boolean NOT NULL DEFAULT true,
    ordem   integer NOT NULL DEFAULT 0,

    limite_processos_monitorados  integer NOT NULL,
    limite_usuarios               integer NOT NULL,
    limite_armazenamento_mb       integer NOT NULL,
    limite_notificacoes_wpp_mes   integer NOT NULL,
    limite_quadros                integer NOT NULL DEFAULT 1,
    limite_creditos_ia_mes        integer NOT NULL DEFAULT 0,

    recursos  jsonb NOT NULL DEFAULT '{}',   -- feature flags por tier
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE assinaturas (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    escritorio_id  uuid UNIQUE NOT NULL REFERENCES escritorios(id) ON DELETE CASCADE,
    plano_id       uuid NOT NULL REFERENCES planos(id),
    status         text NOT NULL DEFAULT 'trial'
                   CHECK (status IN ('trial','ativa','inadimplente','cancelada')),
    trial_expira_em timestamptz,
    iniciada_em    timestamptz NOT NULL DEFAULT now(),
    cancelada_em   timestamptz,
    observacao     text,        -- exceção concedida pelo suporte
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE uso_quotas (
    escritorio_id         uuid NOT NULL REFERENCES escritorios(id) ON DELETE CASCADE,
    competencia           char(7) NOT NULL,        -- 'AAAA-MM'
    processos_monitorados integer NOT NULL DEFAULT 0,
    usuarios              integer NOT NULL DEFAULT 0,
    armazenamento_mb      integer NOT NULL DEFAULT 0,
    notificacoes_wpp      integer NOT NULL DEFAULT 0,
    creditos_ia           integer NOT NULL DEFAULT 0,
    updated_at            timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (escritorio_id, competencia)
);
```

**Municípios monitorados são ilimitados em todos os planos** — não há coluna de limite, por decisão de produto (a coleta é por município, custo marginal zero por cliente).

### Seed inicial

| Plano | Processos | Usuários | Storage | WhatsApp/mês | Quadros | IA |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: |
| Gratuito | 5 | 1 | 100 MB | 0 | 1 | 0 |
| Gestor | 25 | 2 | 1 GB | 100 | 2 | 5 |
| Escritório | 300 | 5 | 10 GB | 1.000 | 4 | 20 |
| Escritório Plus | 1.000 | 15 | 30 GB | 5.000 | 10 | 50 |

Valores a validar comercialmente — são configuração, não código.

---

## 5. Dados do tenant

```sql
CREATE TABLE clientes (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    escritorio_id  uuid NOT NULL REFERENCES escritorios(id) ON DELETE CASCADE,
    usuario_id     uuid REFERENCES usuarios(id),   -- se tem acesso ao painel
    nome           text NOT NULL,
    cpf_cnpj       text,
    email          text,
    telefone       text,
    cargo          text,          -- prefeito, secretário, ordenador
    municipio_id   integer REFERENCES municipios(id),
    ativo          boolean NOT NULL DEFAULT true,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE processos_monitorados (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    escritorio_id  uuid NOT NULL REFERENCES escritorios(id) ON DELETE CASCADE,
    processo_id    uuid NOT NULL REFERENCES processos(id) ON DELETE CASCADE,
    cliente_id     uuid REFERENCES clientes(id) ON DELETE SET NULL,
    responsavel_id uuid REFERENCES usuarios(id),
    notificar_email    boolean NOT NULL DEFAULT true,
    notificar_whatsapp boolean NOT NULL DEFAULT true,
    ativo          boolean NOT NULL DEFAULT true,
    created_at     timestamptz NOT NULL DEFAULT now(),
    UNIQUE (escritorio_id, processo_id)
);
```

> **Tabela-chave do modelo.** Liga o espelho público ao tenant privado e é onde a quota `limite_processos_monitorados` é contada.

### Prazos

```sql
CREATE TABLE feriados (
    data       date PRIMARY KEY,
    descricao  text NOT NULL,
    ambito     text NOT NULL CHECK (ambito IN ('nacional','estadual','tce'))
);

CREATE TABLE tipos_prazo (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nome           text NOT NULL,
    dias           integer NOT NULL,
    contagem       text NOT NULL DEFAULT 'uteis' CHECK (contagem IN ('uteis','corridos')),
    marco_inicial  text NOT NULL DEFAULT 'intimacao',
    base_legal     text,
    ativo          boolean NOT NULL DEFAULT true
);

CREATE TABLE prazos (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    escritorio_id  uuid NOT NULL REFERENCES escritorios(id) ON DELETE CASCADE,
    processo_id    uuid REFERENCES processos(id),
    tramite_id     uuid REFERENCES tramites(id),
    tipo_prazo_id  uuid REFERENCES tipos_prazo(id),
    responsavel_id uuid REFERENCES usuarios(id),

    descricao      text NOT NULL,
    data_inicial   date NOT NULL,
    data_limite    date NOT NULL,
    memoria_calculo jsonb,      -- marco, dias, feriados descontados
    origem         text NOT NULL DEFAULT 'manual' CHECK (origem IN ('manual','automatico')),

    status         text NOT NULL DEFAULT 'aberto'
                   CHECK (status IN ('aberto','cumprido','perdido','cancelado')),
    cumprido_em    timestamptz,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);
```

`memoria_calculo` guarda como o prazo foi calculado — advogado não confia em prazo que não pode conferir. Alimenta o indicador estratégico (cumpridos vs. perdidos).

### Peças e aprovação

```sql
CREATE TABLE pecas (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    escritorio_id  uuid NOT NULL REFERENCES escritorios(id) ON DELETE CASCADE,
    processo_id    uuid REFERENCES processos(id),
    cliente_id     uuid REFERENCES clientes(id),
    prazo_id       uuid REFERENCES prazos(id),
    titulo         text NOT NULL,
    status         text NOT NULL DEFAULT 'rascunho'
                   CHECK (status IN ('rascunho','aguardando_aprovacao','ajustes_solicitados','aprovada','protocolada')),
    versao_atual   integer NOT NULL DEFAULT 1,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE pecas_versoes (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    peca_id     uuid NOT NULL REFERENCES pecas(id) ON DELETE CASCADE,
    versao      integer NOT NULL,
    arquivo_url text,
    conteudo    text,
    criada_por  uuid REFERENCES usuarios(id),
    created_at  timestamptz NOT NULL DEFAULT now(),
    UNIQUE (peca_id, versao)
);

CREATE TABLE pecas_comentarios (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    peca_id     uuid NOT NULL REFERENCES pecas(id),
    versao      integer NOT NULL,
    autor_id    uuid NOT NULL REFERENCES usuarios(id),
    texto       text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),

    -- comentário referencia uma versão que REALMENTE existe, não um inteiro solto
    FOREIGN KEY (peca_id, versao) REFERENCES pecas_versoes(peca_id, versao)
);

CREATE TABLE pecas_aprovacoes (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    peca_id       uuid NOT NULL REFERENCES pecas(id),
    versao        integer NOT NULL,
    aprovador_id  uuid NOT NULL REFERENCES usuarios(id),
    decisao       text NOT NULL CHECK (decisao IN ('aprovada','ajustes')),
    justificativa text,
    ip            inet,
    created_at    timestamptz NOT NULL DEFAULT now(),

    -- mesma correção: aprovação só existe para versão que existe
    FOREIGN KEY (peca_id, versao) REFERENCES pecas_versoes(peca_id, versao)
);
```

**Duas correções em relação à primeira versão desta modelagem:**

1. **`versao` deixa de ser um inteiro solto e vira parte de uma foreign key composta** contra `pecas_versoes(peca_id, versao)`. Antes, nada impedia gravar uma aprovação para a versão 7 de uma peça que só tinha 3 versões — a "prova de aprovação" podia apontar para uma versão inexistente.

2. **`pecas_aprovacoes` e `pecas_comentarios` perdem `ON DELETE CASCADE` de `pecas`.** Com cascade, apagar a peça apagava também o registro que o próprio modelo descreve como prova imutável de aprovação — contradição direta com a garantia que a tabela existe para dar. Sem cascade, tentar deletar uma peça com aprovações registradas falha por violação de FK, obrigando a uma decisão explícita (arquivar a peça, nunca apagá-la) em vez de perder o histórico silenciosamente.

**Imutabilidade de `pecas_aprovacoes`:** RLS nesta tabela concede apenas `SELECT` e `INSERT` para os perfis de negócio — **nenhuma policy de `UPDATE` ou `DELETE`** é criada para `advogado`, `admin_escritorio` ou `gestor_publico`. Sem policy permissiva para essas operações, o RLS nega por padrão. Isso é o que torna "imutável" uma garantia do banco, não uma convenção do código.

### Atividades (Kanban)

```sql
CREATE TABLE quadros (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    escritorio_id  uuid NOT NULL REFERENCES escritorios(id) ON DELETE CASCADE,
    nome           text NOT NULL,
    ordem          integer NOT NULL DEFAULT 0,
    arquivado      boolean NOT NULL DEFAULT false,
    created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE colunas (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    quadro_id  uuid NOT NULL REFERENCES quadros(id) ON DELETE CASCADE,
    nome       text NOT NULL,
    ordem      integer NOT NULL DEFAULT 0,
    tipo       text NOT NULL DEFAULT 'aberta'
               CHECK (tipo IN ('aberta','em_andamento','concluida'))
);

CREATE TABLE tarefas (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    escritorio_id  uuid NOT NULL REFERENCES escritorios(id) ON DELETE CASCADE,
    coluna_id      uuid NOT NULL REFERENCES colunas(id) ON DELETE CASCADE,
    processo_id    uuid REFERENCES processos(id),
    tramite_id     uuid REFERENCES tramites(id),
    prazo_id       uuid REFERENCES prazos(id),

    titulo         text NOT NULL,
    descricao      text,
    responsavel_id uuid REFERENCES usuarios(id),
    prioridade     text NOT NULL DEFAULT 'media'
                   CHECK (prioridade IN ('baixa','media','alta','urgente')),
    origem         text NOT NULL DEFAULT 'manual'
                   CHECK (origem IN ('manual','tramite_automatico')),
    ordem          integer NOT NULL DEFAULT 0,
    concluida_em   timestamptz,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE etiquetas (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    escritorio_id  uuid NOT NULL REFERENCES escritorios(id) ON DELETE CASCADE,
    nome           text NOT NULL,
    cor            text NOT NULL DEFAULT '#64748b'
);

CREATE TABLE tarefa_etiquetas (
    tarefa_id    uuid REFERENCES tarefas(id) ON DELETE CASCADE,
    etiqueta_id  uuid REFERENCES etiquetas(id) ON DELETE CASCADE,
    PRIMARY KEY (tarefa_id, etiqueta_id)
);
```

### Modelos, ajuda e sugestões

```sql
CREATE TABLE modelos_documento (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    escritorio_id  uuid NOT NULL REFERENCES escritorios(id) ON DELETE CASCADE,
    nome           text NOT NULL,
    conteudo       text NOT NULL,     -- com {{variaveis}}
    variaveis      jsonb NOT NULL DEFAULT '[]',
    created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE artigos_ajuda (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    slug       text UNIQUE NOT NULL,
    titulo     text NOT NULL,
    conteudo   text NOT NULL,
    categoria  text,
    ordem      integer NOT NULL DEFAULT 0,
    publicado  boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE sugestoes (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    escritorio_id  uuid REFERENCES escritorios(id) ON DELETE SET NULL,
    autor_id       uuid REFERENCES usuarios(id),
    titulo         text NOT NULL,
    descricao      text NOT NULL,
    status         text NOT NULL DEFAULT 'recebida'
                   CHECK (status IN ('recebida','em_analise','planejada','entregue','recusada')),
    resposta       text,
    votos          integer NOT NULL DEFAULT 0,
    created_at     timestamptz NOT NULL DEFAULT now()
);
```

---

## 5.1 Integridade entre tenants — o que a FK simples não garante

**Problema real da primeira versão desta modelagem:** colunas como `prazos.responsavel_id`, `pecas.cliente_id`, `tarefas.responsavel_id` e `processos_monitorados.responsavel_id` são `REFERENCES usuarios(id)` / `REFERENCES clientes(id)` — a foreign key garante que o registro **existe**, mas não que ele **pertence ao mesmo `escritorio_id`** da linha que o referencia.

Sem essa garantia, nada impede (por bug de aplicação, não por RLS) que um prazo do escritório A seja atribuído a um responsável do escritório B, ou que uma peça do escritório A cite um cliente do escritório B. RLS bloqueia o *acesso* de fora, mas não impede que o *dado dentro do escritório A* aponte para fora dele.

**Correção: trigger `BEFORE INSERT OR UPDATE` genérico, reaplicado em cada tabela que cruza `escritorio_id` com uma referência a outra tabela de tenant.**

```sql
CREATE OR REPLACE FUNCTION valida_mesmo_escritorio()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    escritorio_referenciado uuid;
BEGIN
    IF NEW.responsavel_id IS NOT NULL THEN
        SELECT escritorio_id INTO escritorio_referenciado
        FROM usuarios WHERE id = NEW.responsavel_id;

        IF escritorio_referenciado IS DISTINCT FROM NEW.escritorio_id THEN
            RAISE EXCEPTION 'responsavel_id pertence a outro escritório';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_prazos_mesmo_escritorio
    BEFORE INSERT OR UPDATE ON prazos
    FOR EACH ROW EXECUTE FUNCTION valida_mesmo_escritorio();
```

Repetir o padrão (adaptando a coluna e a tabela referenciada) para: `pecas.cliente_id` → `clientes.escritorio_id`, `tarefas.responsavel_id` → `usuarios.escritorio_id`, `processos_monitorados.responsavel_id` → `usuarios.escritorio_id`, `processos_monitorados.cliente_id` → `clientes.escritorio_id`.

Isso é **defesa em profundidade**, não substituto de RLS: RLS impede o acesso indevido pela sessão do usuário; o trigger impede a inconsistência de dado mesmo quando a escrita vem de um caminho privilegiado (migration, seed, `service_role` mal usado).

---

## 6. Row Level Security

### Funções auxiliares

```sql
-- escritorio do usuário logado
CREATE OR REPLACE FUNCTION auth_escritorio_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER AS $$
    SELECT escritorio_id FROM usuarios WHERE id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION auth_is_superadmin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS $$
    SELECT COALESCE((SELECT is_superadmin FROM usuarios WHERE id = auth.uid()), false)
$$;

-- perfil do usuário DENTRO do tenant (admin_escritorio | advogado | gestor_publico)
CREATE OR REPLACE FUNCTION auth_perfil()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER AS $$
    SELECT perfil FROM usuarios WHERE id = auth.uid()
$$;

-- sessão de suporte ATIVA e NÃO EXPIRADA para o escritório informado
CREATE OR REPLACE FUNCTION auth_tem_suporte_ativo(alvo uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS $$
    SELECT EXISTS (
        SELECT 1 FROM sessoes_suporte s
        WHERE s.usuario_suporte_id = auth.uid()
          AND s.escritorio_id = alvo
          AND s.encerrada_em IS NULL
          AND s.expira_em > now()
    )
$$;
```

> A verificação de expiração fica **na policy do banco**, não no código da aplicação. Sessão vencida para de funcionar mesmo que a UI falhe em bloquear — e é isso que torna a auditoria confiável.

### Padrão para tabela de tenant

**Uma `FOR ALL` só não basta.** O suporte precisa de leitura e escrita, mas não de exclusão — isso exige uma policy **por operação**, não uma condição só. Aplicar a toda tabela com `escritorio_id`:

```sql
ALTER TABLE clientes ENABLE ROW LEVEL SECURITY;

-- Leitura: dono do tenant OU sessão de suporte ativa
CREATE POLICY clientes_select ON clientes
    FOR SELECT
    USING (
        escritorio_id = auth_escritorio_id()
        OR auth_tem_suporte_ativo(escritorio_id)
    );

-- Criar/editar: mesma regra da leitura
CREATE POLICY clientes_insert ON clientes
    FOR INSERT
    WITH CHECK (
        escritorio_id = auth_escritorio_id()
        OR auth_tem_suporte_ativo(escritorio_id)
    );

CREATE POLICY clientes_update ON clientes
    FOR UPDATE
    USING (
        escritorio_id = auth_escritorio_id()
        OR auth_tem_suporte_ativo(escritorio_id)
    )
    WITH CHECK (
        escritorio_id = auth_escritorio_id()
        OR auth_tem_suporte_ativo(escritorio_id)
    );

-- Deletar: SOMENTE o dono do tenant. Suporte nunca aparece aqui.
CREATE POLICY clientes_delete ON clientes
    FOR DELETE
    USING (escritorio_id = auth_escritorio_id());
```

Este é o padrão para toda tabela de tenant **onde suporte pode ler/escrever mas não apagar** (a maioria). Repetir as quatro policies por tabela — não reduzir a uma `FOR ALL`, mesmo que pareça repetitivo: é exatamente essa repetição que impede o suporte de deletar por engano ou por design incorreto de uma tabela nova.

**Onde o suporte não deve nem escrever** (ex.: `usuario_permissoes`, dados financeiros da assinatura): omitir `auth_tem_suporte_ativo()` das policies de `INSERT`/`UPDATE`/`DELETE`, mantendo-a só em `SELECT` se a leitura for necessária para diagnóstico.

### Espelho do TCE

```sql
ALTER TABLE processos ENABLE ROW LEVEL SECURITY;

CREATE POLICY leitura_autenticada ON processos
    FOR SELECT TO authenticated USING (true);

-- escrita apenas via service role (ingestão), nunca pelo cliente
```

### Operação

```sql
ALTER TABLE sync_runs ENABLE ROW LEVEL SECURITY;

CREATE POLICY so_superadmin ON sync_runs
    FOR ALL USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());
```

Mesmo padrão para `notificacoes`, `municipios`, `regras_classificacao`, `planos`, `logs_auditoria`.

### Gestor público — por que uma policy a mais não isola nada

**Erro a evitar:** aplicar o padrão de tenant em `processos_monitorados` (`escritorio_id = auth_escritorio_id()`) e depois adicionar uma policy `gestor_ve_seus_processos` só para `cliente_id`, esperando que ela restrinja o acesso do gestor.

**Isso não funciona.** No Postgres, múltiplas policies permissivas na mesma operação se combinam por `OR`. Um usuário com `perfil = 'gestor_publico'` e `escritorio_id` preenchido passa pela primeira condição — `escritorio_id = auth_escritorio_id()` é verdadeira para ele também — e **enxerga todos os clientes do escritório**, exatamente o vazamento que a policy extra pretendia impedir.

**Correção: a condição de perfil entra dentro da mesma policy de `SELECT`, não em uma policy separada.**

```sql
ALTER TABLE processos_monitorados ENABLE ROW LEVEL SECURITY;

CREATE POLICY processos_monitorados_select ON processos_monitorados
    FOR SELECT
    USING (
        auth_tem_suporte_ativo(escritorio_id)
        OR (
            -- dono do tenant, mas gestor só vê o que é seu
            escritorio_id = auth_escritorio_id()
            AND (
                auth_perfil() <> 'gestor_publico'
                OR cliente_id IN (SELECT id FROM clientes WHERE usuario_id = auth.uid())
            )
        )
    );

CREATE POLICY processos_monitorados_insert ON processos_monitorados
    FOR INSERT
    WITH CHECK (
        escritorio_id = auth_escritorio_id()
        AND auth_perfil() <> 'gestor_publico'
    );

CREATE POLICY processos_monitorados_update ON processos_monitorados
    FOR UPDATE
    USING (escritorio_id = auth_escritorio_id() AND auth_perfil() <> 'gestor_publico')
    WITH CHECK (escritorio_id = auth_escritorio_id() AND auth_perfil() <> 'gestor_publico');

CREATE POLICY processos_monitorados_delete ON processos_monitorados
    FOR DELETE
    USING (escritorio_id = auth_escritorio_id() AND auth_perfil() <> 'gestor_publico');
```

Usa `auth_perfil()`, definida junto das demais funções auxiliares no início desta seção.

**A regra geral:** sempre que um perfil precisa de uma visão *mais restrita* que a do tenant, a restrição entra como cláusula `AND` dentro da mesma policy — nunca como uma policy adicional torcendo para o `OR` não se aplicar. Uma policy adicional só é segura para **ampliar** acesso (como o suporte), nunca para reduzi-lo.

Esse mesmo cuidado se aplica a qualquer tabela que `advogado`/`gestor_publico` acessem de formas diferentes dentro do mesmo escritório — revisar `clientes`, `prazos`, `pecas` e `tarefas` quando o CRUD do gestor for implementado (Fase 5).

---

## 7. Checklist de verificação

- [ ] Todo `CREATE TABLE` de tenant seguido de `ENABLE ROW LEVEL SECURITY`
- [ ] Nenhuma policy aceita `escritorio_id` vindo do request — sempre de `auth_escritorio_id()`
- [ ] Teste com dois tenants: consultar dado do outro retorna vazio
- [ ] Teste de sessão de suporte expirada: acesso negado **pela policy**, com a UI fora do caminho
- [ ] `tramite_id_tce` é UNIQUE — sync reexecutado não duplica
- [ ] Nenhum processo com `sigiloso: true` no banco
- [ ] Nenhum `interessados.nome` preenchido onde `preservado = true`

---

## Referências

- [API_TCE.md](API_TCE.md) — origem e formato dos dados
- [ARQUITETURA.md](ARQUITETURA.md) — fluxo e camadas
- [CONFORMIDADE.md](CONFORMIDADE.md) — base legal do tratamento
