terraform {
  required_version = ">= 1.11.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0" # allow all 3.x
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0" # allow all 3.x
    }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}
