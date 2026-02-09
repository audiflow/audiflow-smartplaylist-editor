terraform {
  required_version = "~> 1.5"

  # State is isolated per workspace (dev/prod) automatically.
  # GCS stores state at: <prefix>/default.tfstate or <prefix>/<workspace>/default.tfstate
  backend "gcs" {
    bucket = "audiflow-tfstate"
    prefix = "cloud-run"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
