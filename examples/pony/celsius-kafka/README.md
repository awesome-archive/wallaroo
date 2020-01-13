# Celsius-kafka

This is an example of a stateless application that takes a floating point Celsius value from Kafka and sends out a floating point Fahrenheit value to Kafka.

## Prerequisites

- ponyc
- pony-stable
- Wallaroo

See [Wallaroo Environment Setup Instructions](https://docs.wallaroolabs.com/pony-installation/).

## Building

Build Celsius-kafka with

```bash
make
```

## Celsius-kafka argument

In a shell, run the following to get help on arguments to the application:

```bash
./celsius-kafka --help
```

## Running Celsius-kafka

### Shell 1: Metrics

Start up the Metrics UI if you don't already have it running.

```bash
metrics_reporter_ui start
```

You can verify it started up correctly by visiting [http://localhost:4000](http://localhost:4000).

If you need to restart the UI, run the following.

```bash
metrics_reporter_ui restart
```

When it's time to stop the UI, run the following.

```bash
metrics_reporter_ui stop
```

If you need to start the UI after stopping it, run the following.

```bash
metrics_reporter_ui start
```

### Shell 2: Kafka setup and listener

#### Start Kafka and create the `test-in` and `test-out` topics

You need Kafka running for this example. Ideally you should go to the Kafka website (https://kafka.apache.org/) to properly configure Kafka for your system and needs. However, the following is a quick/easy way to get Kafka running for this example:

This requires `docker-compose`:

Ubuntu:

```bash
sudo curl -L https://github.com/docker/compose/releases/download/1.15.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

MacOS: Docker compose is already included as part of Docker for Mac.


**NOTE:** You might need to run with sudo depending on how you set up Docker.

Clone local-kafka-cluster project and run it:

```bash
cd /tmp
git clone https://github.com/effata/local-kafka-cluster
cd local-kafka-cluster
./cluster up 1 # change 1 to however many brokers are desired to be started
sleep 1 # allow kafka to start
docker exec -i local_kafka_1_1 /kafka/bin/kafka-topics.sh --zookeeper \
  zookeeper:2181 --create --partitions 4 --topic test-in --replication-factor \
  1 # to create a test-in topic; change arguments as desired
docker exec -i local_kafka_1_1 /kafka/bin/kafka-topics.sh --zookeeper \
  zookeeper:2181 --create --partitions 4 --topic test-out --replication-factor \
  1 # to create a test-out topic; change arguments as desired
```

**Note:** The `./cluster up 1` command outputs `Host IP used for Kafka Brokers is <YOUR_HOST_IP>`.

#### Set up a listener to monitor the Kafka topic the application will publish results to. We usually use `kafkacat`.

`kafkacat` can be installed via:

```bash
docker pull ryane/kafkacat
```

##### Run `kafkacat` from Docker

Set the Kafka broker IP address:

**NOTE:** If you're running Wallaroo in Docker, you will need to replace the following with `export KAFKA_UP=*IP OUTPUT BY ./cluster up 1 COMMAND*` instead.

```bash
export KAFKA_IP=$(docker inspect local_kafka_1_1 | grep kafka_ip | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
```

To run `kafkacat` to listen to the `test-out` topic via Docker:

```bash
docker run --rm -i --name kafkacatconsumer ryane/kafkacat -C -b ${KAFKA_IP}:9092 -t test-out -q -u
```

### Shell 3: Celsius-kafka

Set the Kafka broker IP address:

**NOTE:** If you're running Wallaroo in Docker, you will need to replace the following with `export KAFKA_UP=*IP OUTPUT BY ./cluster up 1 COMMAND*` instead.

```bash
export KAFKA_IP=$(docker inspect local_kafka_1_1 | grep kafka_ip | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
```

Run `celsius-kafka`:

```bash
./celsius-kafka \
  --kafka_source_topic test-in --kafka_source_brokers ${KAFKA_IP}:9092 \
  --kafka_sink_topic test-out --kafka_sink_brokers ${KAFKA_IP}:9092 \
  --kafka_sink_max_message_size 100000 --kafka_sink_max_produce_buffer_ms 10 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:12500 --data 127.0.0.1:12501 \
  --external 127.0.0.1:5050 --cluster-initializer --ponythreads=1 \
  --ponynoblock
```

`kafka_sink_max_message_size` controls maximum size of message sent to Kafka in a single produce request. Kafka will return errors if this is bigger than server is configured to accept.

`kafka_sink_max_produce_buffer_ms` controls maximum time (in ms) to buffer messages before sending to Kafka. Either don't specify it or set it to `0` to disable batching on produce.

### Shell 4: Sender

Send data into Kafka. Again, we use `kafakcat`.

Set the Kafka broker IP address:

**NOTE:** If you're running Wallaroo in Docker, you will need to replace the following with `export KAFKA_UP=*IP OUTPUT BY ./cluster up 1 COMMAND*` instead.

```bash
export KAFKA_IP=$(docker inspect local_kafka_1_1 | grep kafka_ip | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
```

Run the following to send the numbers 1 - 100 as celsius temperatures:

```bash
seq 1 100 | docker run --rm -i --name kafkacatproducer ryane/kafkacat -P -b ${KAFKA_IP}:9092 -t test-in
```

## Shell 5: Shutdown

You can shut down the Wallaroo cluster with this command:

```bash
cluster_shutdown 127.0.0.1:5050
```

You can shut down the kafkacat consumer by pressing Ctrl-c from its shell.

### Stop Kafka

NOTE: You might need to run with sudo depending on how you set up Docker.

If you followed the commands earlier to start Kafka you can stop it by running:

```bash
cd /tmp/local-kafka-cluster
./cluster down # shut down cluster
```

You can shut down the Metrics UI with the following command.

```bash
metrics_reporter_ui stop
```
