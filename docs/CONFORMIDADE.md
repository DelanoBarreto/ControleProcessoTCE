# Conformidade — LGPD, Ética Profissional e Política de Coleta

> Documento técnico de referência. **Não substitui parecer jurídico.** Antes do lançamento comercial, submeter a advogado especializado em proteção de dados e a profissional habilitado quanto às regras da OAB.

---

## Por que este documento existe

A plataforma coleta dados de processos públicos do TCE-CE, identifica gestores municipais com processos em andamento e os aborda por WhatsApp e e-mail. Isso é o principal diferencial comercial — e a principal exposição jurídica.

Três frentes precisam de resposta antes do lançamento:

1. **LGPD** — dado público não é dado livre. A finalidade original (transparência) não autoriza automaticamente a finalidade nova (prospecção comercial).
2. **Ética profissional (OAB)** — o Código de Ética veda captação de clientela e mercantilização da advocacia.
3. **Política de uso do TCE** — mesmo com API aberta, o consumo automatizado precisa ser de boa-fé e documentado.

---

## 1. LGPD

### Dados tratados

| Categoria | Origem | Exemplos |
| :--- | :--- | :--- |
| Dados processuais públicos | API do TCE-CE | Número, espécie, entidade, trâmites, relator |
| Dados pessoais de interessados | API do TCE-CE | Nome de gestores e servidores citados |
| Dados de contato | Fontes externas / cadastro | E-mail, telefone |
| Dados de clientes | Cadastro no sistema | Nome, CPF/CNPJ, cargo, contato |
| Dados de usuários | Cadastro | Nome, e-mail, telefone, credenciais |

### Base legal por finalidade

| Finalidade | Base legal | Observação |
| :--- | :--- | :--- |
| Monitorar processo de **cliente contratante** | Execução de contrato (Art. 7º, V) | Sem controvérsia |
| Operar conta de usuário | Execução de contrato (Art. 7º, V) | |
| Manter espelho de dados processuais públicos | Legítimo interesse (Art. 7º, IX) | Dado já público, finalidade compatível com transparência |
| **Contatar gestor não-cliente com alerta gratuito** | **Legítimo interesse (Art. 7º, IX)** | ⚠️ **Exige teste de balanceamento e opt-out** — ponto crítico |
| Cumprir obrigação legal | Art. 7º, II | Retenção fiscal e contábil |

### Teste de balanceamento — prospecção via alerta

Exigido pelo Art. 10 da LGPD para fundamentar legítimo interesse. Registro da análise:

**a) Finalidade legítima, específica e informada**
Informar gestor público de que existe processo em seu nome no TCE, com prazo eventualmente correndo. Finalidade concreta e comunicada no primeiro contato.

**b) Necessidade**
Não há meio menos invasivo de alcançar o efeito. O TCE publica o dado, mas não notifica ativamente o gestor. A informação só cumpre função útil se chegar a quem é afetado — e chegar a tempo.

**c) Expectativa legítima do titular**
Gestor público que responde por processo em Tribunal de Contas **espera** ser informado sobre ele. O tratamento não contraria expectativa razoável; a rigor, atende uma expectativa frustrada pelo sistema atual.

**d) Salvaguardas adotadas**

- Primeiro contato é **informativo e gratuito**, não oferta de serviço jurídico
- **Opt-out em toda comunicação**, com efeito imediato e permanente
- Origem do dado **declarada explicitamente** no primeiro contato
- Nenhum dado sigiloso tratado (ver Filtro de privacidade)
- Nenhum dado de pessoa com sigilo preservado pelo próprio TCE
- Canal de atendimento a direitos do titular
- Frequência limitada — sem insistência após não-resposta

**e) Direitos do titular preservados**
Acesso, correção, eliminação, oposição e informação sobre compartilhamento — todos atendíveis pelo canal de contato.

