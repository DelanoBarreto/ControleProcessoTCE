-- Schema `plataforma`: camada compartilhada entre os sistemas hospedados neste
-- projeto (tce, e os que vierem). Replica o padrao ja em producao no PortalGov.
--
-- Cada projeto Supabase tem seu proprio auth.users, entao este `plataforma` e
-- independente do `plataforma` do PortalGov: mesmo desenho, dados separados.
--
-- Divergencia deliberada de docs/MODELAGEM_DADOS.md, que previa `escritorios` e
-- `usuarios` proprios do TCE. Aqui `organizacoes` faz o papel de escritorio e
-- `usuarios_sistema` o de usuario, para que clinicas/gerencial/tarefas usem a
-- mesma identidade. Ver ESTADO_DO_PROJETO.md.

CREATE SCHEMA IF NOT EXISTS plataforma;

CREATE TABLE plataforma.sistemas (
    chave      text PRIMARY KEY,
    nome       text NOT NULL,
    status     text NOT NULL DEFAULT 'ativo' CHECK (status IN ('ativo','inativo')),
    criado_em  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE plataforma.sistemas IS
    'Sistemas hospedados neste projeto. usuarios_sistema.sistema referencia esta chave.';

-- nivel_plataforma = papel que enxerga alem de uma organizacao (superadmin).
CREATE TABLE plataforma.papeis (
    sistema           text NOT NULL REFERENCES plataforma.sistemas(chave) ON DELETE CASCADE,
    papel             text NOT NULL,
    nome              text NOT NULL,
    nivel_plataforma  boolean NOT NULL DEFAULT false,
    ordem             integer NOT NULL DEFAULT 0,
    PRIMARY KEY (sistema, papel)
);

-- Tenant. No TCE isto e o escritorio de advocacia; em outro sistema pode ser
-- a clinica, a empresa etc. O que e especifico de cada sistema fica no schema
-- do sistema, nao aqui.
CREATE TABLE plataforma.organizacoes (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    slug        text UNIQUE NOT NULL,
    nome        text NOT NULL,
    codigo      text,
    cnpj        text,
    email       text,
    telefone    text,
    status      text NOT NULL DEFAULT 'ativo' CHECK (status IN ('ativo','suspenso','cancelado')),
    criado_em   timestamptz NOT NULL DEFAULT now(),
    atualizado_em timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE plataforma.assinaturas (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organizacao_id  uuid NOT NULL REFERENCES plataforma.organizacoes(id) ON DELETE CASCADE,
    sistema         text NOT NULL REFERENCES plataforma.sistemas(chave) ON DELETE CASCADE,
    plano_id        uuid,     -- FK adicionada em 20260916190200 (tce.planos)
    status          text NOT NULL DEFAULT 'trial'
                    CHECK (status IN ('trial','ativa','inadimplente','cancelada')),
    trial_expira_em timestamptz,
    iniciada_em     timestamptz NOT NULL DEFAULT now(),
    cancelada_em    timestamptz,
    observacao      text,
    criado_em       timestamptz NOT NULL DEFAULT now(),
    atualizado_em   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (organizacao_id, sistema)
);

-- Vinculo pessoa <-> sistema. A mesma conta auth pode ter papeis diferentes em
-- sistemas diferentes; cada linha e um desses vinculos.
--
-- organizacao_id nulo = papel de plataforma (superadmin), que nao pertence a
-- tenant nenhum.
--
-- is_suporte e extensao propria deste projeto (o PortalGov nao tem): marca quem
-- pode abrir sessao temporaria auditada sobre uma organizacao cliente. E flag
-- INDEPENDENTE do papel - suporte e superadmin tem acessos quase opostos, e
-- fundir os dois numa coluna so e origem classica de vazamento multi-tenant.
CREATE TABLE plataforma.usuarios_sistema (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    sistema         text NOT NULL REFERENCES plataforma.sistemas(chave) ON DELETE CASCADE,
    organizacao_id  uuid REFERENCES plataforma.organizacoes(id) ON DELETE CASCADE,
    papel           text NOT NULL,
    nome            text NOT NULL,
    cpf             text,
    telefone        text,
    is_suporte      boolean NOT NULL DEFAULT false,
    status          text NOT NULL DEFAULT 'convidado'
                    CHECK (status IN ('convidado','ativo','bloqueado','removido')),
    ultimo_acesso   timestamptz,
    criado_em       timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (sistema, papel) REFERENCES plataforma.papeis(sistema, papel),
    UNIQUE (auth_user_id, sistema, organizacao_id)
);

CREATE INDEX idx_usuarios_sistema_auth ON plataforma.usuarios_sistema (auth_user_id, sistema);
CREATE INDEX idx_usuarios_sistema_org ON plataforma.usuarios_sistema (organizacao_id, sistema);

-- Guarda o HASH do token, nunca o token cru.
CREATE TABLE plataforma.convites (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_sistema_id  uuid NOT NULL REFERENCES plataforma.usuarios_sistema(id) ON DELETE CASCADE,
    token_hash          text NOT NULL UNIQUE,
    expira_em           timestamptz NOT NULL,
    usado_em            timestamptz,
    criado_por          uuid REFERENCES auth.users(id),
    criado_em           timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_convites_pendentes ON plataforma.convites (usuario_sistema_id)
    WHERE usado_em IS NULL;

-- Telas que cada usuario pode ver. Ausencia = sem acesso. Sem FK de tela: o
-- menu vive no codigo, so a marcacao vive aqui.
CREATE TABLE plataforma.permissoes_usuario (
    usuario_sistema_id  uuid NOT NULL REFERENCES plataforma.usuarios_sistema(id) ON DELETE CASCADE,
    tela                text NOT NULL,
    criado_por          uuid REFERENCES auth.users(id),
    criado_em           timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (usuario_sistema_id, tela)
);

-- Sessao de suporte: acesso temporario, auditado e visivel ao cliente.
-- A expiracao e verificada NA POLICY do banco, nao na aplicacao: sessao vencida
-- para de funcionar mesmo que a UI falhe em bloquear.
CREATE TABLE plataforma.sessoes_suporte (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_sistema_id  uuid NOT NULL REFERENCES plataforma.usuarios_sistema(id),
    sistema             text NOT NULL REFERENCES plataforma.sistemas(chave) ON DELETE CASCADE,
    organizacao_id      uuid NOT NULL REFERENCES plataforma.organizacoes(id) ON DELETE CASCADE,
    motivo              text NOT NULL,
    iniciada_em         timestamptz NOT NULL DEFAULT now(),
    expira_em           timestamptz NOT NULL DEFAULT (now() + interval '60 minutes'),
    encerrada_em        timestamptz,
    ip                  inet,
    user_agent          text
);

CREATE INDEX idx_sessoes_suporte_ativa
    ON plataforma.sessoes_suporte (organizacao_id, sistema, expira_em)
    WHERE encerrada_em IS NULL;

CREATE TABLE plataforma.logs_auditoria (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_sistema_id uuid REFERENCES plataforma.usuarios_sistema(id),
    sistema         text REFERENCES plataforma.sistemas(chave),
    organizacao_id  uuid REFERENCES plataforma.organizacoes(id),
    papel           text NOT NULL CHECK (papel IN ('usuario','suporte','superadmin')),
    acao            text NOT NULL,
    entidade        text,
    entidade_id     uuid,
    dados           jsonb,
    ip              inet,
    criado_em       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_logs_auditoria_org ON plataforma.logs_auditoria (organizacao_id, criado_em DESC);

-- Lista de referencia dos municipios do Ceara. NAO sao clientes: clientes vivem
-- em organizacoes. Serve tanto ao TCE (localidade da API) quanto a outros
-- sistemas que precisem da lista.
CREATE TABLE plataforma.catalogo_municipios (
    codigo     text PRIMARY KEY,
    slug       text UNIQUE NOT NULL,
    nome       text NOT NULL,
    uf         char(2) NOT NULL DEFAULT 'CE'
);
