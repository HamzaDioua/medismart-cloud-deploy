output "gke_cluster_name" {
  description = "Nom du cluster GKE"
  value       = google_container_cluster.primary.name
}

output "gke_cluster_endpoint" {
  description = "Endpoint du cluster GKE"
  value       = google_container_cluster.primary.endpoint
}

output "cloud_sql_private_ip" {
  description = "Adresse IP privée de l'instance PostgreSQL Cloud SQL"
  value       = google_sql_database_instance.postgres_instance.private_ip_address
}

output "medical_files_bucket_name" {
  description = "Nom du bucket Cloud Storage pour les fichiers médicaux"
  value       = google_storage_bucket.medical_files.name
}
