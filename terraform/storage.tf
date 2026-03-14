resource "aws_security_group" "efs" {
  count       = var.enable_efs_storage ? 1 : 0
  name        = "${var.cluster_name}-efs"
  description = "Allow EKS nodes to access EFS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "NFS from VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-efs"
  })
}

resource "aws_efs_file_system" "models" {
  count          = var.enable_efs_storage ? 1 : 0
  creation_token = "${var.cluster_name}-models"
  encrypted      = true

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-models"
  })
}

resource "aws_efs_mount_target" "models" {
  count = var.enable_efs_storage ? length(module.vpc.private_subnets) : 0

  file_system_id  = aws_efs_file_system.models[0].id
  subnet_id       = module.vpc.private_subnets[count.index]
  security_groups = [aws_security_group.efs[0].id]
}

resource "kubernetes_storage_class_v1" "efs" {
  count = var.enable_efs_storage ? 1 : 0

  metadata {
    name = "efs-sc"
  }

  storage_provisioner = "efs.csi.aws.com"

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = aws_efs_file_system.models[0].id
    directoryPerms   = "777"
  }

  mount_options = ["tls"]

  depends_on = [
    module.eks_addons,
    aws_efs_mount_target.models
  ]
}

resource "kubernetes_persistent_volume_claim_v1" "efs_model_cache_pvc" {
  count = var.enable_efs_storage ? 1 : 0

  metadata {
    name      = "llm-model-cache"
    namespace = var.vllm_namespace
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = kubernetes_storage_class_v1.efs[0].metadata[0].name

    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }

  depends_on = [
    kubernetes_namespace.vllm,
    kubernetes_storage_class_v1.efs
  ]
}