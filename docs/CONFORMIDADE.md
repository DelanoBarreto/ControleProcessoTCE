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
- **Não existe página de "Termos de Uso" publicada e vinculada especificamente à API do Contexto** — buscado exaustivamente (site, rodapé, `#/ajuda`, busca externa) sem resultado. Ver "Pesquisa de termos de uso" abaixo.

### Pesquisa de termos de uso (17/09/2026)

Investigação dedicada para fechar a pendência #1. Três achados relevantes:

**a) O TCE-CE publica e incentiva ativamente uma API de dados abertos institucional — mas é outro sistema.**

`https://api-dados-abertos.tce.ce.gov.br/sim/` é uma API REST documentada via Swagger/OpenAPI, oficial, do **SIM** (Sistema Integrado Municipal — licitações, orçamento, folha, patrimônio). Não cobre o acompanhamento processual do Contexto (trâmites, relator, julgamentos), que é o dado que a plataforma precisa. Mas a política de uso publicada nela é a declaração institucional mais próxima de um "termo de uso de API" que o TCE-CE assume publicamente, e serve de indício forte de que consumo automatizado é bem-vindo pela instituição:

> *"Acesse e utilize os dados públicos do Tribunal de Contas do Estado do Ceará de forma simples e automatizada (...) Use para: criar aplicações, fazer análises, automatizar consultas de dados públicos."*
>
> Limites declarados: até 1.000 requisições/segundo · até 1.000 registros/requisição (paginação via `$start_index`) · acesso restrito a IPs do Brasil.

Esse texto **não se aplica juridicamente** à API do Contexto (`api-processos.tce.ce.gov.br`), que é um sistema separado. Mas é evidência de postura institucional favorável a automação de consulta a dados públicos, útil como elemento de contexto no teste de boa-fé — não como autorização.

**b) A norma que rege sigilo é a Resolução Administrativa nº 05/2024/TCE-CE — e ela já está refletida no comportamento da própria API.**

Encontrada no bundle JavaScript do app do Contexto, no texto exibido ao usuário quando tenta abrir um documento sigiloso:

> *"Este documento contém dados pessoais ou informações sigilosas protegidos por lei, tais como Lei Geral de Proteção de Dados Pessoais (LGPD), Lei Orgânica do TCE, Lei de Acesso à Informação e Resolução Administrativa nº 05/2024 do TCE-CE."*

Isso **confirma que o filtro de privacidade já adotado é o correto**: as flags `sigiloso: true` e `exibirDocumento: false` retornadas pela própria API são o reflexo técnico dessa resolução — o TCE já marca o que não deve circular, e o `TceClient` respeita essa marcação. O texto integral da Resolução 05/2024 não foi localizado publicado (não indexado por busca; pode estar em repositório interno de normativos). Se necessário para o parecer jurídico, requerer via LAI ou Ouvidoria (`ouvidoria@tce.ce.gov.br`).

**c) Não há documento de "termos de uso" dedicado ao Portal Contexto ou à sua API.**

Páginas verificadas sem resultado: `tce.ce.gov.br` (rodapé/menu), `contexto/#/ajuda`, `contexto/#/pagina-inicial`, `cidadao/consulta-de-processos`, `lgpd`, busca externa (Google) por `site:tce.ce.gov.br "termos de uso"`. Nenhuma restringe ou proíbe uso automatizado; também nenhuma autoriza explicitamente.

**Conclusão da pesquisa:** a ausência de termo publicado não é sinal de proibição — é ausência de regulamentação específica. Combinada com (a) a política pública de incentivo a automação no SIM e (b) a ausência de `robots.txt` restritivo ou autenticação na API do Contexto, o quadro sustenta a leitura de que o consumo é tolerado, desde que conduzido com as salvaguardas já adotadas (throttle, identificação, filtro de privacidade). **Não substitui formalização institucional** — ver pendência atualizada abaixo.

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
| Sessão de usuário | Supabase Auth (JWT); cookie de sessão `httpOnly`, `secure`, `sameSite: lax` |
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
| 1 | ✅ Pesquisado (17/09/2026) — nenhum termo de uso dedicado ao Contexto encontrado; ver "Pesquisa de termos de uso". **Formalizar contato institucional com o TCE-CE** (Ouvidoria ou área de TI) para comunicar o uso e obter posicionamento oficial, antes do lançamento comercial | **Fase 0** — pesquisa concluída; formalização antes do lançamento |
| 2 | Validação do teste de balanceamento por advogado de proteção de dados | Antes do lançamento |
| 3 | Parecer sobre o posicionamento perante o Código de Ética da OAB | Antes do lançamento |
| 4 | Redigir Política de Privacidade e Termos de Uso da plataforma | Antes do lançamento |
| 5 | Definir encarregado (DPO) e publicar canal de contato | Antes do lançamento |
| 6 | Contrato de tratamento com os escritórios (controlador × operador) | Antes do lançamento |

> **Pendência 1 foi pesquisada em 17/09/2026 e não bloqueia mais o desenvolvimento** — ver "Pesquisa de termos de uso" acima. Ficou apenas a formalização de contato institucional, exigível antes do lançamento comercial. As demais pendências (2–6) continuam bloqueantes só para o lançamento comercial, não para o desenvolvimento.

---

## Referências

- Lei 13.709/2018 (LGPD) — em especial Arts. 7º, 10 e 18
- Código de Ética e Disciplina da OAB — Art. 7º (captação de clientela)
- [API_TCE.md](API_TCE.md) — comportamento verificado da API
- [MODELAGEM_DADOS.md](MODELAGEM_DADOS.md) — RLS e retenção
- [CONSOLE_INTERNO.md](CONSOLE_INTERNO.md) — sessões de suporte e auditoria
