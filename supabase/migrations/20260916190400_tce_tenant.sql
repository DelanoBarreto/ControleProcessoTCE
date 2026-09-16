-- Dados do tenant no sistema TCE. Toda tabela leva organizacao_id e RLS.
-- O schema inteiro entra agora, inclusive o que so e usado nas fases 5-7:
-- tabela criada cedo custa quase nada; adicionar organizacao_id e quota depois,
-- com o codigo escrito, obriga a mexer em dezenas de lugares.
-- Ver docs/MODELAGEM_DADOS.md secao 5.

CREATE TABLE tce.clientes (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organizacao_id     uuid NOT NULL REFERENCES plataforma.organizacoes(id) ON DELETE CASCADE,
    usuario_sistema_id uuid REFERENCES plataforma.usuarios_sistema(id),
    nome               text NOT NULL,
    cpf_cnpj           text,
    email              text,
    telefone           text,
    cargo              text,
    municipio_id       integer REFERENCES tce.municipios(id),
    ativo              boolean NOT NULL DEFAULT true,
    criado_em          timestamptz NOT NULL DEFAULT now(),
    atualizado_em      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_clientes_org ON tce.clientes (organizacao_id);

-- Tabela-chave do modelo: liga o espelho publico ao tenant privado, e e onde a
-- quota limite_processos_monitorados e contada.
CREATE TABLE tce.processos_monitorados (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organizacao_id     uuid NOT NULL REFERENCES plataforma.organizacoes(id) ON DELETE CASCADE,
    processo_id        uuid NOT NULL REFERENCES tce.processos(id) ON DELETE CASCADE,
    cliente_id         uuid REFERENCES tce.clientes(id) ON DELETE SET NULL,
    responsavel_id     uuid REFERENCES plataforma.usuarios_sistema(id),
    notificar_email    boolean NOT NULL DEFAULT true,
    notificar_whatsapp boolean NOT NULL DEFAULT true,
    ativo              boolean NOT NULL DEFAULT true,
    criado_em          timestamptz NOT NULL DEFAULT now(),
    UNIQUE (organizacao_id, processo_id)
);

CREATE INDEX idx_proc_monitorados_org ON tce.processos_monitorados (organizacao_id);
CREATE INDEX idx_proc_monitorados_cliente ON tce.processos_monitorados (cliente_id);

CREATE TABLE tce.feriados (
    data       date PRIMARY KEY,
    descricao  text NOT NULL,
    ambito     text NOT NULL CHECK (ambito IN ('nacional','estadual','tce'))
);

CREATE TABLE tce.tipos_prazo (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nome           text NOT NULL,
    dias           integer NOT NULL,
    contagem       text NOT NULL DEFAULT 'uteis' CHECK (contagem IN ('uteis','corridos')),
    marco_inicial  text NOT NULL DEFAULT 'intimacao',
    base_legal     text,
    ativo          boolean NOT NULL DEFAULT true
);

ALTER TABLE tce.regras_classificacao
    ADD CONSTRAINT regras_tipo_prazo_fk
    FOREIGN KEY (tipo_prazo_id) REFERENCES tce.tipos_prazo(id);

-- memoria_calculo guarda COMO o prazo foi calculado: advogado nao confia em
-- prazo que nao pode conferir. Alimenta o indicador de cumpridos vs. perdidos.
CREATE TABLE tce.prazos (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organizacao_id  uuid NOT NULL REFERENCES plataforma.organizacoes(id) ON DELETE CASCADE,
    processo_id     uuid REFERENCES tce.processos(id),
    tramite_id      uuid REFERENCES tce.tramites(id),
    tipo_prazo_id   uuid REFERENCES tce.tipos_prazo(id),
    responsavel_id  uuid REFERENCES plataforma.usuarios_sistema(id),

    descricao       text NOT NULL,
    data_inicial    date NOT NULL,
    data_limite     date NOT NULL,
    memoria_calculo jsonb,
    origem          text NOT NULL DEFAULT 'manual' CHECK (origem IN ('manual','automatico')),

    status          text NOT NULL DEFAULT 'aberto'
                    CHECK (status IN ('aberto','cumprido','perdido','cancelado')),
    cumprido_em     timestamptz,
    criado_em       timestamptz NOT NULL DEFAULT now(),
    atualizado_em   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_prazos_org ON tce.prazos (organizacao_id, data_limite);

CREATE TABLE tce.pecas (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organizacao_id  uuid NOT NULL REFERENCES plataforma.organizacoes(id) ON DELETE CASCADE,
    processo_id     uuid REFERENCES tce.processos(id),
    cliente_id      uuid REFERENCES tce.clientes(id),
    prazo_id        uuid REFERENCES tce.prazos(id),
    titulo          text NOT NULL,
    status          text NOT NULL DEFAULT 'rascunho'
                    CHECK (status IN ('rascunho','aguardando_aprovacao','ajustes_solicitados','aprovada','protocolada')),
    versao_atual    integer NOT NULL DEFAULT 1,
    criado_em       timestamptz NOT NULL DEFAULT now(),
    atualizado_em   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_pecas_org ON tce.pecas (organizacao_id);

CREATE TABLE tce.pecas_versoes (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    peca_id     uuid NOT NULL REFERENCES tce.pecas(id) ON DELETE CASCADE,
    versao      integer NOT NULL,
    arquivo_url text,
    conteudo    text,
    criada_por  uuid REFERENCES plataforma.usuarios_sistema(id),
    criado_em   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (peca_id, versao)
);

-- Sem ON DELETE CASCADE de pecas, e com FK COMPOSTA contra pecas_versoes:
--   1. A FK composta impede gravar comentario/aprovacao para versao que nao
--      existe (antes, `versao` era inteiro solto e a "prova" podia apontar
--      para o nada).
--   2. Sem cascade, apagar uma peca com aprovacoes falha por violacao de FK,
--      obrigando a decisao explicita (arquivar, nunca apagar) em vez de perder
--      a prova imutavel junto com a peca.
CREATE TABLE tce.pecas_comentarios (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    peca_id     uuid NOT NULL REFERENCES tce.pecas(id),
    versao      integer NOT NULL,
    autor_id    uuid NOT NULL REFERENCES plataforma.usuarios_sistema(id),
    texto       text NOT NULL,
    criado_em   timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (peca_id, versao) REFERENCES tce.pecas_versoes(peca_id, versao)
);

CREATE TABLE tce.pecas_aprovacoes (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    peca_id       uuid NOT NULL REFERENCES tce.pecas(id),
    versao        integer NOT NULL,
    aprovador_id  uuid NOT NULL REFERENCES plataforma.usuarios_sistema(id),
    decisao       text NOT NULL CHECK (decisao IN ('aprovada','ajustes')),
    justificativa text,
    ip            inet,
    criado_em     timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (peca_id, versao) REFERENCES tce.pecas_versoes(peca_id, versao)
);

COMMENT ON TABLE tce.pecas_aprovacoes IS
    'Imutavel: a RLS concede apenas SELECT e INSERT. Sem policy de UPDATE/DELETE o RLS nega por padrao, e e isso que torna a imutabilidade garantia do banco, nao convencao do codigo.';

CREATE TABLE tce.quadros (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organizacao_id  uuid NOT NULL REFERENCES plataforma.organizacoes(id) ON DELETE CASCADE,
    nome            text NOT NULL,
    ordem           integer NOT NULL DEFAULT 0,
    arquivado       boolean NOT NULL DEFAULT false,
    criado_em       timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE tce.colunas (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    quadro_id  uuid NOT NULL REFERENCES tce.quadros(id) ON DELETE CASCADE,
    nome       text NOT NULL,
    ordem      integer NOT NULL DEFAULT 0,
    tipo       text NOT NULL DEFAULT 'aberta'
               CHECK (tipo IN ('aberta','em_andamento','concluida'))
);

CREATE TABLE tce.tarefas (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organizacao_id  uuid NOT NULL REFERENCES plataforma.organizacoes(id) ON DELETE CASCADE,
    coluna_id       uuid NOT NULL REFERENCES tce.colunas(id) ON DELETE CASCADE,
    processo_id     uuid REFERENCES tce.processos(id),
    tramite_id      uuid REFERENCES tce.tramites(id),
    prazo_id        uuid REFERENCES tce.prazos(id),

    titulo          text NOT NULL,
    descricao       text,
    responsavel_id  uuid REFERENCES plataforma.usuarios_sistema(id),
    prioridade      text NOT NULL DEFAULT 'media'
                    CHECK (prioridade IN ('baixa','media','alta','urgente')),
    origem          text NOT NULL DEFAULT 'manual'
                    CHECK (origem IN ('manual','tramite_automatico')),
    ordem           integer NOT NULL DEFAULT 0,
    concluida_em    timestamptz,
    criado_em       timestamptz NOT NULL DEFAULT now(),
    atualizado_em   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_tarefas_org ON tce.tarefas (organizacao_id);

CREATE TABLE tce.etiquetas (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organizacao_id  uuid NOT NULL REFERENCES plataforma.organizacoes(id) ON DELETE CASCADE,
    nome            text NOT NULL,
    cor             text NOT NULL DEFAULT '#64748b'
);

CREATE TABLE tce.tarefa_etiquetas (
    tarefa_id    uuid REFERENCES tce.tarefas(id) ON DELETE CASCADE,
    etiqueta_id  uuid REFERENCES tce.etiquetas(id) ON DELETE CASCADE,
    PRIMARY KEY (tarefa_id, etiqueta_id)
);

ALTER TABLE tce.notificacoes
    ADD CONSTRAINT notificacoes_tarefa_fk FOREIGN KEY (tarefa_id) REFERENCES tce.tarefas(id) ON DELETE CASCADE,
    ADD CONSTRAINT notificacoes_peca_fk   FOREIGN KEY (peca_id)   REFERENCES tce.pecas(id)   ON DELETE CASCADE;

ALTER TABLE tce.tramites
    ADD CONSTRAINT tramites_regra_fk FOREIGN KEY (regra_id) REFERENCES tce.regras_classificacao(id);

CREATE TABLE tce.modelos_documento (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organizacao_id  uuid NOT NULL REFERENCES plataforma.organizacoes(id) ON DELETE CASCADE,
    nome            text NOT NULL,
    conteudo        text NOT NULL,     -- com {{variaveis}}
    variaveis       jsonb NOT NULL DEFAULT '[]',
    criado_em       timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE tce.artigos_ajuda (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    slug       text UNIQUE NOT NULL,
    titulo     text NOT NULL,
    conteudo   text NOT NULL,
    categoria  text,
    ordem      integer NOT NULL DEFAULT 0,
    publicado  boolean NOT NULL DEFAULT false,
    criado_em  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE tce.sugestoes (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organizacao_id  uuid REFERENCES plataforma.organizacoes(id) ON DELETE SET NULL,
    autor_id        uuid REFERENCES plataforma.usuarios_sistema(id),
    titulo          text NOT NULL,
    descricao       text NOT NULL,
    status          text NOT NULL DEFAULT 'recebida'
                    CHECK (status IN ('recebida','em_analise','planejada','entregue','recusada')),
    resposta        text,
    votos           integer NOT NULL DEFAULT 0,
    criado_em       timestamptz NOT NULL DEFAULT now()
);
