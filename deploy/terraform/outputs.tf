output "service_url" {
  description = "Cloud Run service URL"
  value       = google_cloud_run_v2_service.app.uri
}

output "custom_domain_dns_records" {
  description = "DNS records to add at your domain provider"
  value       = google_cloud_run_domain_mapping.default.status[0].resource_records
}

output "config_bucket_url" {
  description = "Public URL for config JSON files"
  value       = "https://storage.googleapis.com/${google_storage_bucket.config.name}"
}

output "config_deploy_sa_email" {
  description = "Service account email for GitHub Actions config deploy"
  value       = google_service_account.config_deploy.email
}

output "workload_identity_provider" {
  description = "Workload Identity provider for GitHub Actions (use in workflow)"
  value       = google_iam_workload_identity_pool_provider.github.name
}
