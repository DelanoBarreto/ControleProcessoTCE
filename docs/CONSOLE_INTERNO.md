# Console Interno (`/interno/*`)

Área de operação da plataforma. **Não é** o painel do escritório-cliente (`/admin/*`) — são níveis diferentes, com públicos diferentes.

---

## Três níveis de acesso

| Nível | Campo | Quem | Enxerga |
| :--- | :--- | :--- | :--- |
| Papel no tenant | `usuarios.perfil` | Clientes | Apenas o próprio `escritorio_id` |
| Poder de plataforma | `usuarios.is_superadmin` | Operação | Máquina de coleta — **nunca** dado privado de escritório |
| Poder de suporte | `usuarios.is_suporte` | Suporte | Nada por padrão; só o que uma sessão ativa liberar |

`is_superadmin` e `is_suporte` são **flags independentes**, fora de `perfil`. Uma pessoa pode ter ambas, uma só, ou nenhuma. Cada poder é concedido e revogado separadamente, e o log registra sob qual papel a ação foi feita.

**Por que separar:** superadmin e suporte precisam de acessos quase opostos. Superadmin opera a plataforma e não precisa ver o cadastro de cliente do escritório X; suporte entra no tenant do cliente e não precisa da máquina de coleta. Fundir os dois numa coluna só concentra poder desnecessário — é a origem clássica de vazamento multi-tenant.

---

## Proteção da rota

Bloqueio **no middleware**, uma vez, para todo o prefixo:

```ts
// middleware.ts — identidade via Supabase Auth, nunca sessão paralela
if (pathname.startsWith('/interno')) {
  const supabase = createMiddlewareClient({ req, res })
  const { data: { user } } = await supabase.auth.getUser()

  const { data: perfil } = await supabase
    .from('usuarios')
    .select('is_superadmin')
    .eq('id', user?.id)
    .single()

  if (!perfil?.is_superadmin) {
    return NextResponse.redirect(new URL('/admin', request.url))
  }
}
```

Nenhuma checagem espalhada por subrota — um ponto de entrada, uma verificação. As policies do banco reforçam no nível dos dados (`auth_is_superadmin()`), de modo que uma falha na UI não expõe registro algum — a mesma consulta `usuarios.is_superadmin` que o middleware faz é a que a função `auth_is_superadmin()` executa dentro da policy, contra `auth.uid()`.

---

## Rotas

### `/interno` — dashboard

- Último sync por município: quando, status, quantos processos e trâmites novos
- Fila de notificações: pendentes, falhas nas últimas 24h
- Trâmites não classificados aguardando regra
- Erros recentes

### `/interno/sync` — coleta

- Histórico de `sync_runs` com filtro por município e status
- **Disparar sync manual** de um município
- **Reprocessar** run que falhou, retomando pelo `cursor_pagina`
- Detalhe de execução: páginas lidas, processos novos, sigilosos descartados, erro

> Disparo manual e cron chamam **o mesmo service**. A tela não reimplementa a coleta (regra 06).

### `/interno/municipios` — escopo da coleta

- Lista dos 184 municípios com `ativo`, último sync e total de processos
- **Ativar/desativar** — controla `municipios.ativo`, que define o escopo do sync

É assim que a plataforma expande de Horizonte para outros municípios: um toggle, sem deploy.

### `/interno/notificacoes` — fila

- Pendentes, enviadas, falhas
- **Reenviar** individualmente ou em lote
- Motivo da falha e número de tentativas

### `/interno/inspetor` — diagnóstico

Consulta um número de processo direto na API do TCE e mostra a resposta crua ao lado do que está gravado no banco.

Serve para responder "o TCE mudou o dado ou o nosso sync falhou?" sem abrir terminal.

> **O filtro de privacidade vale aqui também:** processo com `sigiloso: true` não é renderizado nem em diagnóstico, e nome `preservado` não aparece. Diagnóstico não é exceção à LGPD.

