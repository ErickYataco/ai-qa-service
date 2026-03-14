terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = compact([
      "eks",
      "get-token",
      "--cluster-name", module.eks.cluster_name,
      "--region", var.region,
      var.aws_profile != null && var.aws_profile != "" ? "--profile" : null,
      var.aws_profile != null && var.aws_profile != "" ? var.aws_profile : null
    ])
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = compact([
        "eks",
        "get-token",
        "--cluster-name", module.eks.cluster_name,
        "--region", var.region,
        var.aws_profile != null && var.aws_profile != "" ? "--profile" : null,
        var.aws_profile != null && var.aws_profile != "" ? var.aws_profile : null
      ])
    }
  }
}