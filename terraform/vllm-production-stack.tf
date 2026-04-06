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

resource "helm_release" "keda" {
  name             = "keda"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  version          = "2.16.0"
  namespace        = "keda"
  create_namespace = true

  set {
    name  = "resources.operator.requests.cpu"
    value = "100m"
  }
  set {
    name  = "resources.operator.requests.memory"
    value = "128Mi"
  }
  set {
    name  = "resources.operator.limits.memory"
    value = "256Mi"
  }

  depends_on = [module.eks_addons]
}

resource "helm_release" "opentelemetry_collector" {
  name             = "opentelemetry-collector"
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart            = "opentelemetry-collector"
  version          = "0.110.0"
  namespace        = "observability"
  create_namespace = true

  values = [file("${path.module}/config/otel-collector-values.yaml")]

  depends_on = [module.eks_addons]
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
