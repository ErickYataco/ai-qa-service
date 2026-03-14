module "eks_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.19"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_metrics_server = var.enable_metrics_server

  enable_aws_load_balancer_controller = var.enable_lb_ctl
  aws_load_balancer_controller = {
    wait = true
  }

  enable_aws_efs_csi_driver = var.enable_efs_storage
  aws_efs_csi_driver = {
    most_recent = true
  }

  enable_cert_manager          = false
  enable_external_secrets      = false
  enable_kube_prometheus_stack = var.enable_observability
  enable_karpenter             = false
  enable_cluster_autoscaler    = false
  enable_vpa                   = false

  tags = var.tags
}

locals {
  gpu_selected = lower(var.inference_hardware) == "gpu"
  # Flags for each scenario
  enable_nvidia_operator = contains(["operator_custom", "operator_no_driver"], var.nvidia_setup)
  operator_use_values    = var.nvidia_setup == "operator_custom"
  enable_nvidia_plugin = contains(["plugin"], var.nvidia_setup)

  # Map-style overrides only for the no-driver path
  operator_inline_set = var.nvidia_setup == "operator_no_driver" ? [
    { name = "driver.enabled", value = "false" },
    { name = "toolkit.enabled", value = "false" }
  ] : []
}


module "data_addons" {
  source = "git::https://github.com/cloudthrill/terraform-aws-eks-modules.git//eks-data-addons?ref=v1.0.0"

  # --- required oidc provider arn ---
  oidc_provider_arn = module.eks.oidc_provider_arn

  # --- NVIDIA GPU Setup Selector ---
  # GPU Operator only when hardware inference = gpu *and* user opted for operator
  enable_nvidia_gpu_operator = local.gpu_selected && local.enable_nvidia_operator

  nvidia_gpu_operator_helm_config = local.enable_nvidia_operator ? (
    local.operator_use_values ? {
      version   = "v25.3.1"
      namespace = "gpu-operator"
      values    = [file(var.gpu_operator_file)]
      } : {
      version   = "v25.3.1"
      namespace = "gpu-operator"
      set       = local.operator_inline_set
    }
  ) : null
  depends_on = [module.eks_addons]
  # Device‑plugin only scenario handled via custom_addons in the parent module
enable_nvidia_device_plugin = local.gpu_selected && local.enable_nvidia_plugin
nvidia_device_plugin_helm_config = local.enable_nvidia_plugin ? {
  tolerations = [{
    key      = "nvidia.com/gpu"
    operator = "Exists"
    effect   = "NoSchedule"
  }]
}: null
}