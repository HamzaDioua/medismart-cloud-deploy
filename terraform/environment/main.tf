# ==============================================================================
# 1. RÉSEAU VPC & SOUS-RÉSEAU DÉDIÉS
# ==============================================================================
resource "google_compute_network" "vpc" {
  name                    = "medismart-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name                     = "medismart-gke-subnet"
  ip_cidr_range            = "10.10.0.0/20"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true

  # Plages secondaires obligatoires pour GKE VPC-Native (Alias IP)
  secondary_ip_range {
    range_name    = "gke-pods-range"
    ip_cidr_range = "10.20.0.0/16"
  }

  secondary_ip_range {
    range_name    = "gke-services-range"
    ip_cidr_range = "10.30.0.0/20"
  }
}

# ==============================================================================
# 2. PRIVATE SERVICE ACCESS (VPC PEERING POUR CLOUD SQL)
# ==============================================================================
# Réservation d'une plage IP privée interne pour les services managés Google
resource "google_compute_global_address" "private_ip_alloc" {
  name          = "medismart-private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

# Établissement du peering privé vers Google Services
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
}

# ==============================================================================
# 3. BASE DE DONNÉES MANAGÉE : CLOUD SQL POSTGRESQL 16
# ==============================================================================
resource "google_sql_database_instance" "postgres_instance" {
  name                = "medismart-postgres-${var.environment}"
  database_version    = "POSTGRES_16"
  region              = var.region
  deletion_protection = false # Permet de détruire lors des tests d'apprentissage

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier              = "db-f1-micro" # Économique pour tests / dev / démo
    availability_type = "ZONAL"

    ip_configuration {
      ipv4_enabled                                  = false # Aucune IP publique !
      private_network                               = google_compute_network.vpc.id
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled = false
    }
  }
}

resource "google_sql_database" "medismart_database" {
  name     = "medismart_db"
  instance = google_sql_database_instance.postgres_instance.name
}

resource "google_sql_user" "medismart_user" {
  name     = "medismart_user"
  instance = google_sql_database_instance.postgres_instance.name
  password = var.db_password
}

# ==============================================================================
# 4. CLOUD STORAGE POUR LES FICHIERS MÉDICAUX (PRESCRIPTIONS / OCR)
# ==============================================================================
resource "google_storage_bucket" "medical_files" {
  name          = "medismart-files-${var.project_id}-${var.environment}"
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true
}

# ==============================================================================
# 5. CLUSTER GOOGLE KUBERNETES ENGINE (GKE) STANDARD
# ==============================================================================
# Service Account dédié aux nœuds du cluster (Sécurité Moindre Privilège)
resource "google_service_account" "gke_nodes_sa" {
  account_id   = "medismart-gke-nodes"
  display_name = "Service Account pour les nœuds GKE"
}

resource "google_project_iam_member" "gke_nodes_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes_sa.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes_sa.email}"
}

resource "google_project_iam_member" "gke_nodes_ar_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes_sa.email}"
}

# Cluster Master
resource "google_container_cluster" "primary" {
  name     = "medismart-cluster-${var.environment}"
  location = var.zone

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id

  remove_default_node_pool = true
  initial_node_count       = 1

  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods-range"
    services_secondary_range_name = "gke-services-range"
  }

  # Activation de Workload Identity GKE
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Activation du pilote GCS FUSE CSI driver pour monter le bucket de fichiers
  gcs_fuse_csi_driver_config {
    enabled = true
  }

  deletion_protection = false
}

# Node Pool dédié
resource "google_container_node_pool" "primary_nodes" {
  name       = "medismart-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 2

  node_config {
    machine_type = "e2-standard-2"
    disk_size_gb = 30
    disk_type    = "pd-standard"

    service_account = google_service_account.gke_nodes_sa.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    # Activation de Workload Identity sur les nœuds
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      environment = var.environment
    }
  }
}
