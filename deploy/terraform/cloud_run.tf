locals {
  image = "${var.region}-docker.pkg.dev/${var.project_id}/audiflow/${var.service_name}:${var.image_tag}"
}

resource "google_cloud_run_v2_service" "app" {
  name     = var.service_name
  location = var.region

  template {
    service_account = google_service_account.cloud_run.email

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }

    containers {
      image = local.image

      resources {
        limits = {
          memory = "512Mi"
          cpu    = "1"
        }
      }

      # -- Secret env vars --

      env {
        name = "JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jwt_secret.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "GITHUB_CLIENT_ID"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.github_client_id.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "GITHUB_CLIENT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.github_client_secret.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "GITHUB_TOKEN"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.github_token.secret_id
            version = "latest"
          }
        }
      }

      # -- Plain env vars --

      env {
        name  = "CONFIG_OWNER"
        value = var.config_owner
      }

      env {
        name  = "CONFIG_REPO"
        value = var.config_repo
      }

      env {
        name  = "CONFIG_REPO_URL"
        value = local.config_repo_url
      }

      env {
        name  = "GITHUB_REDIRECT_URI"
        value = var.github_redirect_uri
      }

      # -- Health check --

      startup_probe {
        http_get {
          path = "/api/health"
        }
        initial_delay_seconds = 5
        period_seconds        = 10
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = "/api/health"
        }
        period_seconds = 30
      }
    }
  }

  depends_on = [
    google_secret_manager_secret_version.jwt_secret,
    google_secret_manager_secret_version.github_client_id,
    google_secret_manager_secret_version.github_client_secret,
    google_secret_manager_secret_version.github_token,
  ]
}

# Custom domain mapping
resource "google_cloud_run_domain_mapping" "default" {
  name     = var.custom_domain
  location = var.region

  metadata {
    namespace = var.project_id
  }

  spec {
    route_name = google_cloud_run_v2_service.app.name
  }
}

# Allow unauthenticated public access
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  project  = google_cloud_run_v2_service.app.project
  location = google_cloud_run_v2_service.app.location
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
