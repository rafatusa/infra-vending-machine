# ---------------------------------------------------------------------------
# Global / Core
# ---------------------------------------------------------------------------

variable "project_name" {
  description = "Project name — used as prefix for all resource names and tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must be lowercase alphanumeric with hyphens only."
  }
}

variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (dev / staging / production)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be one of: dev, staging, production."
  }
}

variable "ssh_public_key" {
  description = "SSH public key material — injected by the platform via SSH_PUBLIC_KEY secret."
  type        = string
  default     = ""
  sensitive   = true
}

# ---------------------------------------------------------------------------
# EC2 — toggle + configuration
# ---------------------------------------------------------------------------

variable "create_ec2" {
  description = "Set true to provision an EC2 instance via infra/modules/aws/ec2."
  type        = bool
  default     = false
}

variable "ec2_instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^[a-z][0-9][a-z]?\\.(nano|micro|small|medium|large|xlarge|[0-9]+xlarge)$", var.ec2_instance_type))
    error_message = "Provide a valid EC2 instance type (e.g. t3.micro, m5.large)."
  }
}

variable "ec2_ami_id" {
  description = "AMI ID override. Leave empty to auto-select latest Amazon Linux 2023."
  type        = string
  default     = ""
}

variable "ec2_root_volume_size" {
  description = "Root EBS volume size in GB. AL2023 latest AMI requires >= 30GB."
  type        = number
  default     = 30

  validation {
    condition     = var.ec2_root_volume_size >= 30 && var.ec2_root_volume_size <= 16384
    error_message = "Root volume must be at least 30GB (AL2023 AMI snapshot minimum)."
  }
}

variable "ec2_associate_public_ip" {
  description = "Assign a public IP to the EC2 instance."
  type        = bool
  default     = true
}

variable "ec2_allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH into the EC2 instance."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ec2_allowed_http_cidrs" {
  description = "CIDR blocks allowed on ports 80/443."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------
# VPC — toggle + configuration
# ---------------------------------------------------------------------------

variable "create_vpc" {
  description = "Set true to provision a dedicated VPC via infra/modules/aws/vpc."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# EKS — toggle + configuration
# ---------------------------------------------------------------------------

variable "create_eks" {
  description = "Set true to provision an EKS cluster with a 2-node managed node group."
  type        = bool
  default     = false
}

variable "eks_kubernetes_version" {
  description = "Kubernetes version for the EKS cluster. Must be within EKS standard support window (1.33–1.36 as of August 2026)."
  type        = string
  default     = "1.33"

  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.eks_kubernetes_version))
    error_message = "eks_kubernetes_version must be in the form 1.NN (e.g. 1.33)."
  }
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS managed nodes. t3.medium is the minimum recommended for system pods."
  type        = string
  default     = "t3.medium"
}

variable "eks_desired_nodes" {
  description = "Desired number of nodes in the managed node group."
  type        = number
  default     = 2

  validation {
    condition     = var.eks_desired_nodes >= 1 && var.eks_desired_nodes <= 20
    error_message = "eks_desired_nodes must be between 1 and 20."
  }
}

variable "eks_min_nodes" {
  description = "Minimum number of nodes in the managed node group."
  type        = number
  default     = 1
}

variable "eks_max_nodes" {
  description = "Maximum number of nodes in the managed node group."
  type        = number
  default     = 3
}

# ---------------------------------------------------------------------------
# RDS — toggle + configuration
# ---------------------------------------------------------------------------

variable "create_rds" {
  description = "Set true to provision an RDS instance via infra/modules/aws/rds."
  type        = bool
  default     = false
}

variable "rds_engine" {
  description = "RDS engine type (postgres or mysql)."
  type        = string
  default     = "postgres"

  validation {
    condition     = contains(["postgres", "mysql"], var.rds_engine)
    error_message = "rds_engine must be postgres or mysql."
  }
}

variable "rds_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

# ---------------------------------------------------------------------------
# S3 — toggle + configuration
# ---------------------------------------------------------------------------

variable "create_s3" {
  description = "Set true to provision an S3 bucket with versioning + encryption."
  type        = bool
  default     = false
}

variable "s3_bucket_name" {
  description = "S3 bucket name (must be globally unique)."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# KMS — toggle + configuration
# ---------------------------------------------------------------------------

variable "create_kms" {
  description = "Set true to provision a KMS key with rotation enabled."
  type        = bool
  default     = false
}

variable "kms_description" {
  description = "Description for the KMS key."
  type        = string
  default     = "Managed by infra-vending-machine"
}
