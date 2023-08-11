DOCKER_IMAGE ?= echo
DOCKER_VERSION ?= 0.1.2
TRAEFIK_IMAGE ?= traefik-sni
CLIENT_IMAGE ?= sclient

PORT != docker ps --filter "name=sni-test-registry" --format "{{.Ports}}" \
	| sed 's/.*:\([0-9]*\).*->.*/\1/'

build: build-echo build-traefik build-client

build-echo: Dockerfile
	docker build  . \
		-f Dockerfile \
		-t "${DOCKER_IMAGE}:${DOCKER_VERSION}" \
		-t "${DOCKER_IMAGE}:latest" \
		-t "localhost:${PORT}/${DOCKER_IMAGE}:latest"

build-traefik: Dockerfile.traefik
	docker build . \
		-f Dockerfile.traefik \
		-t "${TRAEFIK_IMAGE}:latest" \
		-t "localhost:${PORT}/${TRAEFIK_IMAGE}:latest"

build-client: Dockerfile.client entrypoint.sh
	docker build . \
		-f Dockerfile.client \
		-t "${CLIENT_IMAGE}:latest"

push: push-echo push-traefik

push-echo:
	docker push "localhost:${PORT}/${DOCKER_IMAGE}:latest"

push-traefik:
	docker push "localhost:${PORT}/${TRAEFIK_IMAGE}:latest"

run-client:
	docker run --rm -it --network k3d-sni-test sclient:latest

.PHONY: build-echo build-traefik build-client push-echo push-traefik run-client
