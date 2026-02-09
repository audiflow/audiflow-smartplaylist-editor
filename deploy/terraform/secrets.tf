# -- JWT Secret --

resource "google_secret_manager_secret" "jwt_secret" {
  secret_id = "audiflow-sp-jwt-secret"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "jwt_secret" {
  secret      = google_secret_manager_secret.jwt_secret.id
  secret_data = var.jwt_secret
}

# -- GitHub Client ID --

resource "google_secret_manager_secret" "github_client_id" {
  secret_id = "audiflow-sp-github-client-id"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "github_client_id" {
  secret      = google_secret_manager_secret.github_client_id.id
  secret_data = var.github_client_id
}

# -- GitHub Client Secret --

resource "google_secret_manager_secret" "github_client_secret" {
  secret_id = "audiflow-sp-github-client-secret"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "github_client_secret" {
  secret      = google_secret_manager_secret.github_client_secret.id
  secret_data = var.github_client_secret
}

# -- GitHub Token --

resource "google_secret_manager_secret" "github_token" {
  secret_id = "audiflow-sp-github-token"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "github_token" {
  secret      = google_secret_manager_secret.github_token.id
  secret_data = var.github_token
}
