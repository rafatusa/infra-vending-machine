# ---------------------------------------------------------------------------
# EC2 Resource — via enterprise-infra-module v1.0.0
#
# Module sources:
#   security-group: github.com/rafatusa/enterprise-infra-module//infra/modules/aws/security-group?ref=v1.0.0
#   ec2:            github.com/rafatusa/enterprise-infra-module//infra/modules/aws/ec2?ref=v1.0.0
#
# Toggle: set create_ec2 = true in terraform.tfvars to provision.
# Default is false — a bare push is always a no-op.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Security Group — v1.0.0 interface
# Accepted: project_name, environment, name, description, vpc_id,
#           ingress_rules, egress_rules, tags
# ---------------------------------------------------------------------------
module "ec2_sg" {
  count  = var.create_ec2 ? 1 : 0
  source = "github.com/rafatusa/enterprise-infra-module//infra/modules/aws/security-group?ref=v1.0.0"

  project_name = var.project_name
  environment  = var.environment
  name         = "${var.project_name}-ec2-sg"
  description  = "Security group for ${var.project_name} EC2 instance"
  vpc_id       = data.aws_vpc.default.id

  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ec2_allowed_ssh_cidrs
      description = "SSH"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = var.ec2_allowed_http_cidrs
      description = "HTTP"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.ec2_allowed_http_cidrs
      description = "HTTPS"
    },
  ]

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# EC2 Instance — v1.0.0 interface
# Accepted: project_name, environment, ami_id, instance_type, subnet_id,
#           security_group_ids, ssh_public_key, iam_instance_profile,
#           root_volume_type, root_volume_size, tags
# ---------------------------------------------------------------------------
module "ec2_instance" {
  count  = var.create_ec2 ? 1 : 0
  source = "github.com/rafatusa/enterprise-infra-module//infra/modules/aws/ec2?ref=v1.0.0"

  project_name = var.project_name
  environment  = var.environment

  ami_id             = local.resolved_ami
  instance_type      = var.ec2_instance_type
  subnet_id          = data.aws_subnets.default.ids[0]
  security_group_ids = [module.ec2_sg[0].security_group_id]
  ssh_public_key     = var.ssh_public_key

  root_volume_size = var.ec2_root_volume_size

  tags = local.common_tags
}
