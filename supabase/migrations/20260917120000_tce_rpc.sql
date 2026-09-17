-- Funcoes RPC do sistema TCE, expostas a aplicacao.
--
-- As funcoes de plataforma.* nao sao chamaveis pela API REST (o schema nao e
-- exposto de proposito: e a camada de identidade compartilhada entre sistemas,
-- nao superficie publica). Estes wrappers no schema `tce` dao a aplicacao o
-- que ela precisa, ja fixando o sistema — a aplicacao nunca escolhe de qual
-- sistema quer o papel.
--
-- Mesmo padrao do PortalGov, que tem portalgov.meu_papel() e
-- portalgov.posso_ver_tela() por cima das funcoes de plataforma.

CREATE OR REPLACE FUNCTION tce.eh_papel_de_plataforma(p_sistema text DEFAULT 'tce')
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $fn$
    SELECT plataforma.eh_papel_de_plataforma('tce')
$fn$;

COMMENT ON FUNCTION tce.eh_papel_de_plataforma(text) IS
    'Superadmin do sistema TCE. O parametro existe so para compatibilidade de chamada; o sistema e sempre tce.';

CREATE OR REPLACE FUNCTION tce.meu_papel()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $fn$
    SELECT plataforma.papel_atual('tce')
$fn$;

CREATE OR REPLACE FUNCTION tce.tenho_acesso()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $fn$
    SELECT plataforma.tem_acesso('tce')
$fn$;

CREATE OR REPLACE FUNCTION tce.minha_organizacao()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $fn$
    SELECT plataforma.org_atual('tce')
$fn$;

CREATE OR REPLACE FUNCTION tce.posso_ver_tela(p_tela text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $fn$
    SELECT plataforma.pode_ver_tela('tce', p_tela)
$fn$;

-- Contexto completo do usuario logado numa chamada so: o layout precisa de
-- tudo isso junto, e cinco RPCs separadas seriam cinco round-trips.
CREATE OR REPLACE FUNCTION tce.meu_contexto()
RETURNS TABLE (
    usuario_sistema_id uuid,
    nome               text,
    papel              text,
    is_suporte         boolean,
    eh_plataforma      boolean,
    organizacao_id     uuid,
    organizacao_nome   text,
    organizacao_slug   text
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $fn$
    SELECT
        us.id,
        us.nome,
        plataforma.papel_atual('tce'),
        us.is_suporte,
        plataforma.eh_papel_de_plataforma('tce'),
        o.id,
        o.nome,
        o.slug
    FROM plataforma.usuarios_sistema us
    LEFT JOIN plataforma.organizacoes o ON o.id = us.organizacao_id
    WHERE us.auth_user_id = (SELECT auth.uid())
      AND us.sistema = 'tce'
      AND us.status = 'ativo'
    ORDER BY us.organizacao_id NULLS FIRST
    LIMIT 1
$fn$;

GRANT EXECUTE ON FUNCTION
    tce.eh_papel_de_plataforma(text),
    tce.meu_papel(),
    tce.tenho_acesso(),
    tce.minha_organizacao(),
    tce.posso_ver_tela(text),
    tce.meu_contexto()
TO authenticated;
