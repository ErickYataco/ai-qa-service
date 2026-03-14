locals {
  vllm_values_template = (
    local.gpu_enabled ?
    "${path.module}/config/gpu-smollm2-ingress.tpl" :
    "${path.module}/config/cpu-smollm2-ingress.tpl"
  )
}

resource "kubernetes_namespace" "vllm" {
  metadata {
    name = var.vllm_namespace
  }
}

resource "kubernetes_secret" "hf_token" {
  metadata {
    name      = "hf-token"
    namespace = var.vllm_namespace
  }

  data = {
    HF_TOKEN = var.hf_token
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.vllm]
}

resource "helm_release" "vllm_stack" {
  name             = "vllm"
  repository       = "https://vllm-project.github.io/production-stack"
  chart            = "vllm-stack"
  namespace        = var.vllm_namespace
  create_namespace = false
  timeout          = 1800

  values = [
    file(local.vllm_values_template)
  ]

  depends_on = [
    module.eks_addons,
    kubernetes_namespace.vllm,
    kubernetes_persistent_volume_claim_v1.efs_model_cache_pvc,
  ]
}