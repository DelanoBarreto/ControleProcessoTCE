-- RLS, integridade entre tenants e role dedicada de ingestao.
-- Ver docs/MODELAGEM_DADOS.md secoes 5.1 e 6.

-- ---------------------------------------------------------------------------
-- Integridade entre tenants: o que a FK simples nao garante
-- ---------------------------------------------------------------------------
-- responsavel_id REFERENCES usuarios_sistema(id) garante que o usuario EXISTE,
-- nao que ele PERTENCE a mesma organizacao da linha que o referencia. Sem isso,
-- nada impede (por bug de aplicacao) um prazo da org A ser atribuido a alguem
-- da org B. RLS bloqueia o acesso de fora; nao impede o dado DENTRO de A
-- apontar para fora.
--
-- Defesa em profundidade: o trigger pega tambem a escrita por caminho
-- privilegiado (migration, seed, service_role mal usada), que a RLS nao ve.

CREATE OR REPLACE FUNCTION tce.valida_usuario_mesma_org()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE
    v_org uuid;
BEGIN
    IF NEW.responsavel_id IS NOT NULL THEN
        SELECT organizacao_id INTO v_org
        FROM plataforma.usuarios_sistema WHERE id = NEW.responsavel_id;

        IF v_org IS DISTINCT FROM NEW.organizacao_id THEN
            RAISE EXCEPTION 'responsavel_id pertence a outra organizacao'
                USING ERRCODE = '23514';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION tce.valida_cliente_mesma_org()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE
    v_org uuid;
BEGIN
    IF NEW.cliente_id IS NOT NULL THEN
        SELECT organizacao_id INTO v_org
        FROM tce.clientes WHERE id = NEW.cliente_id;

        IF v_org IS DISTINCT FROM NEW.organizacao_id THEN
            RAISE EXCEPTION 'cliente_id pertence a outra organizacao'
                USING ERRCODE = '23514';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_prazos_responsavel_org
    BEFORE INSERT OR UPDATE ON tce.prazos
    FOR EACH ROW EXECUTE FUNCTION tce.valida_usuario_mesma_org();

CREATE TRIGGER trg_tarefas_responsavel_org
    BEFORE INSERT OR UPDATE ON tce.tarefas
    FOR EACH ROW EXECUTE FUNCTION tce.valida_usuario_mesma_org();

CREATE TRIGGER trg_monitorados_responsavel_org
    BEFORE INSERT OR UPDATE ON tce.processos_monitorados
    FOR EACH ROW EXECUTE FUNCTION tce.valida_usuario_mesma_org();

CREATE TRIGGER trg_monitorados_cliente_org
    BEFORE INSERT OR UPDATE ON tce.processos_monitorados
    FOR EACH ROW EXECUTE FUNCTION tce.valida_cliente_mesma_org();

CREATE TRIGGER trg_pecas_cliente_org
    BEFORE INSERT OR UPDATE ON tce.pecas
    FOR EACH ROW EXECUTE FUNCTION tce.valida_cliente_mesma_org();

-- ---------------------------------------------------------------------------
-- Espelho do TCE: dados publicos. Leitura para autenticado com acesso ao
-- sistema; escrita so pela role de ingestao (ver final do arquivo).
-- ---------------------------------------------------------------------------

ALTER TABLE tce.municipios          ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.processos           ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.tramites            ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.documentos_processo ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.julgamentos         ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.interessados        ENABLE ROW LEVEL SECURITY;

CREATE POLICY municipios_select ON tce.municipios
    FOR SELECT TO authenticated USING (plataforma.tem_acesso('tce'));
CREATE POLICY processos_select ON tce.processos
    FOR SELECT TO authenticated USING (plataforma.tem_acesso('tce'));
CREATE POLICY tramites_select ON tce.tramites
    FOR SELECT TO authenticated USING (plataforma.tem_acesso('tce'));
CREATE POLICY julgamentos_select ON tce.julgamentos
    FOR SELECT TO authenticated USING (plataforma.tem_acesso('tce'));
CREATE POLICY interessados_select ON tce.interessados
    FOR SELECT TO authenticated USING (plataforma.tem_acesso('tce'));

