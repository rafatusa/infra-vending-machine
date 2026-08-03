locals {
  # -------------------------------------------------------------------------
  # Common tags — applied to every resource via merge(local.common_tags, {...})
  # ManagedBy=terraform is REQUIRED by the enterprise module contract.
  # The enterprise modules auto-inject ManagedBy and Module; we set the rest.
  # -------------------------------------------------------------------------
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "infra-vending-machine"
  }

  # -------------------------------------------------------------------------
  # AMI resolution — user-supplied override wins; falls back to latest AL2023
  # -------------------------------------------------------------------------
  resolved_ami = var.ec2_ami_id != "" ? var.ec2_ami_id : data.aws_ami.amazon_linux_2023.id

  # -------------------------------------------------------------------------
  # Active resource summary — used in outputs for pipeline visibility
  # -------------------------------------------------------------------------
  active_resources = {
    ec2 = var.create_ec2
    rds = var.create_rds
    s3  = var.create_s3
    kms = var.create_kms
    vpc = var.create_vpc
  }
}
