provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

terraform {
  backend "gcs" {
    bucket = "servicenow-ai-terraform-state-staging"
    prefix = "terraform/state/staging"
  }
  required_version = ">= 1.11.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.10"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.10"
    }
  }
}
