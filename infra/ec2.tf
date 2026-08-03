# ---------------------------------------------------------------------------
# EC2 Resource — via enterprise modules
#
# Module sources (real paths confirmed from repo tree):
#   security-group: github.com/rafatusa/terraform-enterprise-modules//infra/modules/aws/security-group?ref=main
#   ec2:            github.com/rafatusa/terraform-enterprise-modules//infra/modules/aws/ec2?ref=main
#
# Toggle: set create_ec2 = true in terraform.tfvars to provision.
# Default is false — a bare push is always a no-op.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Key Pair — registered from the platform SSH_PUBLIC_KEY secret.
# The ec2 module accepts key_name (an existing key pair); we create the pair
# here so the platform's injected key material seeds the instance.
# ---------------------------------------------------------------------------
resource "aws_key_pair" "ec2" {
  count      = var.create_ec2 ? 1 : 0
  key_name   = "${var.project_name}-ec2-key"
  public_key = var.ssh_public_key

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ec2-key"
  })
}

# ---------------------------------------------------------------------------
# Security Group — using the enterprise security-group module
# Real variables: name, description, vpc_id, ingress_rules, egress_rules,
#                 project, environment, tags
# ---------------------------------------------------------------------------
module "ec2_sg" {
  count  = var.create_ec2 ? 1 : 0
  source = "github.com/rafatusa/terraform-enterprise-modules//infra/modules/aws/security-group?ref=main"

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

  # egress_rules default = allow-all outbound; no override needed
  project     = var.project_name
  environment = var.environment
  tags        = local.common_tags
}

# ---------------------------------------------------------------------------
# EC2 Instance — using the enterprise ec2 module
# Real variables confirmed from infra/modules/aws/ec2/variables.tf:
#   name, ami_id, instance_type, subnet_id, vpc_id, key_name,
#   security_group_ids, associate_public_ip, root_volume_size,
#   root_volume_type, project, environment, tags
# Real outputs: instance_id, instance_arn, private_ip, public_ip, ami_id
# ---------------------------------------------------------------------------
module "ec2_instance" {
  count  = var.create_ec2 ? 1 : 0
  source = "github.com/rafatusa/terraform-enterprise-modules//infra/modules/aws/ec2?ref=main"

  name      = "${var.project_name}-ec2"
  ami_id    = local.resolved_ami
  subnet_id = data.aws_subnets.default.ids[0]
  vpc_id    = data.aws_vpc.default.id

  instance_type       = var.ec2_instance_type
  key_name            = aws_key_pair.ec2[0].key_name
  security_group_ids  = [module.ec2_sg[0].security_group_id]
  associate_public_ip = var.ec2_associate_public_ip

  root_volume_size = var.ec2_root_volume_size
  root_volume_type = "gp3"

  project     = var.project_name
  environment = var.environment
  tags        = local.common_tags
}
