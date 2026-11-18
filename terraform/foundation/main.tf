# 1. Activation des APIs Google Cloud fondamentales
locals {
  services = [
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "storage.googleapis.com",
    "container.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com"
  ]
}

resource "google_project_service" "apis" {
  for_each                   = toset(locals.services)
  project                    = var.project_id
  service                    = each.key
  disable_dependent_services = false
  disable_on_destroy         = false
}

# 2. Dépôt Docker Artifact Registry (Permanent)
resource "google_artifact_registry_repository" "docker_repo" {
  depends_on    = [google_project_service.apis]
  project       = var.project_id
  location      = var.region
  repository_id = "medismart-repo"
  description   = "Dépôt Docker MediSmart (Backend & Frontend)"
  format        = "DOCKER"
}

# 3. Compte de service CI/CD GitHub Actions
resource "google_service_account" "ci_sa" {
  depends_on   = [google_project_service.apis]
  project      = var.project_id
  account_id   = "medismart-ci"
  display_name = "MediSmart CI GitHub Actions"
}

# Rôle Moindre Privilège : Writer uniquement sur Artifact Registry
resource "google_project_iam_member" "ci_ar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.ci_sa.email}"
}

# 4. Workload Identity Federation (Authentification sans clé JSON)
resource "google_iam_workload_identity_pool" "github_pool" {
  depends_on                = [google_project_service.apis]
  project                   = var.project_id
  workload_identity_pool_id = "medismart-github-pool"
  display_name              = "Pool GitHub Actions MediSmart"
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "medismart-github-provider"
  display_name                       = "GitHub Provider"
  attribute_condition                = "assertion.repository_owner == '${var.github_owner}'"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.actor"      = "assertion.actor"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Autoriser GitHub Actions à impersonner le Service Account CI
resource "google_service_account_iam_member" "wif_binding" {
  service_account_id = google_service_account.ci_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/${var.github_repo}"
}

# 5. Secret Manager (provisionnement des réceptacles de secrets)
resource "google_secret_manager_secret" "secrets" {
  for_each   = toset(var.secrets_list)
  depends_on = [google_project_service.apis]
  project    = var.project_id
  secret_id  = each.key

  replication {
    auto {}
  }
}
