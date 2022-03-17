
# Using QuestDB as a datasource for MindsDB

## Introduction

MindsDB enables you to use ML to ask predictive questions in SQL about your data, and receive accurate 
answers from it. Developers can quickly add AI capabilities to applications. Data Scientists can 
streamline MLOps by deploying ML models as AI Tables. Data Analysts can easily make forecasts on complex 
data, such as multivariate time-series with high cardinality, and visualize these in BI tools like 
Grafana, or Tableau.
 
QuestDB is the best open-source, column-oriented SQL database for time-series type data. It has been 
designed from the ground up as the de facto backend for high-performance (massively-parallelized vectorized 
execution, SIMD) demanding applications in financial services, IoT, IIoT, ML, DevOps and observability. It 
implements ANSI SQL with additional extensions for time-specific queries, which make it simple to correlate 
data from multiple sources using relational and time series joins, and execute aggregation functions with
simplicity and speed. 

Combining both, your prediction ability is unbound, and the only language you need is SQL. You can perform 
all the pre-processing of your data inside QuestDB, using its powerful and unique SQL, and then you can 
access these data from MindsDB to produce powerful ML models.

The main goal of this article is to gently introduce these two deep technologies, and give you enough 
understanding to be able to undertake very ambitious ML projects. To that end we will hands-on:

- Build a Docker image of **MindsDB** that is compatible with using **QuestDB** as a datasource.
- Spawn two Docker containers to run **MindsDB** and **QuestDB**.
- Add **QuestDB** as a datasource to **MindsDB** through its web UI.
- Create a table, and add data for a simple ML use case, using **QuestDB**'s web UI.
- Connect to **MindsDB** through the `mysql` client and write some SQL.
- Create a predictor for our ML use case.
- Make some predictions about our data.

Have fun!

## Requirements

