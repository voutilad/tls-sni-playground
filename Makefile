CLUSTER_NAME ?= sni-test
RP_DOMAIN ?= sni-demo.redpanda-labs.com
SNI_DEMO_VERSION ?= 0.2.0
ECHO_IMAGE ?= echo
TRAEFIK_IMAGE ?= traefik-sni
CLIENT_IMAGE ?= sclient

K3D_REPO_PORT != docker ps --filter "name=${CLUSTER_NAME}-registry" \
	--format "{{.Ports}}" \
	| sed 's/.*:\([0-9]*\).*->.*/\1/'
ifeq ($(K3D_REPO_PORT),)
	REPO_BASE=
else
# no k3d detected
	REPO_BASE=localhost:$(K3D_REPO_PORT)/
endif


build: build-echo build-traefik build-client

build-echo: ./echo/Dockerfile
	echo "K3D_REPO_PORT: ${K3D_REPO_PORT}"
	echo "Using REPO_BASE: ${REPO_BASE}"
	docker build ./echo \
		-t "${ECHO_IMAGE}:${SNI_DEMO_VERSION}" \
		-t "${REPO_BASE}${ECHO_IMAGE}:${SNI_DEMO_VERSION}" \
		-t "${REPO_BASE}${ECHO_IMAGE}:latest"

build-traefik: ./traefik/Dockerfile ./traefik/traefik.yaml ./traefik/traefik-dynamic.yaml
	docker build ./traefik \
		--build-arg "DOMAIN=${RP_DOMAIN}" \
		-t "${TRAEFIK_IMAGE}:${SNI_DEMO_VERSION}" \
		-t "${REPO_BASE}${TRAEFIK_IMAGE}:${SNI_DEMO_VERSION}" \
		-t "${REPO_BASE}${TRAEFIK_IMAGE}:latest"

build-client: ./sclient/Dockerfile ./sclient/entrypoint.sh
	docker build ./sclient \
		-t "${CLIENT_IMAGE}:${SNI_DEMO_VERSION}" \
		-t "${CLIENT_IMAGE}:latest"

push: push-echo push-traefik

push-echo:
ifneq ($(REPO_BASE),)
	docker push "${REPO_BASE}${ECHO_IMAGE}:latest"
	docker push "${REPO_BASE}${ECHO_IMAGE}:${SNI_DEMO_VERSION}"
endif

push-traefik:
ifneq ($(REPO_BASE),)
	docker push "${REPO_BASE}${TRAEFIK_IMAGE}:latest"
	docker push "${REPO_BASE}${TRAEFIK_IMAGE}:${SNI_DEMO_VERSION}"
endif

run-client:
	docker run --rm -it \
		--network "k3d-${CLUSTER_NAME}" sclient:latest

.PHONY: build-echo build-traefik build-client push-echo push-traefik run-client
