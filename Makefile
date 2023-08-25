CLUSTER_NAME ?= sni-test
SNI_DEMO_VERSION ?= 0.2.0
CLIENT_IMAGE ?= sclient

build: build-client

build-client: ./sclient/Dockerfile ./sclient/entrypoint.sh
	docker build ./sclient \
		-t "${CLIENT_IMAGE}:${SNI_DEMO_VERSION}" \
		-t "${CLIENT_IMAGE}:latest"

run-client:
	docker run --rm -it \
		--network "k3d-${CLUSTER_NAME}" sclient:latest

.PHONY: build deploy-echo-configmap build-client run-client