**Conclusão da análise:** o legítimo interesse sustenta-se **desde que** as salvaguardas acima sejam efetivamente implementadas. Sem opt-out funcional e sem o enquadramento informativo do primeiro contato, a base legal se desfaz.

### Direitos do titular

Canal obrigatório para:

| Direito | Prazo |
| :--- | :--- |
| Confirmação de tratamento e acesso | 15 dias |
| Correção | Imediato |
| Anonimização, bloqueio ou eliminação | Imediato quando desnecessário |
| Oposição ao tratamento | **Imediato** — opt-out da base |
| Informação sobre compartilhamento | 15 dias |

Toda solicitação registrada em `logs_auditoria`.

### Retenção

| Dado | Prazo |
| :--- | :--- |
| Processos e trâmites | Enquanto o processo tramitar + 5 anos |
| Dados de cliente ativo | Durante o contrato + 5 anos (fiscal) |
| Lead que não converteu | **12 meses** sem interação → eliminar |
| Opt-out | **Permanente** — lista de supressão nunca é apagada |
| Logs de auditoria | 5 anos |

> A lista de opt-out é a única base que nunca se apaga: apagá-la faria o titular voltar a ser contatado, anulando o direito exercido.

---

## 2. Ética profissional (OAB)

### O risco

O Código de Ética e Disciplina da OAB veda captação de clientela e mercantilização da advocacia. Um escritório que aborda gestor dizendo "vi que você tem processo no TCE, posso defendê-lo" tende a configurar infração disciplinar.

**Isso não inviabiliza o produto — muda quem faz a abordagem e como.**

### Como o produto se posiciona

| ❌ Não fazer | ✅ Fazer |
| :--- | :--- |
| Escritório aborda oferecendo serviço | **Plataforma** envia alerta informativo gratuito |
| "Posso cuidar do seu processo" | "Há movimentação no processo X; consulte aqui" |
| Contato parte do advogado | Contato parte do serviço; o gestor procura o escritório se quiser |
| Menção a honorários no primeiro contato | Nenhuma oferta de serviço jurídico no alerta |

A plataforma é um **serviço de informação** (como um alerta de vencimento bancário), não um canal de captação. O gestor recebe utilidade pública gratuita; se decidir contratar assessoria, procura por conta própria.

### Regras para o produto

1. O alerta automático **nunca** contém oferta de serviço jurídico
2. O alerta **não** é assinado por escritório nem por advogado — é da plataforma
3. Conteúdo gerado por IA marcado como **orientação automática, não aconselhamento jurídico**
4. Escritório assinante **não** recebe lista de gestores não-clientes para abordar
5. O gestor, ao buscar ajuda, é quem inicia o contato

> **Regra 4 é a mais importante.** Entregar lista de prospecção ao escritório transfere o risco disciplinar para o cliente e recria exatamente o problema que o posicionamento evita.

---

## 3. Política de coleta

### Fundamento

O TCE-CE expõe API REST pública, sem autenticação, com dados de transparência. O consumo é lícito, desde que de boa-fé.

Verificado em 16/09/2026:

- `robots.txt` de `www.tce.ce.gov.br` bloqueia apenas pastas internas do Joomla — **não** bloqueia `/contexto` nem a API
- `api-processos.tce.ce.gov.br` não publica `robots.txt`
- Nenhum rate limit detectado

### Regras de conduta

| Regra | Implementação |
| :--- | :--- |
| Throttle de 1 req/s | `TceClient`, mesmo sem limite imposto |
| `User-Agent` identificável | Nome da plataforma + contato |
| Nunca burlar bloqueio | Se surgir rate limit ou captcha, **respeitar e procurar o TCE** |
| Coletar só o necessário | Apenas municípios com `ativo = true` |
| Sem paralelismo agressivo | Sequencial com backoff |
| Horário de menor carga | Sync noturno |

> Ausência de limite técnico não é autorização para consumo agressivo. A boa-fé documentada é o que protege o projeto se a conduta for questionada.

### Filtro de privacidade

Aplicado no `TceClient`, **antes de qualquer persistência**:

