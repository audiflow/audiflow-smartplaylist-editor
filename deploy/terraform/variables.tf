variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "asia-northeast1"
}

variable "service_name" {
  description = "Cloud Run service name"
  type        = string
  default     = "audiflow-sp"
}

variable "image_tag" {
  description = "Container image tag to deploy"
  type        = string
  default     = "latest"
}

variable "config_owner" {
  description = "GitHub owner of the config repository"
  type        = string
  default     = "reedom"
}

variable "config_repo" {
  description = "GitHub config repository name"
  type        = string
  default     = "audiflow-smartplaylist"
}

variable "config_repo_url" {
  description = "Base URL for config file access (set automatically from config_bucket_name)"
  type        = string
  default     = ""
}

variable "config_bucket_name" {
  description = "GCS bucket name for config JSON files"
  type        = string
}

variable "config_deploy_repo" {
  description = "GitHub repo (owner/name) that deploys config files to GCS"
  type        = string
}

variable "custom_domain" {
  description = "Custom domain to map to the Cloud Run service"
  type        = string
}

variable "github_redirect_uri" {
  description = "GitHub OAuth redirect URI"
  type        = string
}

variable "jwt_secret" {
  description = "JWT signing secret"
  type        = string
  sensitive   = true
}

variable "github_client_id" {
  description = "GitHub OAuth app client ID"
  type        = string
  sensitive   = true
}

variable "github_client_secret" {
  description = "GitHub OAuth app client secret"
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "GitHub personal access token for config repo access"
  type        = string
  sensitive   = true
}
