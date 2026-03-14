data "aws_caller_identity" "current" {}

data "aws_kms_key" "eks_managed_key" {
  key_id = "alias/aws/eks"
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}