.PHONY: deps build-runner server dev mcp test test-shared test-server test-react test-mcp \
	analyze lint format build-web clean help

# Ports
SERVER_PORT ?= 8080

# Paths
ROOT        := $(shell pwd)
SP_SHARED   := $(ROOT)/packages/sp_shared
SP_SERVER   := $(ROOT)/packages/sp_server
SP_REACT    := $(ROOT)/packages/sp_react
MCP_SERVER  := $(ROOT)/mcp_server

# Data directory (path to a cloned audiflow-smartplaylist data repo)
DATA_DIR    ?= $(ROOT)/../audiflow-smartplaylist

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# -- Setup -------------------------------------------------------------------

deps: ## Install dependencies for all packages
	dart pub get
	cd $(SP_REACT) && pnpm install

build-runner: ## Run code generation (json_serializable) for sp_shared
	cd $(SP_SHARED) && dart run build_runner build --delete-conflicting-outputs

setup: deps build-runner ## Full setup: install deps + run code generation

# -- Run services ------------------------------------------------------------

server: ## Start the backend API server (PORT=$(SERVER_PORT))
	cd $(SP_SERVER) && PORT=$(SERVER_PORT) DATA_DIR="$(DATA_DIR)" dart run bin/server.dart

dev: ## Start server and React web app together (Ctrl+C stops both)
	@trap 'kill 0 2>/dev/null' EXIT; \
	(cd $(SP_SERVER) && PORT=$(SERVER_PORT) DATA_DIR="$(DATA_DIR)" dart run bin/server.dart) & \
	echo "sp_server started on port $(SERVER_PORT)"; \
	cd $(SP_REACT) && pnpm dev

mcp: ## Start the MCP server (run from a data repo directory)
	dart run $(MCP_SERVER)/bin/mcp_server.dart

# -- Testing -----------------------------------------------------------------

test: ## Run all tests
	dart test $(SP_SHARED)
	dart test $(SP_SERVER)
	dart test $(MCP_SERVER)
	cd $(SP_REACT) && pnpm test -- --run

test-shared: ## Run sp_shared tests
	dart test $(SP_SHARED)

test-server: ## Run sp_server tests
	dart test $(SP_SERVER)

test-react: ## Run sp_react tests
	cd $(SP_REACT) && pnpm test -- --run

test-mcp: ## Run mcp_server tests
	dart test $(MCP_SERVER)

# -- Quality -----------------------------------------------------------------

analyze: ## Run static analysis on all packages
	dart analyze
	cd $(SP_REACT) && npx tsc -b --noEmit

lint: ## Run linters (ESLint for React, dart analyze for Dart)
	dart analyze
	cd $(SP_REACT) && npx oxlint

format: ## Format all Dart files
	dart format .

format-check: ## Check formatting without applying changes
	dart format --set-exit-if-changed .

# -- Build -------------------------------------------------------------------

build-web: ## Build React SPA for production
	cd $(SP_REACT) && pnpm build

# -- Cleanup -----------------------------------------------------------------

clean: ## Remove build artifacts and caches
	rm -rf $(SP_REACT)/dist $(SP_REACT)/node_modules
	dart pub get
