# Statefulset TLS PLayground

TBA...short detail is this is a python app and k8s config for
deploying a stateful app that provides a simple echo service over tcp
with tls.

## Pre-reqs
- Docker
- k3d (for local k3s orchestration)

> This was developed and tested all on a Debian 12 host. YMMV.

## Deploying

1. Build images, spin up k3s, and push images.

```
$ make build    # build the docker image
$ ./k3d.sh      # spin up the k3s cluster
$ make push     # deploy the app image
```

2. Deploy the k8s services.
> You may need to wait a bit for k3s to be ready.
```
$ kubectl apply -f 00-cert-manager.yaml   # install cert-manager
$ kubectl apply -f 01-cert-issuers.yaml   # deploy issuers
$ kubectl apply -f 02-statefulset.yaml    # deploy the application
$ kubectl apply -f 03-traefik.yaml        # deploy the sni router
```

3. Make sure it's running.

```
$ kubectl get statefulset -n echo echo
```

4. Use the provided Docker image to test connectivity.

> Why this image? It ships a modified `/etc/hosts` to make connections
> to both echo instances resolve to the local k3s docker network.

```
$ make run-client
```

You should end up in a Docker instance *outside* the k3s cluster.

```
docker run --rm -it --network k3d-sni-test sclient:latest
Updating /etc/hosts:
192.168.48.6 echo-0.echo-svc.echo.svc.cluster.local
192.168.48.6 echo-1.echo-svc.echo.svc.cluster.local
192.168.48.6 echo-svc.echo.svc.cluster.local

-----------------------------------------------------------------
You can now connect to one of the statefulset pods using openssl.

For example, to force connection to echo-1:

# openssl s_client -servername echo-1.echo-svc.echo.svc.cluster.local echo-svc.echo.svc.cluster.local:30088

TODO: pull in the self-signed root CA for verification

/ #
```

The "echo" application should greet each connection with its FQDN and
then just echo back any lines you send it.

## And now with Redpanda!

1. Spin up a Redpanda 3-node cluster using the provided shell script.

```
$ ./rp-go.sh
# you'll see a bunch of output...eventually...
# ...
>> Waiting for rollout...
Waiting for 3 pods to be ready...
Waiting for 2 pods to be ready...
Waiting for 1 pods to be ready...
statefulset rolling update complete 3 pods at revision redpanda-5b7c5db958...
> Checking if topic  exists...
NAME      PARTITIONS  REPLICAS
_schemas  1           3
> Fetching copy of root CA...
```

You'll now have a local copy of the root certificate as
`redpanda-ca.crt`.

2. Update your `/etc/hosts` to contain the Redpanda brokers exposed
   via the NodePort that sends traffic to the traefik ingress:

```
# echo "
127.0.0.1  redpanda-0.redpanda.redpanda.svc.cluster.local
127.0.0.1  redpanda-1.redpanda.redpanda.svc.cluster.local
127.0.0.1  redpanda-2.redpanda.redpanda.svc.cluster.local
" >> /etc/hosts
```

3. List topics using a **local** copy of `rpk`.

```
$ rpk topic list \
    --brokers redpanda-0.redpanda.redpanda.svc.cluster.local:9093 \
    --tls-enabled --tls-truststore redpanda-ca.crt
NAME      PARTITIONS  REPLICAS
_schemas  1           3
```

4. Create a topic with no replication and a single partition.

```
$ rpk topic create solo -r 1 \
    --brokers redpanda-0.redpanda.redpanda.svc.cluster.local:9093 \
    --tls-enabled --tls-truststore redpanda-ca.crt
TOPIC  STATUS
solo   OK
```

5. Find which broker hosts the `solo` topic.

```
$ rpk topic list --detailed \
    --brokers redpanda-0.redpanda.redpanda.svc.cluster.local:9093 \
    --tls-enabled --tls-truststore redpanda-ca.crt
_schemas, 1 partitions, 3 replicas
      PARTITION  LEADER  EPOCH  REPLICAS
      0          0       2      [0 1 2]

solo, 1 partitions, 1 replicas
      PARTITION  LEADER  EPOCH  REPLICAS
      0          1       1      [1]
```

In the above example, it's on node 1. Let's show we can produce and
consume to it which providing just the `redpanda-0` broker as the
discovery broker.

6. Produce a simple message.

```
$ echo "SNI is Fun" | rpk topic produce solo \
    --brokers redpanda-0.redpanda.redpanda.svc.cluster.local.:9093 \
    --tls-enabled --tls-truststore redpanda-ca.crt
Produced to partition 0 at offset 0 with timestamp 1692044323438.
```

7. Consume a message using the other node as the broker seed (in this
   case, `redpanda-2`).