### `/interno/classificacao` — regras de trâmite

- CRUD de `regras_classificacao` — sem deploy
- Trâmites **não cobertos por regra**, com a sugestão da IA
- **Promover sugestão a regra fixa**
- Testar regra contra trâmites históricos antes de ativar

A funcionalidade mais sensível do console: ela decide o que vira alerta. Regra errada ou notifica demais (cliente desliga) ou de menos (cliente perde prazo).

### `/interno/planos` — planos e limites

CRUD de `planos`: preço, limites de cada quota, feature flags.

### `/interno/assinaturas` — clientes

- Assinaturas por status (trial, ativa, inadimplente, cancelada)
- Consumo de quota por escritório
- Trocar plano
- **Conceder exceção pontual** sem mudar o tier (gravada em `assinaturas.observacao` e auditada)

### `/interno/ajuda` — conteúdo

- CRUD de `artigos_ajuda`
- Triagem de `sugestoes`: mudar status e responder

### `/interno/suporte` — sessões

- **Abrir sessão**: escolher escritório + **motivo obrigatório**
- Sessões ativas, com tempo restante
- **Encerrar** antes do prazo
- Histórico completo

### `/interno/auditoria` — logs

Consulta a `logs_auditoria` com filtro por usuário, escritório, ação e período.

---

## Sessões de suporte

Suporte **não tem** poder permanente de ler qualquer escritório. Para atender, abre uma sessão escopada.

### Regras

| Aspecto | Regra |
| :--- | :--- |
| Escopo | Um escritório por sessão |
| Prazo | 60 minutos, expira sozinha |
| Motivo | Obrigatório na abertura |
| Leitura | Liberada dentro do escritório |
| Escrita | Liberada — **exceto** deletar registros e alterar usuários/permissões |
| Identidade | Ações gravadas com o **usuário real de suporte**, nunca mascaradas como o cliente |
| Visibilidade | **Banner permanente** para o cliente enquanto ativa |
| Encerramento | Manual ou por expiração; ambos registrados |

### O que isso muda

Converte "meu suporte vê tudo" em:

> "O suporte acessou o escritório X às 14h02, por 40 minutos, motivo: 'cliente relatou erro ao cadastrar processo', e executou estas 3 ações."

Defensável perante a LGPD, e utilizável como argumento comercial — gestor público é o cliente mais sensível a isso que existe.

### Onde a expiração é verificada

**Na policy do Postgres**, não no código:

```sql
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

Se a interface esquecer de bloquear, o banco bloqueia. É isso que torna a auditoria confiável em vez de decorativa.

---

## Auditoria

Toda ação de escrita do console grava em `logs_auditoria`:

```
usuario_id · escritorio_id · papel · acao · entidade · entidade_id · dados · ip · created_at
```

`papel` distingue `superadmin`, `suporte` e `usuario` — a mesma pessoa aparece sob chapéus diferentes conforme o poder que exerceu.

Registrar sempre:

- Abertura e encerramento de sessão de suporte
- Qualquer escrita durante sessão de suporte
- Ativar/desativar município
- Disparo manual de sync e reprocessamento
- Alteração de plano, limite ou exceção de quota
- Criação e alteração de regra de classificação

---

## O que o console **não** faz

- **Não** tem CRUD de dados de escritório. Para isso existe a sessão de suporte, que é auditada e temporária.
- **Não** expõe dado de processo sigiloso, nem em diagnóstico.
- **Não** permite ao superadmin ler dados privados de escritório sem abrir sessão de suporte — são poderes distintos, mesmo acumulados na mesma pessoa.

---

## Referências

- [MODELAGEM_DADOS.md](MODELAGEM_DADOS.md) — tabelas e policies
- [ARQUITETURA.md](ARQUITETURA.md) — fluxo de coleta
- [CONFORMIDADE.md](CONFORMIDADE.md) — base legal
