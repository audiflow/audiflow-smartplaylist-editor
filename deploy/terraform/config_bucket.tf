locals {
  config_repo_url = (
    var.config_repo_url != ""
    ? var.config_repo_url
    : "https://storage.googleapis.com/${var.config_bucket_name}"
  )
}

# GCS bucket for config JSON files (meta.json, pattern dirs, playlists)
resource "google_storage_bucket" "config" {
  name     = var.config_bucket_name
  location = var.region

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

# Public read access so the server can fetch via HTTPS without credentials
resource "google_storage_bucket_iam_member" "config_public_read" {
  bucket = google_storage_bucket.config.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# --- Workload Identity Federation for GitHub Actions ---

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  attribute_condition = "assertion.repository == \"${var.config_deploy_repo}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Service account for GitHub Actions to write config files
resource "google_service_account" "config_deploy" {
  account_id   = "config-deploy-sa"
  display_name = "Config Deploy GitHub Actions SA"
}

# Allow GitHub Actions to impersonate the SA
resource "google_service_account_iam_member" "config_deploy_wif" {
  service_account_id = google_service_account.config_deploy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.config_deploy_repo}"
}

# Grant the deploy SA write access to the config bucket
resource "google_storage_bucket_iam_member" "config_deploy_write" {
  bucket = google_storage_bucket.config.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.config_deploy.email}"
}
