variable "project_id" {
  description = "L'ID du projet Google Cloud"
  type        = string
  default     = "medismart-cloud-deploy"
}

variable "region" {
  description = "Région principale GCP"
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "Zone GCP pour le cluster GKE zonal"
  type        = string
  default     = "europe-west1-b"
}

variable "environment" {
  description = "Nom de l'environnement (ex: staging, prod)"
  type        = string
  default     = "prod"
}

variable "db_password" {
  description = "Mot de passe de l'utilisateur de la base PostgreSQL"
  type        = string
  sensitive   = true
  default     = "medismart_secure_password_2026"
}
