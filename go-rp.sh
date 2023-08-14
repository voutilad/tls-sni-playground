#!/bin/sh
set -e

### 0. Pre-requisites
for cmd in k3d helm kubectl; do
    if [ -z "$(which "${cmd}")" ]; then
        echo "!! Failed to find ${cmd} in path. Is it installed?"
        exit 1;
    else
        echo "> Using ${cmd} @ $(which ${cmd})"
    fi
done

### 1. Update Helm.
echo "> Updating Helm charts..."
helm repo add redpanda https://charts.redpanda.com > /dev/null
helm repo update > /dev/null

### 2. Install Redpanda (if needed)
echo "> Looking for Redpanda..."
if ! kubectl get service redpanda -n redpanda > /dev/null; then
    echo ">> Installing Redpanda broker cluster..."
    helm install redpanda redpanda/redpanda \
         --namespace redpanda \
         --create-namespace \
         --set external.domain=${DOMAIN} \
         --set statefulset.initContainers.setDataDirOwnership.enabled=true \
         --set resources.memory.container.max=1.5Gi \
         --set imemory.redpanda.memory=1Gi
    echo ">> Waiting for rollout..."
    kubectl -n redpanda rollout status statefulset redpanda --watch
fi

### 3. Bootstrap our Topic(s)
echo "> Checking if topic ${TOPIC} exists..."
if ! kubectl -n redpanda exec -it redpanda-0 -c redpanda -- \
     rpk topic list \
     --brokers redpanda.redpanda.svc.cluster.local.:9093 \
     --tls-truststore /etc/tls/certs/default/ca.crt --tls-enabled \
   | grep "${TOPIC}"; then
    echo ">> Creating topic ${TOPIC}"
    kubectl -n redpanda exec -it redpanda-0 -c redpanda -- \
            rpk topic create "${TOPIC}" -r "${SERVERS}" \
            --brokers redpanda.redpanda.svc.cluster.local.:9093 \
            --tls-truststore /etc/tls/certs/default/ca.crt --tls-enabled
fi

### 5. Update our copy of the self-signed root CA file
echo "> Fetching copy of root CA..."
kubectl -n redpanda get secret \
	redpanda-default-root-certificate \
	-o go-template='{{ index .data "ca.crt" | base64decode }}' \
	> redpanda-ca.crt
