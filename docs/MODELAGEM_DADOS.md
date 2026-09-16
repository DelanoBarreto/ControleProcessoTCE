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

    raw                       jsonb,        -- resposta original, para diagnóstico
    sincronizado_em           timestamptz NOT NULL DEFAULT now(),
    created_at                timestamptz NOT NULL DEFAULT now(),
    updated_at                timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_processos_municipio ON processos (municipio_id);
CREATE INDEX idx_processos_ultimo_enc ON processos (dt_ultimo_encaminhamento DESC);
```

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

`cursor_pagina` permite retomar de onde parou — é o que viabiliza chunking dentro do limite de execução da Vercel.

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
                    CHECK (status IN ('pendente','enviada','falhou','cancelada')),
    tentativas      integer NOT NULL DEFAULT 0,
    erro            text,
    enviado_em      timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_notificacoes_fila
    ON notificacoes (status, created_at)
    WHERE status = 'pendente';
```

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
    peca_id     uuid NOT NULL REFERENCES pecas(id) ON DELETE CASCADE,
    versao      integer NOT NULL,
    autor_id    uuid NOT NULL REFERENCES usuarios(id),
    texto       text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE pecas_aprovacoes (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    peca_id       uuid NOT NULL REFERENCES pecas(id) ON DELETE CASCADE,
    versao        integer NOT NULL,
    aprovador_id  uuid NOT NULL REFERENCES usuarios(id),
    decisao       text NOT NULL CHECK (decisao IN ('aprovada','ajustes')),
    justificativa text,
    ip            inet,
    created_at    timestamptz NOT NULL DEFAULT now()
);
```

> `pecas_aprovacoes` é **registro imutável** — nunca sofre UPDATE nem DELETE. É a prova de que o gestor aprovou aquela versão, e o que protege o advogado.

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

Aplicar a toda tabela com `escritorio_id`:

```sql
ALTER TABLE clientes ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON clientes
    FOR ALL
    USING (
        escritorio_id = auth_escritorio_id()
        OR auth_tem_suporte_ativo(escritorio_id)
    )
    WITH CHECK (
        escritorio_id = auth_escritorio_id()
        OR auth_tem_suporte_ativo(escritorio_id)
    );
```

O suporte **não pode deletar** — restringir por `GRANT`/policy separada por comando onde a operação for destrutiva.

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

### Gestor público

O gestor vê apenas os processos vinculados ao seu cadastro de cliente:

```sql
CREATE POLICY gestor_ve_seus_processos ON processos_monitorados
    FOR SELECT USING (
        cliente_id IN (SELECT id FROM clientes WHERE usuario_id = auth.uid())
    );
```

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