-- Documento so aparece com exibir_documento = true. A Fase 0 nunca viu true em
-- 564 documentos; a policy e allowlist estrita para que null jamais libere.
CREATE POLICY documentos_select ON tce.documentos_processo
    FOR SELECT TO authenticated
    USING (plataforma.tem_acesso('tce') AND exibir_documento);

-- ---------------------------------------------------------------------------
-- Operacao: so papel de plataforma (superadmin).
-- ---------------------------------------------------------------------------

ALTER TABLE tce.sync_runs            ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.regras_classificacao ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.notificacoes         ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.planos               ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.uso_quotas           ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.feriados             ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.tipos_prazo          ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.artigos_ajuda        ENABLE ROW LEVEL SECURITY;

CREATE POLICY sync_runs_all ON tce.sync_runs
    FOR ALL USING (plataforma.eh_papel_de_plataforma('tce'))
    WITH CHECK (plataforma.eh_papel_de_plataforma('tce'));

CREATE POLICY regras_all ON tce.regras_classificacao
    FOR ALL USING (plataforma.eh_papel_de_plataforma('tce'))
    WITH CHECK (plataforma.eh_papel_de_plataforma('tce'));

-- Notificacao: superadmin ve tudo; a organizacao ve so as proprias, e nao as
-- altera (fila e da maquina, nao do cliente).
CREATE POLICY notificacoes_select ON tce.notificacoes
    FOR SELECT USING (
        plataforma.eh_papel_de_plataforma('tce')
        OR organizacao_id = plataforma.org_atual('tce')
    );
CREATE POLICY notificacoes_admin ON tce.notificacoes
    FOR ALL USING (plataforma.eh_papel_de_plataforma('tce'))
    WITH CHECK (plataforma.eh_papel_de_plataforma('tce'));

-- Catalogos legiveis por qualquer usuario do sistema; so superadmin escreve.
CREATE POLICY planos_select ON tce.planos
    FOR SELECT TO authenticated USING (plataforma.tem_acesso('tce'));
CREATE POLICY planos_admin ON tce.planos
    FOR ALL USING (plataforma.eh_papel_de_plataforma('tce'))
    WITH CHECK (plataforma.eh_papel_de_plataforma('tce'));

CREATE POLICY feriados_select ON tce.feriados
    FOR SELECT TO authenticated USING (plataforma.tem_acesso('tce'));
CREATE POLICY feriados_admin ON tce.feriados
    FOR ALL USING (plataforma.eh_papel_de_plataforma('tce'))
    WITH CHECK (plataforma.eh_papel_de_plataforma('tce'));

CREATE POLICY tipos_prazo_select ON tce.tipos_prazo
    FOR SELECT TO authenticated USING (plataforma.tem_acesso('tce'));
CREATE POLICY tipos_prazo_admin ON tce.tipos_prazo
    FOR ALL USING (plataforma.eh_papel_de_plataforma('tce'))
    WITH CHECK (plataforma.eh_papel_de_plataforma('tce'));

CREATE POLICY artigos_select ON tce.artigos_ajuda
    FOR SELECT TO authenticated USING (plataforma.tem_acesso('tce') AND publicado);
CREATE POLICY artigos_admin ON tce.artigos_ajuda
    FOR ALL USING (plataforma.eh_papel_de_plataforma('tce'))
    WITH CHECK (plataforma.eh_papel_de_plataforma('tce'));

CREATE POLICY uso_quotas_select ON tce.uso_quotas
    FOR SELECT USING (
        plataforma.eh_papel_de_plataforma('tce')
        OR organizacao_id = plataforma.org_atual('tce')
    );
CREATE POLICY uso_quotas_admin ON tce.uso_quotas
    FOR ALL USING (plataforma.eh_papel_de_plataforma('tce'))
    WITH CHECK (plataforma.eh_papel_de_plataforma('tce'));

-- ---------------------------------------------------------------------------
-- Tenant: quatro policies POR OPERACAO, nunca uma FOR ALL.
--
-- O suporte precisa ler e escrever, mas NAO deletar. Uma condicao unica nao
-- expressa isso: por isso a repeticao e deliberada. E ela que impede o suporte
-- de apagar por engano ou por desenho incorreto de uma tabela nova.
-- ---------------------------------------------------------------------------

ALTER TABLE tce.clientes           ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.prazos             ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.pecas              ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.quadros            ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.tarefas            ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.etiquetas          ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.modelos_documento  ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.sugestoes          ENABLE ROW LEVEL SECURITY;

