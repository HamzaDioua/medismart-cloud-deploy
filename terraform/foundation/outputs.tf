output "artifact_registry_repo" {
  description = "URL complète du dépôt Artifact Registry"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.repository_id}"
}

output "ci_service_account_email" {
  description = "Email du compte de service CI"
  value       = google_service_account.ci_sa.email
}

output "workload_identity_provider_name" {
  description = "Nom complet du provider WIF pour GitHub Actions"
  value       = google_iam_workload_identity_pool_provider.github_provider.name
}
