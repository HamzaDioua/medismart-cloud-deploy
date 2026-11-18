variable "project_id" {
  description = "L'identifiant du projet Google Cloud"
  type        = string
  default     = "medismart-cloud-deploy"
}

variable "region" {
  description = "Région principale GCP"
  type        = string
  default     = "europe-west1"
}

variable "github_repo" {
  description = "Dépôt GitHub autorisé pour WIF (format: propriétaire/repo)"
  type        = string
  default     = "HamzaDioua/medismart-cloud-deploy"
}

variable "github_owner" {
  description = "Propriétaire GitHub pour la condition WIF"
  type        = string
  default     = "HamzaDioua"
}

variable "secrets_list" {
  description = "Liste des secrets applicatifs requis dans Secret Manager"
  type        = list(string)
  default = [
    "SPRING_DATASOURCE_PASSWORD",
    "JWT_SECRET",
    "MAIL_PASSWORD",
    "GROQ_API_KEY",
    "STRIPE_SECRET_KEY"
  ]
}