```
$ rpk topic consume solo --num 1 \
    --brokers redpanda-2.redpanda.redpanda.svc.cluster.local.:9093 \
    --tls-enabled --tls-truststore redpanda-ca.crt
{
  "topic": "solo",
  "value": "SNI is Fun",
  "timestamp": 1692044323438,
  "partition": 0,
  "offset": 0
}
```

Still don't believe it after reading the above? Here's the consuming
again but with verbose mode enabled in rpk:

```
$ rpk topic consume solo -v --num 1 --brokers redpanda-2.redpanda.redpanda.svc.cluster.local.:9093 --tls-enabled --tls-truststore redpanda-ca.crt
16:23:30.800 [INFO] immediate metadata update triggered; why: querying metadata for consumer initialization
16:23:30.800 [DEBUG] opening connection to broker; addr: redpanda-2.redpanda.redpanda.svc.cluster.local.:9093, broker: seed 0
16:23:30.806 [DEBUG] connection opened to broker; addr: redpanda-2.redpanda.redpanda.svc.cluster.local.:9093, broker: seed 0
16:23:30.806 [DEBUG] issuing api versions request; broker: seed 0, version: 3
16:23:30.806 [DEBUG] wrote ApiVersions v3; broker: seed 0, bytes_written: 31, write_wait: 78.084µs, time_to_write: 23.333µs, err: <nil>
16:23:30.806 [DEBUG] read ApiVersions v3; broker: seed 0, bytes_read: 296, read_wait: 74.542µs, time_to_read: 664.003µs, err: <nil>
16:23:30.807 [DEBUG] connection initialized successfully; addr: redpanda-2.redpanda.redpanda.svc.cluster.local.:9093, broker: seed 0
16:23:30.807 [DEBUG] wrote Metadata v7; broker: seed 0, bytes_written: 28, write_wait: 6.642153ms, time_to_write: 30.5µs, err: <nil>
16:23:30.807 [DEBUG] read Metadata v7; broker: seed 0, bytes_read: 295, read_wait: 31.208µs, time_to_read: 753.629µs, err: <nil>
16:23:30.808 [INFO] assigning partitions; why: new assignments from direct consumer, how: assigning everything new, keeping current assignment, input: solo[0{-2 e-1 ce0}]
16:23:30.808 [DEBUG] assign requires loading offsets
16:23:30.808 [DEBUG] offsets to load broker; broker: 1, load: {map[solo:map[0:{-2 e-1 ce1}]] map[]}
16:23:30.808 [DEBUG] opening connection to broker; addr: redpanda-1.redpanda.redpanda.svc.cluster.local.:9093, broker: 1
16:23:30.811 [DEBUG] connection opened to broker; addr: redpanda-1.redpanda.redpanda.svc.cluster.local.:9093, broker: 1
16:23:30.811 [DEBUG] issuing api versions request; broker: 1, version: 3
16:23:30.811 [DEBUG] wrote ApiVersions v3; broker: 1, bytes_written: 31, write_wait: 35.75µs, time_to_write: 30.417µs, err: <nil>
16:23:30.812 [DEBUG] read ApiVersions v3; broker: 1, bytes_read: 296, read_wait: 20.75µs, time_to_read: 598.419µs, err: <nil>
16:23:30.812 [DEBUG] connection initialized successfully; addr: redpanda-1.redpanda.redpanda.svc.cluster.local.:9093, broker: 1
16:23:30.812 [DEBUG] wrote ListOffsets v4; broker: 1, bytes_written: 52, write_wait: 4.208267ms, time_to_write: 37.875µs, err: <nil>
16:23:30.813 [DEBUG] read ListOffsets v4; broker: 1, bytes_read: 52, read_wait: 34.667µs, time_to_read: 365.335µs, err: <nil>
16:23:30.813 [DEBUG] handled list results; broker: 1, using: map[solo:map[0:{0 1}]], reloading: map[]
16:23:30.813 [DEBUG] opening connection to broker; addr: redpanda-1.redpanda.redpanda.svc.cluster.local.:9093, broker: 1
16:23:30.815 [DEBUG] connection opened to broker; addr: redpanda-1.redpanda.redpanda.svc.cluster.local.:9093, broker: 1
16:23:30.815 [DEBUG] connection initialized successfully; addr: redpanda-1.redpanda.redpanda.svc.cluster.local.:9093, broker: 1
16:23:30.815 [DEBUG] wrote Fetch v11; broker: 1, bytes_written: 90, write_wait: 2.232384ms, time_to_write: 8.25µs, err: <nil>
16:23:30.815 [DEBUG] read Fetch v11; broker: 1, bytes_read: 152, read_wait: 26.208µs, time_to_read: 503.294µs, err: <nil>
{
  "topic": "solo",
  "value": "SNI is Fun",
  "timestamp": 1692044323438,
  "partition": 0,
  "offset": 0
}
```

## Exercises left for the Reader

Now go expose the Admin API 😉
