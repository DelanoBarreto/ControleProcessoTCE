# Modelagem de Dados - ControleProcessoTCE

Este arquivo deve ser alimentado conforme as tabelas do projeto forem modeladas.

## Schema Base (Todas as tabelas)

Toda tabela de conteúdo gerenciável terá estes campos:

```sql
id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
created_at   timestamptz NOT NULL DEFAULT now(),
updated_at   timestamptz NOT NULL DEFAULT now(),
created_by   uuid        REFERENCES auth.users(id),
status       text        NOT NULL DEFAULT 'rascunho'
                         CHECK (status IN ('rascunho', 'publicado', 'arquivado')),
```

## Tabelas Iniciais Previstas

### 1. Entidades (tab_entidades)
Dados de entidades, órgãos ou prefeituras fiscalizadas pelo TCE.

### 2. Processos (tab_processos)
Controle principal dos processos.
Possíveis campos: Número, Ano, Entidade Relacionada, Relator, Tipo de Processo, Valor, PDF da Inicial.

### 3. Prazos (tab_prazos)
Prazos e tarefas do processo. Associado a um usuário responsável.

### 4. Gestores/Responsáveis (tab_responsaveis)
Gestores que estão sob julgamento ou acompanhamento.

---

*(Preencha os campos específicos das tabelas nesta seção antes de executá-las no Supabase).*
