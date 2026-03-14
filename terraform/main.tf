locals {
  inference_hardware_normalized = lower(var.inference_hardware)
  gpu_enabled                   = local.inference_hardware_normalized == "gpu"

  node_groups_map = merge(
    {
      cpu = {
        min_size       = var.cpu_node_min_size
        max_size       = var.cpu_node_max_size
        desired_size   = var.cpu_node_desired_size
        ami_type       = "AL2023_x86_64_STANDARD"
        instance_types = var.cpu_node_instance_types
        capacity_type  = "ON_DEMAND"
        subnet_ids     = module.vpc.private_subnets

        block_device_mappings = {
          xvda = {
            device_name = "/dev/xvda"
            ebs = {
              volume_size           = var.cpu_root_volume_size
              volume_type           = "gp3"
              encrypted             = true
              delete_on_termination = true
            }
          }
        }

        labels = {
          "workload-type" = "cpu"
          "node-group"    = "cpu-pool"
        }
      }
    },
    local.gpu_enabled ? {
      gpu = {
        min_size       = var.gpu_node_min_size
        max_size       = var.gpu_node_max_size
        desired_size   = var.gpu_node_desired_size
        ami_type       = "AL2023_x86_64_NVIDIA"
        instance_types = var.gpu_node_instance_types
        capacity_type  = var.gpu_capacity_type
        subnet_ids     = module.vpc.private_subnets

        block_device_mappings = {
          xvda = {
            device_name = "/dev/xvda"
            ebs = {
              volume_size           = var.gpu_root_volume_size
              volume_type           = "gp3"
              encrypted             = true
              delete_on_termination = true
            }
          }
        }

        labels = {
          "workload-type" = "gpu"
          "node-group"    = "gpu-pool"
        }

        taints = [{
          key    = "nvidia.com/gpu"
          value  = "true"
          effect = "NO_SCHEDULE"
        }]
      }
    } : {}
  )
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access       = var.api_public_access
  cluster_endpoint_private_access      = var.api_private_access
  cluster_endpoint_public_access_cidrs = var.api_public_access_cidrs

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa                              = true
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions
  eks_managed_node_groups                  = local.node_groups_map

  create_kms_key = false
  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = data.aws_kms_key.eks_managed_key.arn
  }

  cluster_enabled_log_types   = []
  create_cloudwatch_log_group = false

  tags = var.tags
}