-- clientes
CREATE POLICY clientes_select ON tce.clientes FOR SELECT
    USING (organizacao_id = plataforma.org_atual('tce')
           OR plataforma.tem_suporte_ativo('tce', organizacao_id));
CREATE POLICY clientes_insert ON tce.clientes FOR INSERT
    WITH CHECK (organizacao_id = plataforma.org_atual('tce')
                OR plataforma.tem_suporte_ativo('tce', organizacao_id));
CREATE POLICY clientes_update ON tce.clientes FOR UPDATE
    USING (organizacao_id = plataforma.org_atual('tce')
           OR plataforma.tem_suporte_ativo('tce', organizacao_id))
    WITH CHECK (organizacao_id = plataforma.org_atual('tce')
                OR plataforma.tem_suporte_ativo('tce', organizacao_id));
CREATE POLICY clientes_delete ON tce.clientes FOR DELETE
    USING (organizacao_id = plataforma.org_atual('tce'));

-- prazos
CREATE POLICY prazos_select ON tce.prazos FOR SELECT
    USING (organizacao_id = plataforma.org_atual('tce')
           OR plataforma.tem_suporte_ativo('tce', organizacao_id));
CREATE POLICY prazos_insert ON tce.prazos FOR INSERT
    WITH CHECK (organizacao_id = plataforma.org_atual('tce')
                OR plataforma.tem_suporte_ativo('tce', organizacao_id));
CREATE POLICY prazos_update ON tce.prazos FOR UPDATE
    USING (organizacao_id = plataforma.org_atual('tce')
           OR plataforma.tem_suporte_ativo('tce', organizacao_id))
    WITH CHECK (organizacao_id = plataforma.org_atual('tce')
                OR plataforma.tem_suporte_ativo('tce', organizacao_id));
CREATE POLICY prazos_delete ON tce.prazos FOR DELETE
    USING (organizacao_id = plataforma.org_atual('tce'));

-- pecas
CREATE POLICY pecas_select ON tce.pecas FOR SELECT
    USING (organizacao_id = plataforma.org_atual('tce')
           OR plataforma.tem_suporte_ativo('tce', organizacao_id));
CREATE POLICY pecas_insert ON tce.pecas FOR INSERT
    WITH CHECK (organizacao_id = plataforma.org_atual('tce')
                OR plataforma.tem_suporte_ativo('tce', organizacao_id));
CREATE POLICY pecas_update ON tce.pecas FOR UPDATE
    USING (organizacao_id = plataforma.org_atual('tce')
           OR plataforma.tem_suporte_ativo('tce', organizacao_id))
    WITH CHECK (organizacao_id = plataforma.org_atual('tce')
                OR plataforma.tem_suporte_ativo('tce', organizacao_id));
CREATE POLICY pecas_delete ON tce.pecas FOR DELETE
    USING (organizacao_id = plataforma.org_atual('tce'));

-- quadros
CREATE POLICY quadros_select ON tce.quadros FOR SELECT
    USING (organizacao_id = plataforma.org_atual('tce')
           OR plataforma.tem_suporte_ativo('tce', organizacao_id));
CREATE POLICY quadros_insert ON tce.quadros FOR INSERT
    WITH CHECK (organizacao_id = plataforma.org_atual('tce')
                OR plataforma.tem_suporte_ativo('tce', organizacao_id));
CREATE POLICY quadros_update ON tce.quadros FOR UPDATE
    USING (organizacao_id = plataforma.org_atual('tce')
           OR plataforma.tem_suporte_ativo('tce', organizacao_id))
    WITH CHECK (organizacao_id = plataforma.org_atual('tce')
                OR plataforma.tem_suporte_ativo('tce', organizacao_id));
CREATE POLICY quadros_delete ON tce.quadros FOR DELETE
    USING (organizacao_id = plataforma.org_atual('tce'));

-- tarefas
CREATE POLICY tarefas_select ON tce.tarefas FOR SELECT
    USING (organizacao_id = plataforma.org_atual('tce')
           OR plataforma.tem_suporte_ativo('tce', organizacao_id));
CREATE POLICY tarefas_insert ON tce.tarefas FOR INSERT
    WITH CHECK (organizacao_id = plataforma.org_atual('tce')
                OR plataforma.tem_suporte_ativo('tce', organizacao_id));
