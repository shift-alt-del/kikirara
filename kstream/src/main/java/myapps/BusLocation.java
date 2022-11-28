package myapps;

import io.confluent.common.utils.TestUtils;
import io.confluent.kafka.serializers.KafkaAvroDeserializerConfig;
import io.confluent.kafka.streams.serdes.avro.GenericAvroSerde;
import org.apache.avro.generic.GenericData;
import org.apache.avro.generic.GenericRecord;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.common.serialization.Serde;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.*;
import org.apache.kafka.streams.kstream.*;
import org.apache.kafka.streams.state.Stores;

import java.time.Duration;
import java.util.*;

public class BusLocation {

    public static void main(final String[] args) {

        final Properties props = getStreamsConfiguration();

        final StreamsBuilder builder = createStream();
        final Topology topology = builder.build();
        System.out.println(topology.describe());

        final KafkaStreams streams = new KafkaStreams(topology, props);

        streams.setStateListener((newState, oldState) -> {
            if (newState == KafkaStreams.State.RUNNING) {
                System.out.println("***********");
                for (ThreadMetadata tmd : streams.metadataForLocalThreads()) {
                    System.out.println("Thread "
                            + tmd.threadName()
                            + " active "
                            + Arrays.toString(tmd.activeTasks().stream()
                            .map(val -> val.taskId()).toArray())
                            + " standby "
                            + Arrays.toString(tmd.standbyTasks().stream()
                            .map(val -> val.taskId()).toArray()));
                }
            }
        });

        streams.cleanUp();
        streams.start();

        Runtime.getRuntime().addShutdownHook(new Thread(streams::close));
    }

    static Properties getStreamsConfiguration() {
        final Properties streamsConfiguration = new Properties();
        streamsConfiguration.put(StreamsConfig.APPLICATION_ID_CONFIG, "bus_location");
        streamsConfiguration.put(StreamsConfig.CLIENT_ID_CONFIG, "bus_location");
        streamsConfiguration.put(StreamsConfig.BOOTSTRAP_SERVERS_CONFIG, "broker:9092");
        streamsConfiguration.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG,
                Serdes.String().getClass().getName());
        streamsConfiguration.put(StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG,
                Serdes.String().getClass().getName());
        streamsConfiguration.put(StreamsConfig.COMMIT_INTERVAL_MS_CONFIG, 10 * 1000);
        streamsConfiguration.put(StreamsConfig.CACHE_MAX_BYTES_BUFFERING_CONFIG, 0);
        // streamsConfiguration.put(StreamsConfig.STATE_DIR_CONFIG,
        // TestUtils.tempDirectory().getAbsolutePath());
        streamsConfiguration.put(StreamsConfig.NUM_STREAM_THREADS_CONFIG, 2);
        streamsConfiguration.put(StreamsConfig.NUM_STANDBY_REPLICAS_CONFIG, 0);
        streamsConfiguration.put(KafkaAvroDeserializerConfig.SCHEMA_REGISTRY_URL_CONFIG,
                "http://schema-registry:8081");
        streamsConfiguration.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");

        return streamsConfiguration;
    }

    static StreamsBuilder createStream() {
        StreamsBuilder builder = new StreamsBuilder();
        // // When you want to override serdes explicitly/selectively
        // //
        // https://docs.confluent.io/platform/current/streams/developer-guide/datatypes.html
        final Map<String, String> serdeConfig = Collections.singletonMap(
                "schema.registry.url", "http://schema-registry:8081");

        final Serde<GenericRecord> valueSerde = new GenericAvroSerde();
        valueSerde.configure(serdeConfig, false); // `false` for record values

        // `bus_extracted` is from ksqldb
        builder.stream("bus_extracted",
                        Consumed.with(Serdes.String(), valueSerde))
                .filter((k, v) -> v.get("LAT") != null
                        && v.get("LONG") != null
                        && v.get("TIME_INT") != null)
                .groupByKey()
                .windowedBy(
                        TimeWindows.ofSizeAndGrace(
                                Duration.ofSeconds(5),
                                Duration.ofSeconds(1)))
                // tutorials -
                // https://developer.confluent.io/tutorials/window-final-result/kstreams.html
                .aggregate(
                        () -> null,
                        (vehId, curr, agg) -> {
                            return String.format(
                                    "%s|%s|%s",
                                    curr.get("LAT"),
                                    curr.get("LONG"),
                                    curr.get("TIME_INT"));
                        })
                .suppress(
                        Suppressed.untilTimeLimit(
                                Duration.ofSeconds(1),
                                Suppressed.BufferConfig.maxRecords(1000)))
                .toStream()
                .print(Printed.toSysOut());

        return builder;
    }
}