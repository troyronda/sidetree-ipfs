#
# Copyright SecureKey Technologies Inc. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

#
# Supported Targets:
#
#   all:                 runs code checks, unit and integration tests
#   checks:              runs code checks (license, lint)
#   unit-test:           runs unit tests
#   bdd-test:            run bdd tests
#   generate-test-keys:  generate tls test keys
#


# Local variables used by makefile
CONTAINER_IDS      = $(shell docker ps -a -q)
DEV_IMAGES         = $(shell docker images dev-* -q)
ARCH               = $(shell go env GOARCH)
GO_VER             = 1.13.4

# Namespace for the sidetree ipfs node
DOCKER_OUTPUT_NS          ?= ghcr.io
SIDETREE_IPFS_IMAGE_NAME  ?= trustbloc/sidetree-ipfs


# Tool commands (overridable)
DOCKER_CMD ?= docker
GO_CMD     ?= go
ALPINE_VER ?= 3.10
GO_TAGS    ?=

export GO111MODULE=on

checks: license lint

license:
	@scripts/check_license.sh

lint:
	@scripts/check_lint.sh

unit-test:
	@scripts/unit.sh

all: clean checks unit-test

sidetree-ipfs:
	@echo "Building sidetree-ipfs"
	@mkdir -p ./.build/bin
	@go build -o ./.build/bin/sidetree-ipfs cmd/sidetree-server/main.go

sidetree-ipfs-docker:
	@docker build -f ./images/sidetree-ipfs/Dockerfile --no-cache -t $(DOCKER_OUTPUT_NS)/$(SIDETREE_IPFS_IMAGE_NAME):latest \
	--build-arg GO_VER=$(GO_VER) \
	--build-arg ALPINE_VER=$(ALPINE_VER) \
	--build-arg GO_TAGS=$(GO_TAGS) \
	--build-arg GOPROXY=$(GOPROXY) .

clean-images:
	@echo "Stopping all containers, pruning containers and images, deleting dev images"
ifneq ($(strip $(CONTAINER_IDS)),)
	@docker stop $(CONTAINER_IDS)
endif
	@docker system prune -f
ifneq ($(strip $(DEV_IMAGES)),)
	@docker rmi $(DEV_IMAGES) -f
endif


generate-test-keys:
	@mkdir -p -p test/bdd/fixtures/keys/tls
	@docker run -i --rm \
		-v $(abspath .):/opt/workspace/sidetree-ipfs \
		--entrypoint "/opt/workspace/sidetree-ipfs/scripts/generate_test_keys.sh" \
		frapsoft/openssl

bdd-test: generate-test-keys sidetree-ipfs-docker
	@scripts/integration.sh

clean:
	rm -Rf ./.build
	rm -Rf ./test/bdd/docker-compose.log
	rm -Rf ./test/bdd/fixtures/keys/tls