CREATE POLICY tarefas_update ON tce.tarefas FOR UPDATE
    USING (organizacao_id = plataforma.org_atual('tce')
           OR plataforma.tem_suporte_ativo('tce', organizacao_id))
    WITH CHECK (organizacao_id = plataforma.org_atual('tce')
                OR plataforma.tem_suporte_ativo('tce', organizacao_id));
CREATE POLICY tarefas_delete ON tce.tarefas FOR DELETE
    USING (organizacao_id = plataforma.org_atual('tce'));

-- etiquetas
CREATE POLICY etiquetas_select ON tce.etiquetas FOR SELECT
    USING (organizacao_id = plataforma.org_atual('tce')
           OR plataforma.tem_suporte_ativo('tce', organizacao_id));
CREATE POLICY etiquetas_insert ON tce.etiquetas FOR INSERT
    WITH CHECK (organizacao_id = plataforma.org_atual('tce')
                OR plataforma.tem_suporte_ativo('tce', organizacao_id));
CREATE POLICY etiquetas_update ON tce.etiquetas FOR UPDATE
    USING (organizacao_id = plataforma.org_atual('tce')
           OR plataforma.tem_suporte_ativo('tce', organizacao_id))
    WITH CHECK (organizacao_id = plataforma.org_atual('tce')
                OR plataforma.tem_suporte_ativo('tce', organizacao_id));
CREATE POLICY etiquetas_delete ON tce.etiquetas FOR DELETE
    USING (organizacao_id = plataforma.org_atual('tce'));

-- modelos_documento
CREATE POLICY modelos_select ON tce.modelos_documento FOR SELECT
    USING (organizacao_id = plataforma.org_atual('tce')
           OR plataforma.tem_suporte_ativo('tce', organizacao_id));
CREATE POLICY modelos_insert ON tce.modelos_documento FOR INSERT
    WITH CHECK (organizacao_id = plataforma.org_atual('tce')
                OR plataforma.tem_suporte_ativo('tce', organizacao_id));
CREATE POLICY modelos_update ON tce.modelos_documento FOR UPDATE
    USING (organizacao_id = plataforma.org_atual('tce')
           OR plataforma.tem_suporte_ativo('tce', organizacao_id))
    WITH CHECK (organizacao_id = plataforma.org_atual('tce')
                OR plataforma.tem_suporte_ativo('tce', organizacao_id));
CREATE POLICY modelos_delete ON tce.modelos_documento FOR DELETE
    USING (organizacao_id = plataforma.org_atual('tce'));

-- sugestoes: o autor manda, o superadmin responde. Ninguem deleta.
CREATE POLICY sugestoes_select ON tce.sugestoes FOR SELECT
    USING (plataforma.eh_papel_de_plataforma('tce')
           OR organizacao_id = plataforma.org_atual('tce'));
CREATE POLICY sugestoes_insert ON tce.sugestoes FOR INSERT
    WITH CHECK (organizacao_id = plataforma.org_atual('tce'));
CREATE POLICY sugestoes_update ON tce.sugestoes FOR UPDATE
    USING (plataforma.eh_papel_de_plataforma('tce'))
    WITH CHECK (plataforma.eh_papel_de_plataforma('tce'));

-- ---------------------------------------------------------------------------
-- processos_monitorados: o gestor publico ve MENOS que o tenant.
--
-- Erro a evitar: adicionar uma policy separada para o gestor. No Postgres,
-- policies permissivas na mesma operacao se combinam por OR, entao o gestor
-- passaria pela policy do tenant e veria TODOS os clientes do escritorio -
-- exatamente o vazamento que a policy extra pretendia impedir.
--
-- Regra geral: restricao de perfil entra como AND DENTRO da mesma policy.
-- Policy adicional so e segura para AMPLIAR acesso (suporte), nunca reduzir.
-- ---------------------------------------------------------------------------

ALTER TABLE tce.processos_monitorados ENABLE ROW LEVEL SECURITY;

