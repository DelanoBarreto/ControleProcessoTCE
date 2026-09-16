-- Schema `tce`: espelho da API do TCE-CE.
-- Dados publicos, coletados uma vez por municipio e compartilhados entre todos
-- os assinantes. SEM organizacao_id: o vinculo privado (quem acompanha o que)
-- mora em tce.processos_monitorados.
-- Ver docs/MODELAGEM_DADOS.md secao 2 e docs/API_TCE.md.

CREATE SCHEMA IF NOT EXISTS tce;

CREATE TABLE tce.municipios (
    id           integer PRIMARY KEY,   -- id da localidade no TCE
    descricao    text NOT NULL,
    codigo_ibge  text REFERENCES plataforma.catalogo_municipios(codigo),
    ativo        boolean NOT NULL DEFAULT false,
    ultimo_sync  timestamptz,
    criado_em    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON COLUMN tce.municipios.ativo IS
    'Entra no sync? So Horizonte (id=72) no piloto. Expandir e UPDATE pelo console.';

-- `sigiloso` NAO existe como coluna: processo sigiloso nunca e persistido.
-- O filtro age no TceClient, antes do banco.
CREATE TABLE tce.processos (
    id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nr_processo               text UNIQUE NOT NULL,
    nr_protocolo              text,
    exercicio                 integer,
    dt_autuacao               date,
    dt_ultimo_encaminhamento  date,
    assunto                   text,
    eletronico                boolean,
    mensagem_aviso            text,

    municipio_id              integer REFERENCES tce.municipios(id),
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

    raw                       jsonb,
    sincronizado_em           timestamptz NOT NULL DEFAULT now(),
    criado_em                 timestamptz NOT NULL DEFAULT now(),
    atualizado_em             timestamptz NOT NULL DEFAULT now()
);

COMMENT ON COLUMN tce.processos.raw IS
    'Resposta original SANITIZADA, nunca a crua. A API traz interessados[].nminteressado mesmo com preservado=true; gravar a resposta crua aqui reintroduziria por caminho lateral o nome que interessados.nome corretamente omite.';

CREATE INDEX idx_processos_municipio ON tce.processos (municipio_id);
CREATE INDEX idx_processos_ultimo_enc ON tce.processos (dt_ultimo_encaminhamento DESC);

-- tramite_id_tce UNIQUE e o mecanismo de deduplicacao: reexecutar o sync nao
-- duplica porque o insert conflita. Estabilidade confirmada na Fase 0
-- (10/10 recoletas com ids identicos).
CREATE TABLE tce.tramites (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    processo_id       uuid NOT NULL REFERENCES tce.processos(id) ON DELETE CASCADE,
    tramite_id_tce    bigint UNIQUE NOT NULL,
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
    criado_em         timestamptz NOT NULL DEFAULT now()
);

COMMENT ON COLUMN tce.tramites.acao_descricao IS
    'Agrupar por trim(upper(descricao)), nunca por acao_id: a Fase 0 achou a mesma acao com ids diferentes so por variacao de caixa. acao pode vir null.';

CREATE INDEX idx_tramites_processo ON tce.tramites (processo_id, data DESC);
CREATE INDEX idx_tramites_pendentes
    ON tce.tramites (classificacao, notificado_em)
    WHERE notificado_em IS NULL;

-- exibir_documento: allowlist estrita, default false.
-- A Fase 0 mediu 564 documentos e exibirDocumento nunca foi true (so null ou
-- false). O TceClient grava true apenas com === true; `!== false` deixaria
-- passar null, e `!exibirDocumento` bloquearia tudo.
CREATE TABLE tce.documentos_processo (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    processo_id        uuid NOT NULL REFERENCES tce.processos(id) ON DELETE CASCADE,
    documento_id_tce   bigint,
    numero             integer,
    ano                integer,
    data_finalizacao   date,
    tipo_descricao     text,
    setor_descricao    text,
    exibir_documento   boolean NOT NULL DEFAULT false,
    criado_em          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_documentos_processo ON tce.documentos_processo (processo_id);

CREATE TABLE tce.julgamentos (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    processo_id  uuid NOT NULL REFERENCES tce.processos(id) ON DELETE CASCADE,
    raw          jsonb,
    criado_em    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_julgamentos_processo ON tce.julgamentos (processo_id);

-- Interessado com preservado=true entra com nome NULL; o id fica so para
-- integridade referencial. O CHECK torna a regra uma garantia do banco, nao
-- uma convencao do codigo de ingestao.
CREATE TABLE tce.interessados (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    processo_id        uuid NOT NULL REFERENCES tce.processos(id) ON DELETE CASCADE,
    interessado_id_tce integer NOT NULL,
    nome               text,
    preservado         boolean NOT NULL DEFAULT false,
    criado_em          timestamptz NOT NULL DEFAULT now(),
    UNIQUE (processo_id, interessado_id_tce),
    CONSTRAINT interessado_preservado_sem_nome
        CHECK (NOT preservado OR nome IS NULL)
);
