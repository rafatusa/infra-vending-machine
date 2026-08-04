# ---------------------------------------------------------------------------
# EC2 Resource — via enterprise-infra-module
#
# Module sources (rafatusa/enterprise-infra-module v1.1.0):
#   security-group: github.com/rafatusa/enterprise-infra-module//infra/modules/aws/security-group?ref=v1.1.0
#   ec2:            github.com/rafatusa/enterprise-infra-module//infra/modules/aws/ec2?ref=v1.1.0
#
# Toggle: set create_ec2 = true in terraform.tfvars to provision.
# Default is false — a bare push is always a no-op.
#
# NOTE: The ec2 module accepts ssh_public_key directly — it manages the
# aws_key_pair resource internally. No raw aws_key_pair needed here.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Security Group — using the enterprise security-group module
# Inputs: name, description, vpc_id, ingress_rules, egress_rules,
#         project, environment, tags
# Outputs: security_group_id, security_group_arn, security_group_name
# ---------------------------------------------------------------------------
module "ec2_sg" {
  count  = var.create_ec2 ? 1 : 0
  source = "github.com/rafatusa/enterprise-infra-module//infra/modules/aws/security-group?ref=v1.1.0"

  name        = "${var.project_name}-ec2-sg"
  description = "Security group for ${var.project_name} EC2 instance"
  vpc_id      = data.aws_vpc.default.id

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

  project     = var.project_name
  environment = var.environment
  tags        = local.common_tags
}

# ---------------------------------------------------------------------------
# EC2 Instance — using the enterprise ec2 module
# Inputs: name, ami_id, instance_type, subnet_id, vpc_id, ssh_public_key,
#         security_group_ids, associate_public_ip, root_volume_size,
#         project, environment, tags
# Outputs: instance_id, public_ip, private_ip, security_group_id
# ---------------------------------------------------------------------------
module "ec2_instance" {
  count  = var.create_ec2 ? 1 : 0
  source = "github.com/rafatusa/enterprise-infra-module//infra/modules/aws/ec2?ref=v1.1.0"

  name      = "${var.project_name}-ec2"
  ami_id    = local.resolved_ami
  subnet_id = data.aws_subnets.default.ids[0]
  vpc_id    = data.aws_vpc.default.id

  instance_type       = var.ec2_instance_type
  ssh_public_key      = var.ssh_public_key
  security_group_ids  = [module.ec2_sg[0].security_group_id]
  associate_public_ip = var.ec2_associate_public_ip

  root_volume_size = var.ec2_root_volume_size

  project     = var.project_name
  environment = var.environment
  tags        = local.common_tags
}