CREATE POLICY monitorados_select ON tce.processos_monitorados FOR SELECT
    USING (
        plataforma.tem_suporte_ativo('tce', organizacao_id)
        OR (
            organizacao_id = plataforma.org_atual('tce')
            AND (
                plataforma.papel_atual('tce') <> 'gestor_publico'
                OR cliente_id IN (
                    SELECT c.id FROM tce.clientes c
                    JOIN plataforma.usuarios_sistema us ON us.id = c.usuario_sistema_id
                    WHERE us.auth_user_id = (SELECT auth.uid())
                )
            )
        )
    );

CREATE POLICY monitorados_insert ON tce.processos_monitorados FOR INSERT
    WITH CHECK (organizacao_id = plataforma.org_atual('tce')
                AND plataforma.papel_atual('tce') <> 'gestor_publico');

CREATE POLICY monitorados_update ON tce.processos_monitorados FOR UPDATE
    USING (organizacao_id = plataforma.org_atual('tce')
           AND plataforma.papel_atual('tce') <> 'gestor_publico')
    WITH CHECK (organizacao_id = plataforma.org_atual('tce')
                AND plataforma.papel_atual('tce') <> 'gestor_publico');

CREATE POLICY monitorados_delete ON tce.processos_monitorados FOR DELETE
    USING (organizacao_id = plataforma.org_atual('tce')
           AND plataforma.papel_atual('tce') <> 'gestor_publico');

-- ---------------------------------------------------------------------------
-- Pecas: versoes, comentarios e aprovacoes.
-- pecas_aprovacoes NAO recebe policy de UPDATE nem DELETE. Sem policy
-- permissiva, o RLS nega por padrao - e e isso que torna a imutabilidade uma
-- garantia do banco, nao uma convencao do codigo.
-- ---------------------------------------------------------------------------

ALTER TABLE tce.pecas_versoes     ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.pecas_comentarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.pecas_aprovacoes  ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.colunas           ENABLE ROW LEVEL SECURITY;
ALTER TABLE tce.tarefa_etiquetas  ENABLE ROW LEVEL SECURITY;

CREATE POLICY pecas_versoes_select ON tce.pecas_versoes FOR SELECT
    USING (EXISTS (SELECT 1 FROM tce.pecas p WHERE p.id = peca_id));
CREATE POLICY pecas_versoes_insert ON tce.pecas_versoes FOR INSERT
    WITH CHECK (EXISTS (SELECT 1 FROM tce.pecas p WHERE p.id = peca_id));

CREATE POLICY pecas_comentarios_select ON tce.pecas_comentarios FOR SELECT
    USING (EXISTS (SELECT 1 FROM tce.pecas p WHERE p.id = peca_id));
CREATE POLICY pecas_comentarios_insert ON tce.pecas_comentarios FOR INSERT
    WITH CHECK (EXISTS (SELECT 1 FROM tce.pecas p WHERE p.id = peca_id));

CREATE POLICY pecas_aprovacoes_select ON tce.pecas_aprovacoes FOR SELECT
    USING (EXISTS (SELECT 1 FROM tce.pecas p WHERE p.id = peca_id));
CREATE POLICY pecas_aprovacoes_insert ON tce.pecas_aprovacoes FOR INSERT
    WITH CHECK (EXISTS (SELECT 1 FROM tce.pecas p WHERE p.id = peca_id));

CREATE POLICY colunas_select ON tce.colunas FOR SELECT
    USING (EXISTS (SELECT 1 FROM tce.quadros q WHERE q.id = quadro_id));
CREATE POLICY colunas_write ON tce.colunas FOR ALL
    USING (EXISTS (SELECT 1 FROM tce.quadros q WHERE q.id = quadro_id))
    WITH CHECK (EXISTS (SELECT 1 FROM tce.quadros q WHERE q.id = quadro_id));

CREATE POLICY tarefa_etiquetas_all ON tce.tarefa_etiquetas FOR ALL
    USING (EXISTS (SELECT 1 FROM tce.tarefas t WHERE t.id = tarefa_id))
    WITH CHECK (EXISTS (SELECT 1 FROM tce.tarefas t WHERE t.id = tarefa_id));

-- ---------------------------------------------------------------------------
-- Schema plataforma: RLS nas tabelas de identidade.
--
-- Divergencia deliberada do PortalGov, que deixa estas tabelas com RLS
-- desabilitada e confia so nas RPC SECURITY DEFINER. Aqui a RLS fica ligada
-- tambem: se um caminho novo consultar a tabela direto (sem passar pela RPC),
-- ele falha fechado em vez de expor a base de usuarios.
-- ---------------------------------------------------------------------------

