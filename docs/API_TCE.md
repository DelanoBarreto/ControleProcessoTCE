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
- `qtd` — itens por página

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

Catálogos de filtro.

**Confirmados**

| Rota | Conteúdo |
| :--- | :--- |
| `/tabelas-auxiliares/localidade` | 184 municípios — `{id, descricao}`; `id: 1` = "CEARÁ" (estado) |
| `/tabelas-auxiliares/especie` | Espécies processuais; `id: 0` = "INDEFINIDO" |

```json
{ "errors": [], "data": { "lista": [ { "id": 72, "descricao": "HORIZONTE" } ] } }
```

**Declarados no bundle, método a confirmar** (GET retornou 404 — provavelmente exigem POST ou parâmetro):

`subespecie` · `entidade` · `setor` · `categoria-especie` · `tipo-documento` · `esfera-julgamento` · `situacao` · `membro-relator` · `tipo-sessao` · `tipo-julgamento` · `interessado`

> Mapear na **Fase 0** do plano de MVP.

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

Horizonte/CE (`localidade: 72`) → **2.431 processos**, 244 páginas de 10.

O sync completo exige `porLista` para descobrir + `porNumero` por processo para obter trâmites. Dimensionar o chunking da Vercel a partir disso.

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
| `documentos[].exibirDocumento: false` | Não disponibilizar download. |
| `tipoAtoDocumento.bloqueioVisualizacao` | Respeitar o bloqueio. |

Vale inclusive no inspetor do console interno: processo sigiloso não é renderizado nem em diagnóstico.

Justificativa e base legal em [CONFORMIDADE.md](CONFORMIDADE.md).

---

## Pendências

1. **Termos de Uso do Portal Contexto** — localizar e verificar se há política de uso automatizado ou canal oficial de dados abertos. Se existir, formalizar o acesso por lá. *(Fase 0)*
2. **Tabelas auxiliares restantes** — descobrir o método correto das 11 rotas declaradas no bundle. *(Fase 0)*
3. **Endpoint de download de documento** — `/arquivos/documento` aparece no bundle sob `url_private`; verificar se exige autenticação.
4. **Estabilidade do contrato** — a API não é versionada e não tem documentação oficial publicada. O `TceClient` deve validar o shape da resposta e falhar alto se o contrato mudar, em vez de gravar dado corrompido.
