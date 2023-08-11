#!/bin/sh
set -ex
NUM_SERVERS=1
NUM_AGENTS=2

# Create a k3s cluster, disabling the built-in traefik ingress.
k3d cluster create \
    --k3s-arg "--disable=traefik@server:*" \
    --registry-create sni-test-registry \
    -s "${NUM_SERVERS}" -a "${NUM_AGENTS}" \
    --servers-memory "1g" --agents-memory "1g" \
    sni-test
