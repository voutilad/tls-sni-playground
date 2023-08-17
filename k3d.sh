#!/bin/sh
set -e
CLUSTER_NAME="${K3D_CLUSTER_NAME:-sni-test}"
NUM_SERVERS="${K3D_NUM_SERVERS:-1}"
NUM_AGENTS="${K3D_NUM_AGENTS:-3}"

NODEPORT_INTERNAL_ECHO=30888
NODEPORT_EXTERNAL_ECHO=8888
NODEPORT_INTERNAL_KAFKA=30094
NODEPORT_EXTERNAL_KAFKA=9094
NODEPORT_INTERNAL_ADMIN=30645
NODEPORT_EXTERNAL_ADMIN=9645

# Create a k3s cluster, disabling the built-in traefik ingress.
echo "> Looking for existing cluster..."
if ! k3d cluster list "${CLUSTER_NAME}" 2>&1 > /dev/null; then
    echo "> Creating cluster ${CLUSTER_NAME}"
    k3d cluster create \
        --k3s-arg "--disable=traefik@server:*" \
        --registry-create "${CLUSTER_NAME}-registry" \
        -s "${NUM_SERVERS}" -a "${NUM_AGENTS}" \
        -p "${NODEPORT_EXTERNAL_ECHO}:${NODEPORT_INTERNAL_ECHO}@agent:0" \
        -p "${NODEPORT_EXTERNAL_KAFKA}:${NODEPORT_INTERNAL_KAFKA}@agent:0" \
        -p "${NODEPORT_EXTERNAL_ADMIN}:${NODEPORT_INTERNAL_ADMIN}@agent:0" \
        --servers-memory "1g" --agents-memory "2g" \
        "${CLUSTER_NAME}"
else
    echo "> Making sure cluster ${CLUSTER_NAME} is started"
    k3d cluster start "${CLUSTER_NAME}" --wait 2>&1 > /dev/null
fi
