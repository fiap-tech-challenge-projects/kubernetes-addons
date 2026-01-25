# =============================================================================
# FIAP Tech Challenge - Kubernetes Addons (Phase 2)
# =============================================================================
# Este modulo provisiona recursos Kubernetes adicionais APOS a criacao do cluster
# EKS. Isso evita o problema de chicken-and-egg com providers Kubernetes/Helm.
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }

  # Backend S3 para armazenamento do state
  backend "s3" {
    key            = "kubernetes-addons/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "fiap-terraform-locks"
  }
}

# -----------------------------------------------------------------------------
# Data Sources - Remote State from kubernetes-core-infra
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = "fiap-tech-challenge-tf-state-${data.aws_caller_identity.current.account_id}"
    key    = "kubernetes-core-infra/terraform.tfstate"
    region = var.aws_region
  }
}

# -----------------------------------------------------------------------------
# Providers
# -----------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

# Kubernetes provider usando valores do remote state (cluster ja existe)
provider "kubernetes" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority)

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name]
  }
}

# Helm provider para instalacao de charts
provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority)

    exec {
      api_version = "client.authentication.k8s.io/v1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name]
    }
  }
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  cluster_name = data.terraform_remote_state.eks.outputs.cluster_name
  vpc_id       = data.terraform_remote_state.eks.outputs.vpc_id
}
