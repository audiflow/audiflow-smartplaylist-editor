.PHONY: deps build-runner server web dev test test-shared test-server test-web test-mcp analyze format clean help

# Ports
SERVER_PORT ?= 8080
WEB_PORT    ?= 60792

# Paths
ROOT        := $(shell pwd)
SP_SHARED   := $(ROOT)/packages/sp_shared
SP_SERVER   := $(ROOT)/packages/sp_server
SP_WEB      := $(ROOT)/packages/sp_web
MCP_SERVER  := $(ROOT)/mcp_server
ENV_FILE    := $(ROOT)/.env

# Load .env if it exists
ifneq (,$(wildcard $(ENV_FILE)))
  include $(ENV_FILE)
  export
endif

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# -- Setup -------------------------------------------------------------------

deps: ## Install dependencies for all packages
	dart pub get

build-runner: ## Run code generation (json_serializable) for sp_shared
	cd $(SP_SHARED) && dart run build_runner build --delete-conflicting-outputs

setup: deps build-runner ## Full setup: install deps + run code generation

# -- Run services ------------------------------------------------------------

server: ## Start the backend API server (PORT=$(SERVER_PORT))
	cd $(SP_SERVER) && PORT=$(SERVER_PORT) dart run bin/server.dart

web: ## Start the Flutter web app (port $(WEB_PORT))
	cd $(SP_WEB) && flutter run -d web-server \
		--web-port=$(WEB_PORT) \
		--dart-define=API_URL=http://localhost:$(SERVER_PORT)

dev: ## Start server and web app together (background server)
	@echo "Starting sp_server on port $(SERVER_PORT) ..."
	@cd $(SP_SERVER) && PORT=$(SERVER_PORT) dart run bin/server.dart &
	@echo "Starting sp_web on port $(WEB_PORT) ..."
	@cd $(SP_WEB) && flutter run -d web-server \
		--web-port=$(WEB_PORT) \
		--dart-define=API_URL=http://localhost:$(SERVER_PORT)

# -- Testing -----------------------------------------------------------------

test: ## Run all tests
	dart test $(SP_SHARED)
	dart test $(SP_SERVER)
	dart test $(MCP_SERVER)

test-shared: ## Run sp_shared tests
	dart test $(SP_SHARED)

test-server: ## Run sp_server tests
	dart test $(SP_SERVER)

test-web: ## Run sp_web tests
	cd $(SP_WEB) && flutter test

test-mcp: ## Run mcp_server tests
	dart test $(MCP_SERVER)

# -- Quality -----------------------------------------------------------------

analyze: ## Run static analysis on all packages
	dart analyze

format: ## Format all Dart files
	dart format .

format-check: ## Check formatting without applying changes
	dart format --set-exit-if-changed .

# -- Cleanup -----------------------------------------------------------------

clean: ## Remove build artifacts and caches
	cd $(SP_WEB) && flutter clean
	dart pub get
