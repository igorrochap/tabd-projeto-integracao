# Projeto TABD — Como executar

*Uso de um Data Warehouse para análise de temas de opressão, desigualdade, discriminação e resistência em One Piece e sua associação com indicadores sociopolíticos contemporâneos.*

Este guia leva do zero até a carga completa do Data Warehouse pelo Pentaho Data Integration (PDI).

## Pré-requisitos

- Docker Desktop (ou Docker Engine + Docker Compose v2).
- Pentaho Data Integration 9.x (Spoon), com Java 11.
- Porta TCP `5433` livre (ou outra, ajustada em `.env`).

O driver JDBC do PostgreSQL já acompanha o PDI 9.x (`data-integration/lib/postgresql-*.jar`). Se o Spoon acusar `Driver class 'org.postgresql.Driver' could not be found`, copie o `.jar` do driver para essa pasta e reinicie o Spoon.

## Estrutura

```text
projeto/
├── .env.example                 # modelo das variáveis de conexão
├── compose.yaml                 # PostgreSQL 17
├── data/
│   ├── vdem_reduzido_pais_ano.csv            # fonte V-Dem país-ano
│   └── vdem_global_anual_1997_2024.csv       # referência para validar as médias anuais
├── db/init/                     # schema e carga da origem One Piece (automáticos)
└── pentaho/
    ├── jobs/job_etl_principal.kjb            # job principal (executar este)
    └── transformations/*.ktr                 # 6 transformações chamadas pelo job
```

## 1. Configurar as variáveis

Na pasta do projeto:

```bash
cp .env.example .env
```

Opcionalmente, edite `.env` para trocar a senha ou a porta. Os arquivos do Pentaho não guardam credenciais: eles leem `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`, `POSTGRES_USER` e `POSTGRES_PASSWORD` desse arquivo.

## 2. Subir o banco de dados

```bash
docker compose up -d
docker compose ps
```

Aguarde até o serviço `postgres` aparecer como `healthy`. Na primeira inicialização, o container cria os schemas `oltp`, `staging` e `dw` e carrega a origem One Piece (11 sagas e 32 arcos). As tabelas de staging e do DW começam vazias.

## 3. Executar o ETL no Spoon

1. Abra o Spoon.
2. Menu **File → Open** e selecione `pentaho/jobs/job_etl_principal.kjb`. Abra como arquivo local, não por repositório, pois os caminhos do `.env` e dos CSVs são relativos à localização do job.
3. Clique em **Run** (ou `F9`) e confirme em **Run** na janela seguinte. Não é necessário preencher parâmetros.

O job executa, em sequência:

| Etapa | O que faz |
|---|---|
| `00 Carregar .env` | Lê as variáveis de conexão do `.env` na raiz do projeto |
| `01 Validar OLTP` | Confere a origem: 11 sagas, 32 arcos, 1125 capítulos |
| `02`–`04` | Carrega `dw.dim_tempo`, `dw.dim_saga` e `dw.dim_arco` |
| `05 Validar dimensoes` | Confere 28 anos, 11 sagas e 32 arcos |
| `06 VDEM_ANUAL` | Agrega o CSV país-ano em 28 médias anuais (`staging.stg_vdem_anual`) e compara com `vdem_global_anual_1997_2024.csv` |
| `07 Validar VDEM anual` | Confere as 28 médias e as inversões dos indicadores |
| `08 VDEM_ARCO` | Calcula a média V-Dem do período de cada arco (`staging.stg_vdem_arco`) |
| `09`–`10` | Validam as médias por arco e as entradas da fato |
| `11 FATO_SOCIOPOLITICA` | Carrega `dw.fato_sociopolitica_arco` (32 linhas) |
| `12 Validar DW final` | Confere o DW completo |

A execução termina em `SUCCESS`. Qualquer falha desvia para `ABORT - falha no ETL`, e a aba **Logging** mostra a mensagem da etapa que falhou. Cada validação registra uma mensagem `OK ...` no log, por exemplo `OK STAGING ANUAL: 28 anos e 13 campos validos.`

O job pode ser executado várias vezes: as cargas usam *Insert/Update* pela chave natural e não geram duplicatas.

### Alternativa: linha de comando

```bash
<pasta-do-pdi>/kitchen.sh -file="$(pwd)/pentaho/jobs/job_etl_principal.kjb" -level=Basic
```

(No Windows, use `Kitchen.bat` com `/file:` apontando para o mesmo `.kjb`.)

## 4. Conferir o resultado

```bash
docker compose exec postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "
SELECT (SELECT count(*) FROM dw.dim_tempo)              AS dim_tempo,
       (SELECT count(*) FROM dw.dim_saga)               AS dim_saga,
       (SELECT count(*) FROM dw.dim_arco)               AS dim_arco,
       (SELECT count(*) FROM staging.stg_vdem_anual)    AS stg_anual,
       (SELECT count(*) FROM staging.stg_vdem_arco)     AS stg_arco,
       (SELECT count(*) FROM dw.fato_sociopolitica_arco) AS fato;"'
```

Resultado esperado: `28 | 11 | 32 | 28 | 32 | 32`.

## Executar uma transformação isoladamente (opcional)

Depois que o job roda uma vez, as variáveis de conexão ficam definidas na sessão do Spoon, e qualquer `.ktr` de `pentaho/transformations/` pode ser aberto e executado sozinho. Para executar um `.ktr` em uma sessão nova sem rodar o job antes, adicione as mesmas variáveis do `.env` em `~/.kettle/kettle.properties` e reinicie o Spoon.

## Recomeçar do zero

```bash
docker compose down -v
docker compose up -d
```

O `-v` apaga o volume do banco. Na próxima inicialização, o container recria os schemas e recarrega a origem One Piece, deixando staging e DW vazios para uma nova execução do job.

## Problemas comuns

- **`Connection refused`:** o container ainda não está `healthy`, ou a porta definida em `POSTGRES_PORT` está ocupada.
- **`00 Carregar .env` falha:** o arquivo `.env` não existe na raiz do projeto (repita o passo 1).
- **`10 Abortar se divergente` em `tr_vdem_anual`:** as médias calculadas não conferem com `vdem_global_anual_1997_2024.csv`. A linha divergente aparece no log.