ALTER TABLE plataforma.sistemas            ENABLE ROW LEVEL SECURITY;
ALTER TABLE plataforma.papeis              ENABLE ROW LEVEL SECURITY;
ALTER TABLE plataforma.organizacoes        ENABLE ROW LEVEL SECURITY;
ALTER TABLE plataforma.assinaturas         ENABLE ROW LEVEL SECURITY;
ALTER TABLE plataforma.usuarios_sistema    ENABLE ROW LEVEL SECURITY;
ALTER TABLE plataforma.convites            ENABLE ROW LEVEL SECURITY;
ALTER TABLE plataforma.permissoes_usuario  ENABLE ROW LEVEL SECURITY;
ALTER TABLE plataforma.sessoes_suporte     ENABLE ROW LEVEL SECURITY;
ALTER TABLE plataforma.logs_auditoria      ENABLE ROW LEVEL SECURITY;
ALTER TABLE plataforma.catalogo_municipios ENABLE ROW LEVEL SECURITY;

CREATE POLICY sistemas_select ON plataforma.sistemas
    FOR SELECT TO authenticated USING (true);
CREATE POLICY papeis_select ON plataforma.papeis
    FOR SELECT TO authenticated USING (true);
CREATE POLICY catalogo_select ON plataforma.catalogo_municipios
    FOR SELECT TO authenticated USING (true);

-- Cada um ve a propria linha; superadmin ve as do sistema; tenant_admin ve as
-- da propria organizacao.
CREATE POLICY usuarios_sistema_select ON plataforma.usuarios_sistema FOR SELECT
    USING (
        auth_user_id = (SELECT auth.uid())
        OR plataforma.eh_papel_de_plataforma(sistema)
        OR (organizacao_id = plataforma.org_atual(sistema)
            AND plataforma.papel_atual(sistema) = 'admin_escritorio')
        OR plataforma.tem_suporte_ativo(sistema, organizacao_id)
    );

CREATE POLICY organizacoes_select ON plataforma.organizacoes FOR SELECT
    USING (
        plataforma.eh_papel_de_plataforma('tce')
        OR id = plataforma.org_atual('tce')
        OR plataforma.tem_suporte_ativo('tce', id)
    );

CREATE POLICY assinaturas_select ON plataforma.assinaturas FOR SELECT
    USING (
        plataforma.eh_papel_de_plataforma(sistema)
        OR organizacao_id = plataforma.org_atual(sistema)
    );

-- Sessao de suporte e visivel ao cliente: e o que torna o acesso defensavel.
CREATE POLICY sessoes_suporte_select ON plataforma.sessoes_suporte FOR SELECT
    USING (
        plataforma.eh_papel_de_plataforma(sistema)
        OR organizacao_id = plataforma.org_atual(sistema)
    );

CREATE POLICY logs_auditoria_select ON plataforma.logs_auditoria FOR SELECT
    USING (
        plataforma.eh_papel_de_plataforma('tce')
        OR organizacao_id = plataforma.org_atual('tce')
    );

CREATE POLICY permissoes_usuario_select ON plataforma.permissoes_usuario FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM plataforma.usuarios_sistema us
        WHERE us.id = usuario_sistema_id
          AND (us.auth_user_id = (SELECT auth.uid())
               OR plataforma.eh_papel_de_plataforma(us.sistema))
    ));

-- convites: sem policy. So a RPC de primeiro acesso (SECURITY DEFINER) le, por
-- token_hash. Expor a tabela permitiria enumerar convites pendentes.

-- ---------------------------------------------------------------------------
-- Role dedicada de ingestao
--
-- O cron do TCE roda sem sessao de usuario, entao nao ha auth.uid() e a RLS
-- bloquearia tudo. A saida obvia seria a service_role - mas ela e do PROJETO:
-- alcanca qualquer schema, inclusive os dos outros sistemas que vierem morar
-- aqui (clinicas, gerencial, tarefas).
--
-- tce_ingestor limita o estrago a este schema: se a chave vazar, o atacante
-- alcanca o espelho publico do TCE, nao a base inteira.
-- ---------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tce_ingestor') THEN
        CREATE ROLE tce_ingestor NOLOGIN;
    END IF;
