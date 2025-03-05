terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "2.9"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.25"
    }
  }
}

provider "kubernetes" {
  config_path = "/infrastructure/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "/infrastructure/.kube/config"
  }
}
