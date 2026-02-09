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

.PHONY: plan-dev apply-dev plan-prod apply-prod init

init:
	terraform init

plan-dev:
	terraform workspace select dev
	$(ENV_VARS_DEV) terraform plan -var-file=environments/dev.tfvars

apply-dev:
	terraform workspace select dev
	$(ENV_VARS_DEV) terraform apply -var-file=environments/dev.tfvars

plan-prod:
	terraform workspace select prod
	$(ENV_VARS_PROD) terraform plan -var-file=environments/prod.tfvars

apply-prod:
	terraform workspace select prod
	$(ENV_VARS_PROD) terraform apply -var-file=environments/prod.tfvars