- [Docker](https://docs.docker.com/get-docker/): To build MindsDB's image. 
- [docker-compose](https://docs.docker.com/compose/install/): To define and run our multi-container 
  Docker application. It is usually installed implicitly when Docker is installed.
- [MySQL](https://formulae.brew.sh/formula/mysql): To interact with QuestDB and MindsDB
  (`mysql -h 127.0.0.1 --port 47335 -u mindsdb -p`).
- [Make](https://www.gnu.org/software/make/): Our CLI to build/run/stop Docker images/containers:
  - `make build-mindsdb-image`: Uses the Dockerfile file to build MindsDB's image `mindsdb/mindsdb:questdb_tutorial`.
  - `make compose-up`: Starts the containers of multi-container application, `questdb` and `mindsdb`.
  - `make compose-down`: Stops/Prunes the containers and their volumes. 
    
     Note: we use external folders to make MindsDB and QuestDB's data persistent across compose-{up | down}.    

## Build Mindsdb image

**Usually**:

1. Clone **MindsDB**'s repo `git clone git@github.com:mindsdb/mindsdb.git`.
2. Create a `venv` environment `python3 -venv venv` .
3. Activate the environment `source venv/bin/activate`.
4. Upgrade pip in the `venv` environment with `pip install -U pip`.
5. Install MindsDB's requirements `pip install -r requirements.txt` 
6. Install Mindsdb itself `pip install -e .` 
7. This would allow you to run Mindsdb as a module

`python -m mindsdb --config=<actual path to>/mindsdb_config.json --api=http,mysql,mongodb`

**However**, if you work on a Mac M1, the above might break down.

**Instead** simply build a MindsDB image locally with command:

```bash
make build-mindsdb-image
```

this takes some time, and results in a new image called:

```bash
$ docker images
REPOSITORY        TAG                IMAGE ID       CREATED          SIZE
mindsdb/mindsdb   questdb_tutorial   38f294a5804b   14 minutes ago   8.91GB
```

The **Dockerfile** file contains an explicit `pip install` for the PostgreSQL type of datasource.
This allows us to add and interact with QuestDB as a datasource:

```dockerfile
RUN python -m pip install --prefer-binary --no-cache-dir --upgrade pip==22.0.4 && \
    pip install --prefer-binary --no-cache-dir wheel==0.37.1 && \
    pip install --prefer-binary --no-cache-dir mindsdb==$MINDSDB_VERSION && \
    pip install --prefer-binary --no-cache-dir mindsdb-datasources[postgresql] <--- THIS, QuestDB speaks postgres-wire-protocol
```

## Running our multi-container Docker application

We have a **docker-compose.yaml** file:

```yaml
version: '3.8'

services:
  questdb:
    image: questdb/questdb:latest
    container_name: questdb
    pull_policy: "always"
    restart: "always"
    ports:
      - "8812:8812"
      - "9000:9000"
      - "9009:9009"
    volumes:
      - ./qdb_root:/root/.questdb

  mindsdb:
    image: mindsdb/mindsdb:questdb_tutorial
    container_name: mindsdb
    restart: "always"
    ports:
      - "47334:47334"
      - "47335:47335"
      - "47336:47336"
      - "8000:8000"
    volumes:
      - .:/root
    depends_on:
      - questdb

networks:
  default:
    name: mindsdb-network
    driver: bridge
```

Which allows us to start our two services with command:

```bash
make compose-up
```

- [questdb](https://github.com/questdb/questdb): Creates a folder **qdb_root** to store
  table data/metadata, server configuration, and the UI interface => available at [localhost:9000](http://localhost:9000).
- [mindsdb](https://github.com/mindsdb/mindsdb): Creates two folders **mindsdb_store**, **nltk_data**, uses 
  the configuration file **mindsdb_config.json** => available at [localhost:47334](http://localhost:47334). 
  
MindsDB takes about 60-90 seconds to become available, logs can be followed in the terminal:

```bash
docker logs -f mindsdb
...
Version 22.3.1.0
Configuration file:
   /root/mindsdb_config.json
Storage path:
   /root/mindsdb_store
http API: starting...
mysql API: starting...
mongodb API: starting...
 ✓ telemetry enabled
 ✓ telemetry enabled
 ✓ telemetry enabled
mongodb API: started on 47336
mysql API: started on 47335
http API: started on 47334
```

We can stop the two containers with command:

```bash
make compose-down
```

## Adding QuestDB as a datasource

We can add QuestDB as a datasource to MindsDB by:

1. Browsing to MindsDB dashboard at [localhost:47334](http://localhost:47334)
2. Clicking on the green button labelled **ADD DATABASE**, which will prompt 
   a dialog asking for QuestDB's connection attributes, use these verbatim:

   | Attr. Name           | Attr. Value          |
   |----------------------| -------------------- |
   | Name Your Connection | questdb              |
   | Supported Databases  | PostgreSQL           |
   | Database Name        | questdb              |
   | Host                 | questdb              |
   | Port                 | 8812                 |
   | Username             | admin                |
   | Password             | quest                |

   Note: Host is `questdb`, the name of QuestDB's container, which
   runs along `mindsdb` on the same bridge network `mindsdb-network`.

We can achieve the same by connecting to MindsDB (ref. [Connecting to MindsDB](#connecting-to-mindsdb)) and executing:

```sql
USE mindsdb;

CREATE DATASOURCE questdb
    WITH ENGINE = "postgres",
    PARAMETERS = {
        "user": "admin",
        "password": "quest",
        "host": "questdb",
        "port": "8812",
        "database": "questdb",
        "public": true
    };
```

Note: in this case the web UI will not assign it a `Name Your Connection`.

## Adding data to QuestDB

We can access QuestDB's web console at [localhost:9000](http://localhost:9000) 
and execute this DDL query to create a simple table:

```sql
CREATE TABLE IF NOT EXISTS house_rentals_data (
    number_of_rooms int,
    number_of_bathrooms int,
    sqft int,
    location symbol,
    neighborhood symbol,
    days_on_market int,
    rental_price float,
    ts timestamp
) timestamp(ts) PARTITION BY YEAR;
```

Then we can populate it with random data:

```sql
INSERT INTO house_rentals_data SELECT * FROM (
    SELECT 
        rnd_int(1,6,0),
        rnd_int(1,3,0),
        rnd_int(180,2000,0),
        rnd_symbol('meh', 'good', 'great', 'amazing'),
        rnd_symbol('uptown', 'downtown', 'west_end', 'east_end', 'north_side', 'south_side'),
        rnd_int(1,20,0),
        rnd_float(0) * 1000 + 500,
        timestamp_sequence(
            to_timestamp('2021-01-01', 'yyyy-MM-dd'),
            14400000000L
        )
    FROM long_sequence(100)
);
```
   
## Connecting to MindsDB

We can connect to MindsDB with a standard mysql-wire-protocol compliant client (no password, hit ENTER):

```bash
mysql -h 127.0.0.1 --port 47335 -u mindsdb -p
```

Only two databases are relevant to us, *mindsdb* and *questdb*:

    ```bash
    mysql> show databases;
    +--------------------+
    | Database           |
    +--------------------+
    | information_schema |
    | mindsdb            |
    | files              |
    | views              |
    | questdb            |
    +--------------------+
    5 rows in set (0.34 sec) 
    ```

- *questdb*: This is a view on our QuestDB instance added as
  a PostgreSQL datasource in section [Adding QuestDB as a datasource](#adding-questdb-as-a-datasource). 
  
  We can query it leveraging the full power of QuestDB's unique SQL syntax (SELECT queries only) 
  because statements are sent over to QuestDB through a python client library that uses the 
  postgres-wire-protocol and are not interpreted by MindsDB itself (MindsDB does not support
  QuestDB's syntax - To access it you first need to **USE questdb** first): 

    ```bash
    mysql> USE questdb;
    Database changed
  
    mysql>  SELECT
        ->     concat(month(ts), '-', year(ts)) When,
        ->     concat(neighborhood, '(', location, ')') Where,
        ->     sum(days_on_market) 'Days Live',
        ->     avg(rental_price) 'Avg Rent',
        ->     min(rental_price) 'Min Rent'
        -> FROM house_rentals_data
        -> SAMPLE BY 1M ALIGN TO CALENDAR;
    +---------+---------------------+-----------+--------------------+----------+
    | When    | Where               | Days Live | Avg Rent           | Min Rent |
    +---------+---------------------+-----------+--------------------+----------+
    | 1-2021  | east_end(great)     | 129       | 1173.8123596191406 | 789.848  |
    | 1-2021  | west_end(great)     | 116       | 901.5536376953125  | 543.647  |
    | 1-2021  | downtown(great)     | 64        | 1156.290815080915  | 748.697  |
    | 1-2021  | east_end(meh)       | 99        | 937.2772674560547  | 506.008  |
    | 1-2021  | downtown(good)      | 62        | 961.129411969866   | 669.647  |
    | 1-2021  | north_side(meh)     | 183       | 1017.69728742327   | 536.219  |
    
                                        ...
       
    | 5-2021  | east_end(great)     | 65        | 1009.2089059012277 | 639.166  |
    | 5-2021  | downtown(good)      | 109       | 916.1708346280185  | 500.828  |
    | 5-2021  | downtown(meh)       | 53        | 1149.3875610351563 | 692.153  |
    
                                        ...
       
    | 6-2021  | east_end(meh)       | 34        | 1338.6304016113281 | 1238.311 |
    | 6-2021  | north_side(good)    | 44        | 992.9532906668527  | 624.624  |
    | 7-2021  | uptown(great)       | 75        | 843.7895889282227  | 581.222  |
    | 7-2021  | downtown(meh)       | 106       | 1097.9656575520833 | 556.068  |
    | 7-2021  | south_size(amazing) | 145       | 1062.8103590745193 | 514.855  |
    
                                        ...
       
    | 11-2021 | south_size(good)    | 120       | 982.1712137858073  | 665.255  |
    | 11-2021 | south_size(amazing) | 70        | 998.2418619791666  | 701.557  |
    | 11-2021 | west_end(amazing)   | 66        | 1066.4378458658855 | 664.759  |
    +---------+---------------------+-----------+--------------------+----------+
    263 rows in set (0.41 sec)
    ```

- *mindsdb*: Contains the metadata tables necessary to create ML models and add new datasources:

    ```bash
    mysql> use mindsdb;
    Database changed
  
    mysql> show tables;
    +-------------------+
    | Tables_in_mindsdb |
    +-------------------+
    | predictors        |
  
           ...
  
    | datasources       |
    +-------------------+
    3 rows in set (0.17 sec)
  
    mysql> select * from datasources;
    +---------+---------------+---------+------+-------+
    | name    | database_type | host    | port | user  |
    +---------+---------------+---------+------+-------+
    | questdb | postgres      | questdb | 8812 | admin |
    +---------+---------------+---------+------+-------+
    1 row in set (0.19 sec)
    ```

## Creating a predictor

We can create a model, stored in table `mindsdb.home_rentals_model_ts`, to predict `predicted_rental_price` 
for the next 2 days considering the past 10 days:

```sql
USE mindsdb;

CREATE PREDICTOR home_rentals_model_ts FROM questdb (
    SELECT number_of_rooms, location, neighborhood, days_on_market, rental_price, ts
    FROM house_rentals_data
)
PREDICT rental_price as predicted_rental_price
ORDER BY ts
WINDOW 10 HORIZON 2;
```

This triggers MindsDB to create/train the model based on the full data available from QuestDB's table 
`house_rentals_data` (100 rows) as a timeseries on column `ts`, with a history of 10 rows to predict 
the next 2.

You can see the progress by monitoring the log output of the `mindsdb` Docker container, and you can
ask MindsDB directly:

```bash
mysql> select * from predictors;
+-----------------------+------------+----------+--------------+---------------+-----------------+-------+-------------------+------------------+
| name                  | status     | accuracy | predict      | update_status | mindsdb_version | error | select_data_query | training_options |
+-----------------------+------------+----------+--------------+---------------+-----------------+-------+-------------------+------------------+
| home_rentals_model_ts | generating | NULL     | rental_price | up_to_date    | 22.3.1.0        | NULL  |                   |                  |
+-----------------------+------------+----------+--------------+---------------+-----------------+-------+-------------------+------------------+
1 row in set (0.34 sec)

mysql> select * from predictors;
+-----------------------+----------+----------+--------------+---------------+-----------------+-------+-------------------+------------------+
| name                  | status   | accuracy | predict      | update_status | mindsdb_version | error | select_data_query | training_options |
+-----------------------+----------+----------+--------------+---------------+-----------------+-------+-------------------+------------------+
| home_rentals_model_ts | training | NULL     | rental_price | up_to_date    | 22.3.1.0        | NULL  |                   |                  |
+-----------------------+----------+----------+--------------+---------------+-----------------+-------+-------------------+------------------+
1 row in set (0.28 sec)

mysql> select * from predictors;
+-----------------------+----------+--------------------+--------------+---------------+-----------------+-------+-------------------+------------------+
| name                  | status   | accuracy           | predict      | update_status | mindsdb_version | error | select_data_query | training_options |
+-----------------------+----------+--------------------+--------------+---------------+-----------------+-------+-------------------+------------------+
| home_rentals_model_ts | complete | 1.3742857938858857 | rental_price | up_to_date    | 22.3.1.0        | NULL  |                   |                  |
+-----------------------+----------+--------------------+--------------+---------------+-----------------+-------+-------------------+------------------+
1 row in set (0.18 sec)
```

When status is **complete** the model is ready for use, until then, simply wait while you observe `mindsdb`'s 
logs, and repeat the query periodically. Creating/training a model will take time proportional to the number of features, 
i.e.cardinality of the source table as defined in the inner SELECT of the CREATE PREDICTOR statement, and the 
size of the corpus, i.e. number of rows.


## Querying MindsDB for predictions

TO BE CONTINUED ...

## MindsDB http api

MindsDB exposes a REST api, with swagger available at [http://localhost:47334/doc/](http://localhost:47334/doc/).

