resource "kubernetes_namespace" "apps" {
  metadata {
    name = var.simple_api_namespace
  }
}

resource "helm_release" "simple_api" {
  name             = "simple-api"
  namespace        = var.simple_api_namespace
  create_namespace = false
  chart            = "${path.module}/charts/simple-api"
  timeout          = 900

  values = [
    templatefile("${path.module}/config/simple-api-values.tpl", {
      simple_api_image_repository = var.simple_api_image_repository
      simple_api_image_tag        = var.simple_api_image_tag
      vllm_namespace              = var.vllm_namespace
    })
  ]

  depends_on = [
    module.eks_addons,
    helm_release.vllm_stack
  ]
}