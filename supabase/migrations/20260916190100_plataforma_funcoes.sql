-- Funcoes de identidade do schema plataforma.
-- Replicam as do PortalGov, com a adicao das de suporte.
--
-- Todas SECURITY DEFINER com search_path vazio: search_path mutavel em funcao
-- SECURITY DEFINER e vetor de escalacao de privilegio.

-- Tenant pedido no header. O middleware do Next envia; a funcao valida o
-- formato antes de confiar.
CREATE OR REPLACE FUNCTION plataforma.org_pedida()
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO '' AS $$
DECLARE
    v_bruto text;
BEGIN
    v_bruto := lower(nullif(
        (nullif(current_setting('request.headers', true), '')::json ->> 'x-tenant-slug'),
        ''
    ));

    IF v_bruto IS NULL THEN
        RETURN NULL;
    END IF;

    IF v_bruto !~ '^[a-z0-9-]{1,64}$' THEN
        RETURN NULL;
    END IF;

    RETURN v_bruto;
EXCEPTION
    WHEN others THEN
        RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION plataforma.tem_acesso(p_sistema text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$
    SELECT EXISTS (
        SELECT 1 FROM plataforma.usuarios_sistema us
        WHERE us.auth_user_id = (SELECT auth.uid())
          AND us.sistema = p_sistema
          AND us.status = 'ativo'
    )
$$;

CREATE OR REPLACE FUNCTION plataforma.eh_papel_de_plataforma(p_sistema text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$
    SELECT EXISTS (
        SELECT 1
        FROM plataforma.usuarios_sistema us
        JOIN plataforma.papeis p ON p.sistema = us.sistema AND p.papel = us.papel
        WHERE us.auth_user_id = (SELECT auth.uid())
          AND us.sistema = p_sistema
          AND us.status = 'ativo'
          AND p.nivel_plataforma
    )
$$;

CREATE OR REPLACE FUNCTION plataforma.papel_atual(p_sistema text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$
    SELECT COALESCE(
        (
            SELECT us.papel
            FROM plataforma.usuarios_sistema us
            JOIN plataforma.papeis p ON p.sistema = us.sistema AND p.papel = us.papel
            WHERE us.auth_user_id = (SELECT auth.uid())
              AND us.sistema = p_sistema
              AND us.status = 'ativo'
              AND us.organizacao_id IS NULL
              AND p.nivel_plataforma
            LIMIT 1
        ),
        (
            SELECT us.papel
            FROM plataforma.usuarios_sistema us
            JOIN plataforma.organizacoes o ON o.id = us.organizacao_id
            WHERE us.auth_user_id = (SELECT auth.uid())
              AND us.sistema = p_sistema
              AND us.status = 'ativo'
              AND o.slug = plataforma.org_pedida()
            LIMIT 1
        )
    )
$$;

CREATE OR REPLACE FUNCTION plataforma.org_atual(p_sistema text)
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$
    SELECT COALESCE(
        (
            SELECT us.organizacao_id
            FROM plataforma.usuarios_sistema us
            JOIN plataforma.organizacoes o ON o.id = us.organizacao_id
            WHERE us.auth_user_id = (SELECT auth.uid())
              AND us.sistema = p_sistema
              AND us.status = 'ativo'
              AND o.slug = plataforma.org_pedida()
            LIMIT 1
        ),
        (
            SELECT o.id
            FROM plataforma.organizacoes o
            WHERE o.slug = plataforma.org_pedida()
              AND plataforma.eh_papel_de_plataforma(p_sistema)
            LIMIT 1
        )
    )
$$;

-- Sessao de suporte ATIVA e NAO EXPIRADA sobre a organizacao informada.
-- A expiracao e verificada aqui, na policy do banco: sessao vencida para de
-- funcionar mesmo que a UI falhe em bloquear, e e isso que torna a auditoria
-- confiavel.
CREATE OR REPLACE FUNCTION plataforma.tem_suporte_ativo(p_sistema text, p_organizacao_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$
    SELECT EXISTS (
        SELECT 1
        FROM plataforma.sessoes_suporte s
        JOIN plataforma.usuarios_sistema us ON us.id = s.usuario_sistema_id
        WHERE us.auth_user_id = (SELECT auth.uid())
          AND us.is_suporte
          AND us.status = 'ativo'
          AND s.sistema = p_sistema
          AND s.organizacao_id = p_organizacao_id
          AND s.encerrada_em IS NULL
          AND s.expira_em > now()
    )
$$;

CREATE OR REPLACE FUNCTION plataforma.pode_ver_tela(p_sistema text, p_tela text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$
    SELECT
        plataforma.tem_acesso(p_sistema)
        AND (
            plataforma.eh_papel_de_plataforma(p_sistema)
            OR EXISTS (
                SELECT 1
                FROM plataforma.permissoes_usuario pu
                JOIN plataforma.usuarios_sistema us ON us.id = pu.usuario_sistema_id
                WHERE us.auth_user_id = (SELECT auth.uid())
                  AND us.sistema = p_sistema
                  AND us.status = 'ativo'
                  AND pu.tela = p_tela
            )
        )
$$;
