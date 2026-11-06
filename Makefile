.ONESHELL:
ifneq (,)
.error This Makefile requires GNU Make.
endif

ifndef VERBOSE
MAKEFLAGS += --no-print-directory
endif

# -------------------------------------------------------------------------------------------------
# Version Variables
# -------------------------------------------------------------------------------------------------
# The planned OpenDKIM version (pinned in the Dockerfile) and the exact Alpine
# base image it is built from. A release is tagged in git with Semantic
# Versioning (e.g. v1.0.0); see the version table in README.md.
#
#   make build                                  # build the default versions
#   make build OPENDKIM_VERSION=2.11.1           # build a different OpenDKIM
#   make build ALPINE_VERSION=3.24.3             # build on a newer Alpine
#
OPENDKIM_VERSION ?= 2.11.0
ALPINE_VERSION  ?= 3.24.2

# Backwards compatibility: `make build VERSION=x.y.z` sets the OpenDKIM version
ifdef VERSION
OPENDKIM_VERSION := $(VERSION)
endif

# OpenDKIM minor version (e.g. 2.11) - used for the moving "2.11-alpine" tag
OPENDKIM_MINOR = $(shell echo $(OPENDKIM_VERSION) | cut -d. -f1,2)

# -------------------------------------------------------------------------------------------------
# Make optional Variables
# -------------------------------------------------------------------------------------------------
ENABLE_CACHE ?= 1

# -------------------------------------------------------------------------------------------------
# Docker required Variables
# -------------------------------------------------------------------------------------------------
DIR        = .
FILE       = Dockerfile
ARCH	   = linux/amd64

# -------------------------------------------------------------------------------------------------
# Docker optional Variables
# -------------------------------------------------------------------------------------------------
CACHE_FLAGS   =
ARGS    =
AUTHORS	= Laszlo Malina <laszlo@malina.hu>
VENDOR	= optimode
URL	= https://github.com/optimode/opendkim
SOURCE	= https://github.com/optimode/opendkim
REVISION=$(shell git rev-parse --short HEAD)
BUILD_DATE=$(shell date --rfc-3339=s)
BASE_IMAGE = alpine:$(ALPINE_VERSION)
OS_VERSION = Alpine $(ALPINE_VERSION)
IMAGE = ghcr.io/$(VENDOR)/opendkim

# Image tags: immutable version tag + moving minor and latest tags
TAGS = $(IMAGE):$(OPENDKIM_VERSION)-alpine \
       $(IMAGE):$(OPENDKIM_MINOR)-alpine \
       $(IMAGE):latest-alpine

# Auto-detect current platform and use it as default to build for
_PLATFORM = $(shell uname -m)
ifeq ($(strip $(_PLATFORM)),x86_64)
	ARCH = linux/amd64
else
	ifeq ($(strip $(_PLATFORM)),arm64)
		ARCH = linux/arm64
	endif
endif

ifeq ($(ENABLE_CACHE),0)
    CACHE_FLAGS+=--no-cache
endif

# -------------------------------------------------------------------------------------------------
# Targets
# -------------------------------------------------------------------------------------------------
.PHONY: build
build: ## Build the image. (Usage: make build [OPENDKIM_VERSION=x.y.z] [ALPINE_VERSION=x.y.z])

	@echo "################################################################################"
	@echo "# Building $(IMAGE):$(OPENDKIM_VERSION)-alpine"
	@echo "# OpenDKIM $(OPENDKIM_VERSION) on $(BASE_IMAGE) (platform: $(ARCH), revision: $(REVISION))"
	@echo "################################################################################"
	docker buildx build \
		$(CACHE_FLAGS) \
		$(ARGS) \
		--network host \
		--platform $(ARCH) \
		--load \
		--build-arg "AUTHORS=$(AUTHORS)" \
		--build-arg "VENDOR=$(VENDOR)" \
		--build-arg "URL=$(URL)" \
		--build-arg "REVISION=$(REVISION)" \
		--build-arg "SOURCE=$(SOURCE)" \
		--build-arg "BUILD_DATE=$(BUILD_DATE)" \
		--build-arg "OPENDKIM_VERSION=$(OPENDKIM_VERSION)" \
		--build-arg "BASE_IMAGE=$(BASE_IMAGE)" \
		--build-arg "OS_VERSION=$(OS_VERSION)" \
		$(foreach tag,$(TAGS),--tag $(tag)) \
		--file $(FILE) $(DIR)
	@echo ""
	@echo "Built tags:"
	@$(foreach tag,$(TAGS),echo "  $(tag)";)
	@echo ""
	@echo "Image metadata:"
	@docker image inspect $(IMAGE):$(OPENDKIM_VERSION)-alpine \
		--format '  version={{index .Config.Labels "org.opencontainers.image.version"}} created={{index .Config.Labels "org.opencontainers.image.created"}} revision={{index .Config.Labels "org.opencontainers.image.revision"}} base={{index .Config.Labels "org.opencontainers.image.base.name"}}'

.PHONY: push
push:  ## Push all tags of the given version to the container registry
	@$(foreach tag,$(TAGS),echo "Pushing $(tag)"; docker push $(tag);)

.PHONY: help
help:  ## List all available make targets
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo " build                Build the Docker image"
	@echo " push                 Push all tags of the built image"
	@echo ""
	@echo " Optional environment variables:"
	@echo ""
	@echo "  OPENDKIM_VERSION=x.y.z OpenDKIM version to pin (default: $(OPENDKIM_VERSION))"
	@echo "  ALPINE_VERSION=x.y.z  Alpine base image version (default: $(ALPINE_VERSION))"
	@echo "  VERSION=x.y.z         Alias of OPENDKIM_VERSION"
	@echo "  ENABLE_CACHE=0        Disable cache during build (default: 1)"
	@echo ""
	@echo "Examples:"
	@echo "  make build"
	@echo "  make build ALPINE_VERSION=3.24.3"
	@echo "  make build push ENABLE_CACHE=0"
