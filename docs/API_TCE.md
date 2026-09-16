# API do TCE-CE — Referência Técnica

> Mapeamento obtido por inspeção do Portal Contexto (`https://www.tce.ce.gov.br/contexto/`) e do bundle `main.js` da aplicação Angular, com todas as chamadas validadas ao vivo em **16/09/2026**.

O TCE-CE expõe uma **API REST pública, sem autenticação**, retornando JSON estruturado. Não é necessário scraping de HTML.

---

## Hosts

| Host | Uso |
| :--- | :--- |
| `https://api-processos.tce.ce.gov.br` | **Principal** — processos, protocolos, tabelas auxiliares |
| `https://contexto-api.tce.ce.gov.br` | Sessões, pautas, normativos, diários oficiais, logs |
| `https://ged.tce.ce.gov.br/sap.php/consultas` | Gestão eletrônica de documentos |
| `https://api-add.tce.ce.gov.br` | Não mapeado |
| `https://portaljurisdicionado.tce.ce.gov.br` | Portal do jurisdicionado |

**Header obrigatório:** `Origin: https://www.tce.ce.gov.br`
**Content-Type:** `application/json` nas chamadas POST

> **Não confundir com a API de Dados Abertos do SIM** (`api-dados-abertos.tce.ce.gov.br/sim/`), oficial, documentada via Swagger e **separada** desta. O SIM cobre licitações, orçamento, folha e patrimônio municipal — não trâmites processuais. Não serve como fonte de dados deste projeto, mas sua política de uso pública (throttle declarado, incentivo a automação, sem exigência de credencial para leitura) é referência do padrão que o TCE-CE considera aceitável. Ver [CONFORMIDADE.md](CONFORMIDADE.md#3-política-de-coleta).

---

## ⚠️ Armadilha crítica: `numero` vs `numeros`

| Endpoint | Campo | Tipo |
| :--- | :--- | :--- |
| `/processos/porNumero` | `numero` | string (**singular**) |
| `/processos/porLista` | `numeros` | array (**plural**) |

Passar o campo errado retorna `{"errors":[],"data":{"lista":[]},"totalPages":null,"totalResultados":null}` com **HTTP 200**. Não há mensagem de erro — a consulta simplesmente volta vazia.

Este comportamento custou tempo na investigação e só foi resolvido lendo o bundle JavaScript da aplicação. O `TceClient` deve tipar os dois payloads separadamente para tornar o erro impossível.

---

## Endpoints

### `POST /processos/porLista` — busca e listagem

Descoberta de processos por filtros. Base do sync diário.

**Request**
```json
{
  "numeros": [],
  "filtros": { "localidade": ["72"] },
  "pagina": 1,
  "qtd": 10
}
```

- `numeros` — array de números de processo; vazio para buscar só por filtro
- `filtros` — objeto de filtros (ver [Filtros](#filtros)); valores sempre como **array de string**
- `pagina` — 1-indexado
- `qtd` — **ignorado pelo backend.** Testado `5, 10, 20, 50, 100, 500`: a resposta sempre traz **10 itens por página**, e `totalPages` já vem calculado com base em 10 fixo. Dimensionar chunking assumindo `2431 processos ÷ 10 = 244 páginas`, nunca por `qtd` enviado.

⚠️ **`numeros` preenchido + `filtros: null` → HTTP 500.** Só funciona com `filtros: {}` (objeto vazio, não `null`). Combinar `numeros` com um filtro real (ex.: `localidade`) também retorna 500 — os dois parâmetros são mutuamente exclusivos na prática, apesar de a doc do bundle não indicar isso. Além disso, buscar por lote de `numeros` **não retorna `tramites`** (vem `null`, igual à listagem por filtro) — não existe atalho de batching para trâmites; `porNumero` individual é inevitável.

**Response**
```json
{
  "errors": [],
  "data": { "lista": [ /* ... */ ] },
  "totalPages": 244,
  "totalResultados": 2431
}
```

Na listagem, `tramites`, `documentos` e `julgamentos` vêm `null` — é preciso chamar `porNumero` para obtê-los.

---

### `POST /processos/porNumero` — detalhe completo

**A fonte do monitoramento.** Único endpoint que devolve trâmites.

**Request**
```json
{
  "numero": "20909/2026-1",
  "filtros": null,
  "pagina": 0,
  "qtd": 20
}
```

**Response** — campos do objeto em `data.lista[0]`:

| Campo | Tipo | Observação |
| :--- | :--- | :--- |
| `nrProcesso` | string | Formato `NNNNN/AAAA-D` |
| `nrProtocolo` | string | Formato `NNNNNN/AAAA` |
| `exercicio` | int | Ano de exercício (≠ ano do processo) |
| `dtAutuacao` | string | `DD/MM/AAAA` |
| `dtUltimoEncaminhamento` | string | `DD/MM/AAAA` |
| `assunto` | string | Texto livre |
| `sigiloso` | bool | **`true` → descartar o processo inteiro** |
| `eletronico` | bool | |
| `mensagemAviso` | string \| null | Aviso do próprio TCE |
| `entidade` | objeto | `{id, descricao, unidadeAdministrativa, sigla}` |
| `localidade` | objeto | `{id, descricao}` — município |
| `especie` · `subEspecie` | objeto | `{id, descricao}` |
| `setor` | objeto | Setor onde o processo está |
| `relator` | objeto \| null | `{nome, nomeAbreviado}` |
| `tramites` | array | **Histórico de movimentação** |
| `documentos` | objeto | `{documentosPrincipal: [...]}` |
| `julgamentos` | array | |
| `interessados` | array | `{idinteressado, nminteressado, preservado}` |
| `correlatos` | objeto | Processos apensados, juntados, derivados |

**`tramites[]`**
```json
{
  "id": 6181240,
  "data": "02/09/2026",
  "acao": { "id": 89458, "descricao": "PARA ANÁLISE" },
  "setorOrigem":  { "id": 425, "descricao": "GERENCIA DE APOIO AS SESSOES" },
  "setorDestino": { "id": 295, "descricao": "DIRETORIA DE ATOS DE REGISTRO III" },
  "ultimoTramite": false
}
```

`tramites[].id` é numérico e crescente → **chave natural de deduplicação**. Persistir como `tramite_id_tce UNIQUE` e detectar movimentação nova comparando o conjunto de ids.

**`documentos.documentosPrincipal[]`**
```json
{
  "id": 9738610,
  "numeroProcesso": "20909/2026-1",
  "numero": 8095,
  "ano": 2026,
  "dataFinalizacao": "02/09/2026",
  "tipoAtoDocumento": { "id": 430, "descricao": "TERMO DE DISTRIBUIÇÃO", "bloqueioVisualizacao": null },
  "setor": { "id": 425, "descricao": "GERENCIA DE APOIO AS SESSOES" },
  "exibirDocumento": false,
  "assinaturas": null
}
```

`id: 0` indica documento sem arquivo acessível. Respeitar `exibirDocumento` e `bloqueioVisualizacao`.

---

### `POST /protocolos/porLista` · `POST /protocolos/porNumero`

Mesma estrutura, para protocolos.

---

### `GET /tabelas-auxiliares/{tabela}`

Catálogos de filtro. **Confirmado na Fase 0 (16/09/2026): o problema não era o método (GET funciona), era o host.** O bundle declara as 13 rotas sob um único `url_base`, mas elas estão espalhadas em **dois hosts diferentes** — nunca em `api-add`.

| Host | Rotas confirmadas | `id` |
| :--- | :--- | :--- |
| `api-processos.tce.ce.gov.br` | `localidade` (186 itens), `especie` (207), `tipo-documento` (809 itens — **catálogo diferente** do de mesmo nome no outro host) | **inteiro** |
| `contexto-api.tce.ce.gov.br` | `localidade` (186), `subespecie` (365), `entidade` (11.542), `setor` (374), `categoria-especie` (4), `esfera-julgamento` (7), `situacao` (144), `membro-relator` (32), `tipo-sessao` (19), `tipo-julgamento` (156), `tipo-documento` (569 — **catálogo diferente**), `interessado` (ver abaixo) | **string** |

```json
{ "errors": [], "data": { "lista": [ { "id": 72, "descricao": "HORIZONTE" } ] } }
```

⚠️ **`id` muda de tipo entre hosts.** A mesma tabela `localidade` devolve `"id": 1` (int) em `api-processos` e `"id": "1"` (string) em `contexto-api`. O `TceClient` deve normalizar para um tipo único antes de persistir — comparação solta (`==`) ou cast explícito, nunca assumir o tipo do JSON.

⚠️ **`tipo-documento` não é a mesma tabela nos dois hosts** (809 itens vs 569, primeiro item diferente). Ainda não determinado qual delas corresponde a `tipoAtoDocumento` dentro de `documentos.documentosPrincipal[]` — validar por amostragem antes de usar como FK.

🔴 **`/tabelas-auxiliares/interessado` (em `contexto-api`) é inútil e não deve ser chamado.** Sempre devolve os mesmos 10 registros fixos, ignorando `qtd`, `pagina`, `descricao` e `termo` — não é uma busca. Além disso os registros trazem nome de pessoa física sem qualquer paginação ou filtro, então não há uso legítimo dela no projeto: não filtra por processo, não pagina, não deduplicaria nada. **Não integrar.**

`subespecie` aceita filtro opcional `?idespecie={id}` (retorna a subespécie com o campo `idespecie` já no item, então o filtro é dispensável para uso batch).

---

## Filtros

Aceitos em `filtros` de `porLista`. Valores sempre como array de string, mesmo quando único.

| Chave | Origem dos valores |
| :--- | :--- |
| `localidade` | `/tabelas-auxiliares/localidade` |
| `especie` · `subespecie` | `/tabelas-auxiliares/especie` |
| `entidade` · `setor` · `situacao` | tabelas auxiliares correspondentes |
| `membro-relator` · `esfera-julgamento` · `tipo-julgamento` | idem |

O Portal Contexto expõe na interface: entidade, espécie, subespécie, colegiado, localidade, relator e julgamento.

---

## Comportamento operacional

### Volume

Horizonte/CE (`localidade: 72`) → **2.431 processos**, 244 páginas de 10 (`qtd` é ignorado, ver acima).

O sync completo exige `porLista` para descobrir + `porNumero` por processo para obter trâmites — não há atalho de batching (ver armadilha de `numeros` acima). Custo medido na Fase 0 (throttle 1 req/s, sequencial): **descoberta ~813s (244 páginas) + detalhe ~3.900s (2.431 processos, 606ms médio por chamada) ≈ 78min no total** para uma carga inicial completa. Isso excede o limite de execução de uma função serverless da Vercel — exige chunking com auto-continuação (ver [ARQUITETURA.md § Chunking](ARQUITETURA.md)).

**Para o sync diário (não a carga inicial), a descoberta domina o custo, não o detalhe.** `porLista` já traz `dtUltimoEncaminhamento` no item da listagem — dá para comparar com o valor persistido e só chamar `porNumero` nos processos cuja data mudou, evitando 2.431 chamadas de detalhe todo dia. Ainda assim as 244 páginas de descoberta (~813s) precisam ser varridas inteiras: **a ordenação de `porLista` não é por data** (página 2 mistura datas de agosto e setembro fora de ordem) e **`filtros.exercicio` não permite recortar com segurança** — a soma por exercício de 2005 a 2026 fecha em 2.421 de 2.431 (faltam 10 processos que não caem em nenhum exercício testado). Não usar `exercicio` para pular parte da varredura sem investigar os 10 processos ausentes primeiro.

### Rate limit

Não detectado: 5 requisições consecutivas retornaram HTTP 200, com 2–5s cada.

**Ainda assim, aplicar throttle voluntário de 1 req/s** e `User-Agent` identificável. Ausência de limite técnico não é autorização para consumo agressivo — e a boa-fé documentada protege o projeto.

### robots.txt

`https://www.tce.ce.gov.br/robots.txt` bloqueia apenas pastas internas do Joomla (`/administrator/`, `/cache/`, `/templates/`…). **Não** bloqueia `/contexto` nem a API. `api-processos.tce.ce.gov.br` não tem robots.txt (404).

### Erros

Backend Spring Boot. Rota inexistente:
```json
{"timestamp":"...","status":404,"error":"Not Found","path":"/rota"}
```

Consulta sem resultado **não** é erro: HTTP 200 com `data.lista: []`.

Não há Swagger/OpenAPI exposto (`/v3/api-docs`, `/swagger-ui`, `/actuator` → 404). Este documento é a referência disponível.

---

## Filtro de privacidade (obrigatório)

Aplicado no `TceClient`, **antes de qualquer persistência** — o dado proibido não entra no sistema, então nenhuma camada acima precisa se defender dele.

| Condição | Ação |
| :--- | :--- |
| `sigiloso: true` | Descartar o processo inteiro. Não persistir nada. |
| `interessados[].preservado: true` | Não persistir nem exibir `nminteressado`. Manter só `idinteressado`. |
| `documentos[].exibirDocumento !== true` | Não disponibilizar download. |
| `tipoAtoDocumento.bloqueioVisualizacao != null` | Respeitar o bloqueio (não exibir/baixar). |

Vale inclusive no inspetor do console interno: processo sigiloso não é renderizado nem em diagnóstico.

⚠️ **Comparação exata obrigatória — amostra de 564 documentos (Fase 0, 16/09/2026) nunca teve `exibirDocumento: true`.** Os únicos valores observados foram `null` (326 casos) e `false` (238 casos, e os 238 coincidem exatamente com `id: 0`, ou seja, documento sem arquivo). Um filtro escrito como `if (exibirDocumento === false)` deixa passar o `null` sem bloquear nada; um filtro `if (!exibirDocumento)` bloqueia praticamente tudo, inclusive documentos legítimos. A regra correta é **allowlist, não blocklist**: só liberar quando o valor for estritamente `true`. Como isso nunca ocorreu na amostra, **na prática nenhum download de documento deve ser oferecido no MVP** até se confirmar em produção que `true` de fato aparece — validar isso é um item de acompanhamento, não uma suposição a codificar.

⚠️ **`bloqueioVisualizacao` não é booleano — é `null` ou um ID de tipo de bloqueio** (valores observados: `102203`, `102204`; 150 de 564 documentos bloqueados). Um `if (bloqueioVisualizacao === true)` nunca é verdadeiro e libera tudo por acidente. A checagem correta é `!= null` (ou `bloqueioVisualizacao != null`), nunca comparação estrita com `true`.

**Endpoint de download confirmado:** `GET https://api-add.tce.ce.gov.br/arquivos/documento?documento_id={id}` — sem autenticação, devolve `application/pdf` diretamente (confirmado com um documento real de Horizonte). `api-processos.tce.ce.gov.br` responde 404 para essa rota; o host correto é sempre `api-add`.

**Base normativa confirmada:** o próprio bundle do Contexto cita, no aviso exibido ao tentar abrir um documento sigiloso, a **Resolução Administrativa nº 05/2024/TCE-CE** — junto com LGPD, Lei Orgânica do TCE e Lei de Acesso à Informação — como fundamento de sigilo. As flags `sigiloso`/`exibirDocumento` são o reflexo técnico dessa resolução; o `TceClient` apenas respeita o que a própria API já sinaliza. Texto integral da 05/2024 não localizado publicado — requerer via LAI/Ouvidoria se necessário para o parecer jurídico.

Justificativa e base legal em [CONFORMIDADE.md](CONFORMIDADE.md).

---

## Pendências

1. ✅ **Termos de Uso do Portal Contexto** — pesquisado em 17/09/2026: nenhum termo dedicado publicado. Achados e análise completa em [CONFORMIDADE.md § Pesquisa de termos de uso](CONFORMIDADE.md#pesquisa-de-termos-de-uso-17092026). Resta formalizar contato institucional antes do lançamento.
2. ✅ **Tabelas auxiliares restantes** — mapeadas na Fase 0 (16/09/2026): não era problema de método, era host (`contexto-api`, não `api-processos`). Ver tabela acima. **`interessado` não deve ser integrado** (sempre devolve os mesmos 10 registros fixos, ignora todo parâmetro).
3. ✅ **Endpoint de download de documento** — confirmado na Fase 0: `GET https://api-add.tce.ce.gov.br/arquivos/documento?documento_id={id}`, sem autenticação, devolve PDF direto.
4. **Estabilidade do contrato** — a API não é versionada e não tem documentação oficial publicada. O `TceClient` deve validar o shape da resposta e falhar alto se o contrato mudar, em vez de gravar dado corrompido.
5. **Os 10 processos de Horizonte fora de qualquer `exercicio` 2005–2026** — não identificados individualmente na Fase 0. Não bloqueia o MVP (a varredura completa por página os alcança de qualquer forma), mas explica por que `exercicio` não pode virar critério de particionamento do sync sem essa investigação.
6. **Qual `tipo-documento` corresponde a `tipoAtoDocumento` em `documentos.documentosPrincipal[]`** — os dois hosts têm catálogos com nomes iguais e conteúdos diferentes (809 vs 569 itens); não determinado qual é a FK correta antes de modelar a tabela.
