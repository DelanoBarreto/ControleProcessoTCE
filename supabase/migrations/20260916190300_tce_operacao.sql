-- Operacao da plataforma TCE: sync, classificacao, fila de notificacao, planos.
-- Ver docs/MODELAGEM_DADOS.md secoes 3 e 4.

-- cursor_pagina guarda DE ONDE retomar; locked_until e a auto-continuacao
-- (ARQUITETURA.md s.4) resolvem O QUE dispara a proxima invocacao. Ter so o
-- cursor nao move o sync sozinho.
--
-- A Fase 0 mediu: `qtd` e ignorado pela API (sempre 10/pagina), entao Horizonte
-- sao 244 paginas fixas + 2.431 detalhes ~ 78 min a 1 req/s. Excede qualquer
-- timeout serverless.
CREATE TABLE tce.sync_runs (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    municipio_id         integer REFERENCES tce.municipios(id),
    status               text NOT NULL DEFAULT 'em_andamento'
                         CHECK (status IN ('em_andamento','concluido','falhou','cancelado')),
    origem               text NOT NULL DEFAULT 'cron' CHECK (origem IN ('cron','manual')),
    disparado_por        uuid REFERENCES plataforma.usuarios_sistema(id),

    carga_inicial        boolean NOT NULL DEFAULT false,
    locked_until         timestamptz,

    cursor_pagina        integer NOT NULL DEFAULT 1,
    total_paginas        integer,
    processos_lidos      integer NOT NULL DEFAULT 0,
    processos_novos      integer NOT NULL DEFAULT 0,
    tramites_novos       integer NOT NULL DEFAULT 0,
    processos_ignorados  integer NOT NULL DEFAULT 0,

    erro                 text,
    iniciado_em          timestamptz NOT NULL DEFAULT now(),
    finalizado_em        timestamptz
);

COMMENT ON COLUMN tce.sync_runs.carga_inicial IS
    'Primeira sync do municipio: milhares de tramites nunca vistos que nao sao movimentacao nova. Grava e classifica, mas nao enfileira notificacao.';

CREATE INDEX idx_sync_runs_retomaveis ON tce.sync_runs (status, locked_until)
    WHERE status = 'em_andamento';

CREATE TABLE tce.regras_classificacao (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nome             text NOT NULL,
    classificacao    text NOT NULL CHECK (classificacao IN ('critico','relevante','rotina')),
    prioridade       integer NOT NULL DEFAULT 100,   -- menor vence
    match_acao       text,                            -- regex sobre acao_descricao
    match_especie    integer,
    match_subespecie integer,
    gera_tarefa      boolean NOT NULL DEFAULT false,
    tipo_prazo_id    uuid,
    ativa            boolean NOT NULL DEFAULT true,
    criado_em        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE tce.planos (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nome          text NOT NULL,
    slug          text UNIQUE NOT NULL,
    preco_mensal  numeric(10,2) NOT NULL DEFAULT 0,
    preco_anual   numeric(10,2) NOT NULL DEFAULT 0,
    ativo         boolean NOT NULL DEFAULT true,
    ordem         integer NOT NULL DEFAULT 0,

    limite_processos_monitorados  integer NOT NULL,
    limite_usuarios               integer NOT NULL,
    limite_armazenamento_mb       integer NOT NULL,
    limite_notificacoes_wpp_mes   integer NOT NULL,
    limite_quadros                integer NOT NULL DEFAULT 1,
    limite_creditos_ia_mes        integer NOT NULL DEFAULT 0,

    recursos      jsonb NOT NULL DEFAULT '{}',
    criado_em     timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE tce.planos IS
    'Municipios monitorados sao ILIMITADOS em todos os planos: a coleta e por municipio, custo marginal por cliente ~ zero. Por isso nao ha coluna de limite.';

ALTER TABLE plataforma.assinaturas
    ADD CONSTRAINT assinaturas_plano_fk
    FOREIGN KEY (plano_id) REFERENCES tce.planos(id);

CREATE TABLE tce.uso_quotas (
    organizacao_id        uuid NOT NULL REFERENCES plataforma.organizacoes(id) ON DELETE CASCADE,
    competencia           char(7) NOT NULL,   -- 'AAAA-MM'
    processos_monitorados integer NOT NULL DEFAULT 0,
    usuarios              integer NOT NULL DEFAULT 0,
    armazenamento_mb      integer NOT NULL DEFAULT 0,
    notificacoes_wpp      integer NOT NULL DEFAULT 0,
    creditos_ia           integer NOT NULL DEFAULT 0,
    atualizado_em         timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (organizacao_id, competencia)
);

-- UNIQUE (tramite_id, destinatario_id, canal): idempotencia de entrega. O mesmo
-- evento nao gera duas notificacoes para o mesmo destinatario no mesmo canal,
-- mesmo se o worker rodar em duplicidade.
CREATE TABLE tce.notificacoes (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organizacao_id  uuid REFERENCES plataforma.organizacoes(id) ON DELETE CASCADE,
    destinatario_id uuid REFERENCES plataforma.usuarios_sistema(id),
    tramite_id      uuid REFERENCES tce.tramites(id) ON DELETE CASCADE,
    tarefa_id       uuid,
    peca_id         uuid,

    canal           text NOT NULL CHECK (canal IN ('email','whatsapp')),
    destino         text NOT NULL,
    assunto         text,
    corpo           text NOT NULL,

    status          text NOT NULL DEFAULT 'pendente'
                    CHECK (status IN ('pendente','processando','enviada','falhou','cancelada')),
    tentativas      integer NOT NULL DEFAULT 0,
    proxima_tentativa_em timestamptz NOT NULL DEFAULT now(),
    resultado_provedor   text,
    erro            text,
    enviado_em      timestamptz,
    criado_em       timestamptz NOT NULL DEFAULT now(),

    UNIQUE (tramite_id, destinatario_id, canal)
);

COMMENT ON COLUMN tce.notificacoes.resultado_provedor IS
    'Resposta bruta do Resend/WhatsApp. Timeout ou 5xx vai para falhou com backoff, nunca cancelada direto: cancelada e so opt-out ou maximo de tentativas.';

-- A fila e consumida com FOR UPDATE SKIP LOCKED (ver docs/MODELAGEM_DADOS.md
-- s.3): duas invocacoes concorrentes do cron nao competem pelo mesmo registro.
CREATE INDEX idx_notificacoes_fila
    ON tce.notificacoes (status, proxima_tentativa_em)
    WHERE status IN ('pendente', 'falhou');
