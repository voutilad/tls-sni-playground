# Statefulset TLS PLayground

TBA...short detail is this is a python app and k8s config for
deploying a stateful app that provides a simple echo service over tcp
with tls.

## Pre-reqs
- Docker
- k3d

## Deploying

Spin up the k3s environment...

```
$ make build    # build the docker image
$ ./k3d.sh      # spin up the k3s cluster
$ make push     # deploy the app image
```

Deploy the app...

```
$ kubectl apply -f 00-cert-manager.yaml   # install cert-manager
$ kubectl apply -f 01-cert-issuers.yaml   # deploy issuers
$ kubectl apply -f 02-statefulset.yaml    # deploy the application
```

Make sure it's running...

```
$ kubectl get statefulset echo
```
