resource "google_artifact_registry_repository" "docker" {
  location      = var.region
  repository_id = "audiflow"
  format        = "DOCKER"
  description   = "Docker repository for Audiflow container images"
}