| Condição | Ação |
| :--- | :--- |
| `sigiloso: true` | **Descartar o processo inteiro.** Nada é gravado. |
| `interessados[].preservado: true` | **Não gravar nem exibir o nome.** Só o id. |
| `documentos[].exibirDocumento: false` | Não disponibilizar download |
| `tipoAtoDocumento.bloqueioVisualizacao` | Respeitar o bloqueio |

O filtro vive em um único ponto. O dado proibido não entra no sistema, então nenhuma camada acima precisa se defender dele — e não há como esquecer de aplicá-lo numa tela nova.

**Vale também no console interno**, inclusive no inspetor de diagnóstico. Diagnóstico não é exceção à LGPD.

Verificação obrigatória:

```sql
-- ambas devem retornar zero
SELECT count(*) FROM processos WHERE raw->>'sigiloso' = 'true';
SELECT count(*) FROM interessados WHERE preservado = true AND nome IS NOT NULL;
```

---

## 4. Segurança da informação

| Medida | Implementação |
| :--- | :--- |
| Isolamento multi-tenant | RLS em toda tabela de negócio |
| Acesso de suporte | Sessão temporária, com motivo, auditada e visível ao cliente |
| Sessão de usuário | Iron Session AES-256-GCM; cookie `httpOnly`, `secure`, `sameSite: lax` |
| Senhas | bcrypt, custo 12 |
| Tokens | `secrets.token_urlsafe(32)` |
| Segredos de API | Criptografados em repouso; nunca em log |
| Auditoria | `logs_auditoria` com usuário, papel, IP e timestamp |
| Transporte | HTTPS obrigatório |

### Proibições no código

- Logar variável de ambiente sensível
- Logar dado pessoal (nome, e-mail, CPF, telefone) — usar identificadores
- `SUPABASE_SERVICE_ROLE_KEY` em `/app` ou `/components`
- Aceitar `escritorio_id` vindo do corpo da requisição

---

## 5. Comunicações automáticas

Toda mensagem automática contém:

1. **Identificação** da plataforma como remetente
2. **Origem do dado** — "informação pública do TCE-CE"
3. **Motivo do contato**
4. **Opt-out** funcional, com efeito imediato
5. **Contato** para exercício de direitos

Nunca contém: oferta de serviço jurídico, assinatura de escritório ou advogado, menção a honorários, ou dado processual sigiloso.

**Frequência:** um alerta por movimentação relevante. Sem reenvio por falta de resposta. Sem campanha de marketing na base de não-clientes.

---

## 6. Pendências antes do lançamento

| # | Pendência | Quando |
| :--- | :--- | :--- |
| 1 | Localizar Termos de Uso do Portal Contexto; se restringirem uso automatizado, formalizar pedido de acesso a dados abertos | **Fase 0** |
| 2 | Validação do teste de balanceamento por advogado de proteção de dados | Antes do lançamento |
| 3 | Parecer sobre o posicionamento perante o Código de Ética da OAB | Antes do lançamento |
| 4 | Redigir Política de Privacidade e Termos de Uso da plataforma | Antes do lançamento |
| 5 | Definir encarregado (DPO) e publicar canal de contato | Antes do lançamento |
| 6 | Contrato de tratamento com os escritórios (controlador × operador) | Antes do lançamento |

> **Pendência 1 é bloqueante para o projeto.** As demais são bloqueantes para o lançamento comercial, não para o desenvolvimento.

---

## Referências

- Lei 13.709/2018 (LGPD) — em especial Arts. 7º, 10 e 18
- Código de Ética e Disciplina da OAB — Art. 7º (captação de clientela)
- [API_TCE.md](API_TCE.md) — comportamento verificado da API
- [MODELAGEM_DADOS.md](MODELAGEM_DADOS.md) — RLS e retenção
- [CONSOLE_INTERNO.md](CONSOLE_INTERNO.md) — sessões de suporte e auditoria
