terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "medismart-tfstate-hamza"
    prefix = "foundation/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
