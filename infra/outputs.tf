# ---------------------------------------------------------------------------
# Outputs — consumed by configure and verify pipeline stages.
# All outputs are conditional: return "none" when the resource is disabled
# so the pipeline never errors on an empty state.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# EC2 outputs — from modules/aws/ec2
# ---------------------------------------------------------------------------

output "ec2_instance_id" {
  description = "AWS instance ID (empty when create_ec2 = false)."
  value       = var.create_ec2 ? try(module.ec2_instance[0].instance_id, "none") : "none"
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance (empty when create_ec2 = false)."
  value       = var.create_ec2 ? try(module.ec2_instance[0].public_ip, "none") : "none"
}

output "ec2_security_group_id" {
  description = "Security group ID attached to the EC2 instance."
  value       = var.create_ec2 ? try(module.ec2_sg[0].security_group_id, "none") : "none"
}

# ---------------------------------------------------------------------------
# EKS outputs — from enterprise-infra-module//infra/modules/aws/eks
# ---------------------------------------------------------------------------

output "eks_cluster_name" {
  description = "EKS cluster name (none when create_eks = false)."
  value       = var.create_eks ? try(module.eks[0].cluster_name, "none") : "none"
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint (none when create_eks = false)."
  value       = var.create_eks ? try(module.eks[0].cluster_endpoint, "none") : "none"
}

output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role (none when create_eks = false)."
  value       = var.create_eks ? try(module.eks[0].cluster_role_arn, "none") : "none"
}

output "eks_node_group_role_arn" {
  description = "ARN of the EKS node group IAM role (none when create_eks = false)."
  value       = var.create_eks ? try(module.eks[0].node_group_role_arn, "none") : "none"
}

output "eks_kubeconfig_cmd" {
  description = "AWS CLI command to configure kubectl for this cluster."
  value       = var.create_eks ? "aws eks update-kubeconfig --region ${var.region} --name ${try(module.eks[0].cluster_name, "none")}" : "none"
}

# ---------------------------------------------------------------------------
# Network outputs
# ---------------------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID used for all resources."
  value       = data.aws_vpc.default.id
}

output "available_subnet_ids" {
  description = "List of existing subnet IDs in the VPC."
  value       = data.aws_subnets.default.ids
}

output "eks_subnet_ids" {
  description = "Subnet IDs used by the EKS cluster (default VPC subnets)."
  value       = var.create_eks ? data.aws_subnets.default.ids : []
}

# ---------------------------------------------------------------------------
# Active resource summary — shows which toggles are on in the verify stage
# ---------------------------------------------------------------------------

output "active_resources" {
  description = "Map of resource type → enabled (true/false). Used by the verify stage."
  value       = local.active_resources
}
