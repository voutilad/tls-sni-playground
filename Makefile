DOCKER_IMAGE ?= echo
DOCKER_VERSION ?= 0.1.2
PORT != docker ps --filter "name=sni-test-registry" --format "{{.Ports}}" \
	| sed 's/.*:\([0-9]*\).*->.*/\1/'

build:
	docker build  . \
		-t "${DOCKER_IMAGE}:${DOCKER_VERSION}" \
		-t "${DOCKER_IMAGE}:latest" \
		-t "localhost:${PORT}/${DOCKER_IMAGE}:latest"

push:
	docker push "localhost:${PORT}/${DOCKER_IMAGE}:latest"

.PHONY: build push
