.PHONY: deps build-runner server web dev test test-shared test-server test-web test-mcp analyze format clean help \
	docker-build-dev docker-push-dev docker-build-prod docker-push-prod deploy-dev deploy-prod \
	tf-init tf-plan-dev tf-apply-dev tf-plan-prod tf-apply-prod

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

LOCAL_ENV = \
	PORT=$(SERVER_PORT) \
	JWT_SECRET="$(JWT_SECRET_LOCAL)" \
	GITHUB_CLIENT_ID="$(GITHUB_CLIENT_ID_LOCAL)" \
	GITHUB_CLIENT_SECRET="$(GITHUB_CLIENT_SECRET_LOCAL)" \
	GITHUB_TOKEN="$(GITHUB_TOKEN_LOCAL)" \
	GITHUB_REDIRECT_URI="http://localhost:$(SERVER_PORT)/api/auth/github/callback"

server: ## Start the backend API server (PORT=$(SERVER_PORT))
	cd $(SP_SERVER) && $(LOCAL_ENV) dart run bin/server.dart

web: ## Start the Flutter web app (port $(WEB_PORT))
	cd $(SP_WEB) && flutter run -d web-server \
		--web-port=$(WEB_PORT) \
		--dart-define=API_URL=http://localhost:$(SERVER_PORT)

dev: ## Start server and web app together (background server)
	@echo "Starting sp_server on port $(SERVER_PORT) ..."
	@cd $(SP_SERVER) && $(LOCAL_ENV) dart run bin/server.dart &
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

# -- Deploy ------------------------------------------------------------------

IMAGE_DEV  := asia-northeast1-docker.pkg.dev/audiflow-dev/audiflow/audiflow-sp
IMAGE_PROD := asia-northeast1-docker.pkg.dev/audiflow-prod/audiflow/audiflow-sp
TF_DIR     := $(ROOT)/deploy/terraform

ENV_VARS_DEV = \
	TF_VAR_jwt_secret="$(JWT_SECRET_DEV)" \
	TF_VAR_github_client_id="$(GITHUB_CLIENT_ID_DEV)" \
	TF_VAR_github_client_secret="$(GITHUB_CLIENT_SECRET_DEV)" \
	TF_VAR_github_token="$(GITHUB_TOKEN_DEV)"

ENV_VARS_PROD = \
	TF_VAR_jwt_secret="$(JWT_SECRET_PROD)" \
	TF_VAR_github_client_id="$(GITHUB_CLIENT_ID_PROD)" \
	TF_VAR_github_client_secret="$(GITHUB_CLIENT_SECRET_PROD)" \
	TF_VAR_github_token="$(GITHUB_TOKEN_PROD)"

docker-build-dev: ## Build Docker image for dev
	docker build --platform linux/amd64 -t $(IMAGE_DEV):latest .

docker-push-dev: ## Push Docker image to dev Artifact Registry
	docker push $(IMAGE_DEV):latest

docker-build-prod: ## Build Docker image for prod
	docker build --platform linux/amd64 -t $(IMAGE_PROD):latest .

docker-push-prod: ## Push Docker image to prod Artifact Registry
	docker push $(IMAGE_PROD):latest

tf-init: ## Initialize Terraform
	cd $(TF_DIR) && terraform init

tf-plan-dev: ## Preview Terraform changes for dev
	cd $(TF_DIR) && terraform workspace select dev && \
		$(ENV_VARS_DEV) terraform plan -var-file=environments/dev.tfvars

tf-apply-dev: ## Apply Terraform for dev
	cd $(TF_DIR) && terraform workspace select dev && \
		$(ENV_VARS_DEV) terraform apply -var-file=environments/dev.tfvars

tf-plan-prod: ## Preview Terraform changes for prod
	cd $(TF_DIR) && terraform workspace select prod && \
		$(ENV_VARS_PROD) terraform plan -var-file=environments/prod.tfvars

tf-apply-prod: ## Apply Terraform for prod
	cd $(TF_DIR) && terraform workspace select prod && \
		$(ENV_VARS_PROD) terraform apply -var-file=environments/prod.tfvars

deploy-dev: docker-build-dev docker-push-dev tf-apply-dev ## Build, push, and deploy to dev

deploy-prod: docker-build-prod docker-push-prod tf-apply-prod ## Build, push, and deploy to prod

# -- Cleanup -----------------------------------------------------------------

clean: ## Remove build artifacts and caches
	cd $(SP_WEB) && flutter clean
	dart pub get
