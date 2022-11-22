# KikiRara

Use ksqlDB to bring realtime data to your project.


## Batch/Realtime architecures

We only focus on the differences between the batch architecture and the realtime architecture, we will not cover any topics like Lambda architecture, Kappa architecture.

- Batch based architecture
  ```
  Data -> Kafka -> Offline DB -> Batch/ETL    -> Online DB -> Web app
                  |---------- minutes/hours------------|
  ```

- Realtime based architecure
  ```
  Data -> Kafka -> Stream Processing -> Kafka -> Online DB -> Web app
                  |---------- milliseconds/seconds-----|
  ```

## ksqlDB vs "DB"

A lot of new Database technologies, this table will highlight the key differences between ksqlDB and online/offline databases. This may not apply to some NoSQL, New SQL, HTAP databases.

| Diffs              | ksqlDB               | Online DB                 | Offline DB                |
| ------------------ | -------------------- | ------------------------- | ------------------------- |
| Input              | Kafka                | Insert/Bulk load          | Insert/Bulk load          |
| Output             | Kafka                | Instant response          | Table or Instant response |
| Storage            | Kafka, RocksDB       | Data format on local disk | Avro, ORC, Parquet        |
| Index              | Not needed           | Highly depends on Index   | Not really use Index      |
| Trigger            | Realtime             | Online request            | Batch job                 |
| Scalability        | High                 | Low                       | Mid/High                  |
| Data scale         | Millions/**Second**  | Millions/Table            | Billions/Table            |
| Data latency       | Milliseconds         | Milliseconds              | Minutes                   |
| Query: Select      | Key, Range           | All                       | All                       |
| Query: Aggregation | Realtime agg         | -                         | Batched agg               |
| Query: Transaction | -                    | Yes                       | -                         |
| Query: Join        | Limited/co-partition | Yes (Not recommend)       | Yes                       |

## Demo Data
- https://digitransit.fi/en/developers/apis/4-realtime-api/vehicle-positions/


## Prerequisite
```
# install connector plugins
mkdir -p confluent-hub-components
confluent-hub install confluentinc/kafka-connect-mqtt:latest --component-dir confluent-hub-components
confluent-hub install confluentinc/kafka-connect-jdbc:10.6.0 --component-dir confluent-hub-components
confluent-hub install jcustenborder/kafka-connect-redis:0.0.4 --component-dir confluent-hub-components

# create source topic and license topic
kafka-topics --bootstrap-server broker:9092 --create --topic _confluent-command --partitions 3 --replication-factor 1
kafka-topics --bootstrap-server broker:9092 --create --topic bus_raw --partitions 3 --replication-factor 1
```

## Demo
- 1. Source data into Kafka
    ```
    # create mqtt source connector
    curl -X POST http://localhost:8083/connectors \
      -H 'Content-Type: application/json' \
      -H 'Accept: application/json' \
      --data "@./connectors/mqtt-source.json" | jq

    # show connector status
    curl -X GET http://localhost:8083/connectors/mqtt-source/status | jq
    ```
- 2. Create stream in ksqlDB
    ```
    docker exec -it ksqldb-cli ksql http://ksqldb-server:8088 -f /ksqldb/create_stream.sql
    ```
- 3. Create table in ksqlDB to calculate latest position.
    ```
    docker exec -it ksqldb-cli ksql http://ksqldb-server:8088 -f /ksqldb/create_table_bus_current.sql
    ```
- 4. Sink connector.
    ```
    # create recis sink connector
      curl -X POST http://localhost:8083/connectors \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json' \
        --data "@./connectors/redis-sink.json" | jq

    # show connector status
    curl -X GET http://localhost:8083/connectors/redis-sink/status | jq
    ```
- 5. API demo (2 versions)
    ```
    cd web_api
    
    # start fast API server.
    python api.py

    # Redis version
    curl -X GET http://localhost:8000/curr
    # ksqlDB version
    curl -X GET http://localhost:8000/curr2
    ```
- 6. ksqlDB push query
    ```
    curl -X "POST" "http://ksqldb-server:8088/query-stream" \
        -d $'{
      "sql": "SELECT * FROM bus_current EMIT CHANGES;",
      "streamsProperties": {}
    }'
    ```
- 7. Finish

## References:
- [Confluent Course: KSQLDB 101](https://developer.confluent.io/learn-kafka/ksqldb/intro/)