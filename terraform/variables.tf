variable "region" {
  type    = string
  default = "us-east-2"
}

variable "aws_profile" {
  type    = string
  default = null
}

variable "cluster_name" {
  type    = string
  default = "ai-demo-eks"
}

variable "cluster_version" {
  type    = string
  default = "1.31"
}

variable "tags" {
  type = map(string)
  default = {
    Project     = "ai-devops-interview"
    Environment = "demo"
    ManagedBy   = "terraform"
  }
}

variable "vpc_cidr" {
  type    = string
  default = "10.60.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.60.0.0/20", "10.60.16.0/20", "10.60.32.0/20"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.60.128.0/20", "10.60.144.0/20", "10.60.160.0/20"]
}

variable "api_public_access" {
  type    = bool
  default = true
}

variable "api_private_access" {
  type    = bool
  default = true
}

variable "api_public_access_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "enable_nat_gateway" {
  type    = bool
  default = true
}

variable "single_nat_gateway" {
  type    = bool
  default = true
}

variable "one_nat_gateway_per_az" {
  type    = bool
  default = false
}

variable "cpu_root_volume_size" {
  description = "Root EBS volume size for CPU nodes"
  type        = number
  default     = 100
}

variable "gpu_root_volume_size" {
  description = "Root EBS volume size for CPU nodes"
  type        = number
  default     = 100
}

variable "cpu_node_instance_types" {
  type    = list(string)
  default = ["m6i.large"]
}

variable "cpu_node_min_size" {
  type    = number
  default = 2
}

variable "cpu_node_desired_size" {
  type    = number
  default = 2
}

variable "cpu_node_max_size" {
  type    = number
  default = 4
}

variable "gpu_node_instance_types" {
  type    = list(string)
  default = ["g5.xlarge"]
}

variable "gpu_node_min_size" {
  type    = number
  default = 1
}

variable "gpu_node_desired_size" {
  type    = number
  default = 1
}

variable "gpu_node_max_size" {
  type    = number
  default = 2
}

variable "gpu_capacity_type" {
  type    = string
  default = "ON_DEMAND"
}

variable "enable_cluster_creator_admin_permissions" {
  type    = bool
  default = true
}

variable "enable_lb_ctl" {
  type    = bool
  default = true
}

variable "enable_metrics_server" {
  type    = bool
  default = true
}

variable "enable_efs_storage" {
  type    = bool
  default = true
}

variable "enable_vllm" {
  type    = bool
  default = true
}

variable "enable_observability" {
  type    = bool
  default = false
}

variable "hf_token" {
  type      = string
  sensitive = true
}

variable "vllm_namespace" {
  type    = string
  default = "vllm"
}

variable "simple_api_namespace" {
  type    = string
  default = "apps"
}

variable "simple_api_image_repository" {
  type    = string
  default = "docker.io/erickyataco/llm-api"
}

variable "simple_api_image_tag" {
  type    = string
  default = "v2"
}

variable "inference_hardware" {
  description = "Inference hardware profile: cpu or gpu"
  type        = string
  default     = "cpu"

  validation {
    condition     = contains(["cpu", "gpu"], lower(var.inference_hardware))
    error_message = "inference_hardware must be either 'cpu' or 'gpu'."
  }
}

variable "nvidia_setup" {
  description = <<EOT
GPU enablement strategy:
  • "plugin"           → installs only the nvidia-device-plugin DaemonSet
  • "operator_custom"  → GPU Operator with your YAML values file
  • "operator_no_driver" → GPU Operator, driver & toolkit pods disabled (map-style set)
EOT
  type        = string
  default     = "plugin"

  validation {
    condition     = contains(["plugin", "operator_custom", "operator_no_driver"], lower(var.nvidia_setup))
    error_message = "Valid values: plugin | operator_custom | operator_no_driver"
  }
}

variable "gpu_operator_file" {
  description = "Path to GPU Operator Helm values YAML."
  type        = string
  default     = "config/gpu-operator-values.yaml"
}