END
$$;

GRANT USAGE ON SCHEMA tce TO tce_ingestor;
GRANT USAGE ON SCHEMA plataforma TO tce_ingestor;

GRANT SELECT, INSERT, UPDATE, DELETE ON
    tce.processos, tce.tramites, tce.documentos_processo,
    tce.julgamentos, tce.interessados, tce.municipios,
    tce.sync_runs, tce.notificacoes
TO tce_ingestor;

GRANT SELECT ON
    tce.regras_classificacao, tce.processos_monitorados, tce.clientes,
    tce.planos, tce.uso_quotas, plataforma.organizacoes,
    plataforma.usuarios_sistema, plataforma.assinaturas
TO tce_ingestor;

-- BYPASSRLS nao e concedido: a ingestao age sobre o espelho publico, que nao
-- tem policy de escrita para usuario nenhum - o GRANT acima ja basta. As
-- tabelas de tenant ficam em SELECT, o suficiente para decidir quem notificar.
ALTER TABLE tce.processos           FORCE ROW LEVEL SECURITY;
ALTER TABLE tce.tramites            FORCE ROW LEVEL SECURITY;
ALTER TABLE tce.documentos_processo FORCE ROW LEVEL SECURITY;

CREATE POLICY processos_ingestor ON tce.processos
    FOR ALL TO tce_ingestor USING (true) WITH CHECK (true);
CREATE POLICY tramites_ingestor ON tce.tramites
    FOR ALL TO tce_ingestor USING (true) WITH CHECK (true);
CREATE POLICY documentos_ingestor ON tce.documentos_processo
    FOR ALL TO tce_ingestor USING (true) WITH CHECK (true);
CREATE POLICY julgamentos_ingestor ON tce.julgamentos
    FOR ALL TO tce_ingestor USING (true) WITH CHECK (true);
CREATE POLICY interessados_ingestor ON tce.interessados
    FOR ALL TO tce_ingestor USING (true) WITH CHECK (true);
CREATE POLICY municipios_ingestor ON tce.municipios
    FOR ALL TO tce_ingestor USING (true) WITH CHECK (true);
CREATE POLICY sync_runs_ingestor ON tce.sync_runs
    FOR ALL TO tce_ingestor USING (true) WITH CHECK (true);
CREATE POLICY notificacoes_ingestor ON tce.notificacoes
    FOR ALL TO tce_ingestor USING (true) WITH CHECK (true);
CREATE POLICY monitorados_ingestor ON tce.processos_monitorados
    FOR SELECT TO tce_ingestor USING (true);
CREATE POLICY clientes_ingestor ON tce.clientes
    FOR SELECT TO tce_ingestor USING (true);
CREATE POLICY regras_ingestor ON tce.regras_classificacao
    FOR SELECT TO tce_ingestor USING (true);
CREATE POLICY organizacoes_ingestor ON plataforma.organizacoes
    FOR SELECT TO tce_ingestor USING (true);
CREATE POLICY usuarios_sistema_ingestor ON plataforma.usuarios_sistema
    FOR SELECT TO tce_ingestor USING (true);
CREATE POLICY assinaturas_ingestor ON plataforma.assinaturas
    FOR SELECT TO tce_ingestor USING (true);
CREATE POLICY uso_quotas_ingestor ON tce.uso_quotas
    FOR SELECT TO tce_ingestor USING (true);
CREATE POLICY planos_ingestor ON tce.planos
    FOR SELECT TO tce_ingestor USING (true);

-- authenticated precisa enxergar os schemas para a RLS sequer ser avaliada.
GRANT USAGE ON SCHEMA tce, plataforma TO authenticated, anon;
GRANT SELECT ON ALL TABLES IN SCHEMA tce TO authenticated;
GRANT INSERT, UPDATE, DELETE ON
    tce.clientes, tce.processos_monitorados, tce.prazos, tce.pecas,
    tce.pecas_versoes, tce.pecas_comentarios, tce.pecas_aprovacoes,
    tce.quadros, tce.colunas, tce.tarefas, tce.etiquetas,
    tce.tarefa_etiquetas, tce.modelos_documento, tce.sugestoes
TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA plataforma TO authenticated;
