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
```

3. Make sure it's running.

```
$ kubectl get statefulset echo
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
192.168.48.5 echo-0.echo-svc.default.svc.cluster.local
192.168.48.5 echo-1.echo-svc.default.svc.cluster.local

-----------------------------------------------------------------
You can now connect to one of the statefulset pods using openssl:

# openssl s_client echo-1.echo-svc.default.svc.cluster.local:30088

TODO: pull in the self-signed root CA for verification

/ #
```
