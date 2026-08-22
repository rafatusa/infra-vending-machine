# ---------------------------------------------------------------------------
# EKS Cluster + Managed Node Group
#
# Uses enterprise-infra-module v1.0.0:
#   github.com/rafatusa/enterprise-infra-module//infra/modules/aws/eks?ref=v1.0.0
#
# The module is self-contained — it creates:
#   - aws_iam_role (cluster) + AmazonEKSClusterPolicy attachment
#   - aws_iam_role (node group) + Worker/CNI/ECR policy attachments
#   - aws_eks_cluster
#   - aws_eks_node_group
#
# Subnets:    vpc_subnets.tf (2 public subnets, us-east-1a / us-east-1b)
#
# Toggle: set create_eks = true in terraform.tfvars to provision.
# Default is false — a bare push is always a no-op.
# ---------------------------------------------------------------------------

module "eks" {
  count  = var.create_eks ? 1 : 0
  source = "github.com/rafatusa/enterprise-infra-module//infra/modules/aws/eks?ref=v1.0.0"

  project_name       = var.project_name
  environment        = var.environment
  kubernetes_version = var.eks_kubernetes_version
  subnet_ids         = aws_subnet.eks[*].id

  endpoint_public_access = true
  instance_types         = [var.eks_node_instance_type]
  capacity_type          = "ON_DEMAND"
  desired_size           = var.eks_desired_nodes
  min_size               = var.eks_min_nodes
  max_size               = var.eks_max_nodes
  tags                   = local.common_tags
}
