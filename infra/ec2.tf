# ---------------------------------------------------------------------------
# EC2 Resource — via enterprise module
#
# Module source: github.com/rafatusa/terraform-enterprise-modules
# Path:          modules/aws/ec2   (AWS modules live under modules/aws/)
# Pin:           ?ref=main         (repo uses main branch; update to a tag once
#                                   the upstream cuts a release, e.g. ?ref=v1.0.0)
#
# Toggle: set create_ec2 = true in terraform.tfvars to provision.
# Default is false — a bare push is always a no-op.
#
# Two enterprise modules are composed:
#   1. modules/aws/security-group  → creates the SG with rule maps
#   2. modules/aws/ec2             → creates the instance; receives the SG id
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Security Group — using the enterprise security-group module
# ---------------------------------------------------------------------------
module "ec2_sg" {
  count  = var.create_ec2 ? 1 : 0
  source = "github.com/rafatusa/terraform-enterprise-modules//modules/aws/security-group?ref=main"

  name        = "${var.project_name}-ec2-sg"
  description = "Security group for ${var.project_name} EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  ingress_rules = [
    {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ec2_allowed_ssh_cidrs
    },
    {
      description = "HTTP"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = var.ec2_allowed_http_cidrs
    },
    {
      description = "HTTPS"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.ec2_allowed_http_cidrs
    },
  ]

  egress_rules = [
    {
      description = "All outbound"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    },
  ]

  tags = merge(local.common_tags, {
    Name   = "${var.project_name}-ec2-sg"
    Module = "modules/aws/security-group"
  })
}

# ---------------------------------------------------------------------------
# EC2 Instance — using the enterprise ec2 module
# The module handles SSM agent, EBS encryption, and key pair internally.
# ---------------------------------------------------------------------------
module "ec2_instance" {
  count  = var.create_ec2 ? 1 : 0
  source = "github.com/rafatusa/terraform-enterprise-modules//modules/aws/ec2?ref=main"

  # Identity
  name    = "${var.project_name}-ec2"
  project = var.project_name

  # Compute
  instance_type = var.ec2_instance_type
  ami_id        = local.resolved_ami
  subnet_id     = data.aws_subnets.default.ids[0]

  # Networking
  security_group_ids          = [module.ec2_sg[0].security_group_id]
  associate_public_ip_address = var.ec2_associate_public_ip

  # Storage — module enforces EBS encryption at rest (enterprise standard)
  root_volume_size = var.ec2_root_volume_size
  root_volume_type = "gp3"

  # SSH key — platform injects SSH_PUBLIC_KEY secret; module registers the key pair
  ssh_public_key = var.ssh_public_key

  # Enterprise tags — ManagedBy + Module are required by the module contract
  tags = merge(local.common_tags, {
    Name        = "${var.project_name}-ec2"
    Module      = "modules/aws/ec2"
    Environment = var.environment
  })
}
