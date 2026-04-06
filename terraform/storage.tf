resource "aws_security_group" "efs_access" {
  count       = var.enable_efs_storage ? 1 : 0
  name        = "${var.cluster_name}-efs-access"
  description = "Allow EKS nodes to access EFS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow NFS traffic from VPC"
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
    Name = "${var.cluster_name}-efs-access"
  })
}

resource "aws_efs_file_system" "models" {
  count          = var.enable_efs_storage ? 1 : 0
  creation_token = "${var.cluster_name}-models"
  encrypted      = true

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-efs-models"
  })
}

resource "aws_efs_mount_target" "models" {
  count = var.enable_efs_storage ? length(module.vpc.private_subnets) : 0

  file_system_id  = aws_efs_file_system.models[0].id
  subnet_id       = module.vpc.private_subnets[count.index]
  security_groups = [aws_security_group.efs_access[0].id]
}

resource "kubernetes_storage_class_v1" "efs_storage_class" {
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

resource "kubernetes_persistent_volume_v1" "efs_persistent_volume" {
  metadata {
    name = "efs-pv"
  }

  spec {
    capacity = {
      storage = "40Gi"
    }

    volume_mode                      = "Filesystem"
    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"

    persistent_volume_source {
      csi {
        driver        = "efs.csi.aws.com"
        volume_handle = aws_efs_file_system.models[0].id  # Reference to the EFS filesystem
      }
    }
  }

  depends_on = [
    aws_efs_file_system.models,        # EFS filesystem must exist first
    aws_efs_mount_target.models,       # Mount targets must be ready
    module.eks_addons,                 # Ensure EFS CSI driver is installed
  ]
}
