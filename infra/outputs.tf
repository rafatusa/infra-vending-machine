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
# Network outputs
# ---------------------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID used for all resources (default VPC unless create_vpc=true)."
  value       = data.aws_vpc.default.id
}

output "available_subnet_ids" {
  description = "List of subnet IDs available in the VPC."
  value       = data.aws_subnets.default.ids
}

# ---------------------------------------------------------------------------
# Active resource summary — shows which toggles are on in the verify stage
# ---------------------------------------------------------------------------

output "active_resources" {
  description = "Map of resource type → enabled (true/false). Used by the verify stage."
  value       = local.active_resources
}
