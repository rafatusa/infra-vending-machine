# ---------------------------------------------------------------------------
# infra/terraform.tfvars  —  SHARED INFRA CONTROL PANEL
#
# The Universal Vending Machine handles team resource requests via GitHub
# Issues. This file controls SHARED / PLATFORM-LEVEL resources only.
#
# HOW TO USE:
#   For team resource requests  →  open a GitHub Issue using the
#       "Infrastructure Resource Request" template.
#   For shared platform infra   →  toggle a flag here and push to main.
#
# Every toggle defaults to false — a bare push is always a no-op.
# ---------------------------------------------------------------------------

# ── Global ──────────────────────────────────────────────────────────────────
region      = "us-east-1"
environment = "dev" # dev | staging | production

# ── EC2 Instance  (modules/aws/ec2 + modules/aws/security-group) ─────────────
create_ec2              = false
ec2_instance_type       = "t3.micro"
ec2_ami_id              = "" # leave blank → auto-selects latest Amazon Linux 2023
ec2_root_volume_size    = 30 # AL2023 latest AMI snapshot requires >= 30GB
ec2_associate_public_ip = true
ec2_allowed_ssh_cidrs   = ["0.0.0.0/0"]
ec2_allowed_http_cidrs  = ["0.0.0.0/0"]

# ── EKS Cluster  (modules/aws/eks) ───────────────────────────────────────────
create_eks             = false
eks_kubernetes_version = "1.33"
eks_node_instance_type = "t3.medium"
eks_desired_nodes      = 2
eks_min_nodes          = 1
eks_max_nodes          = 3

# ── VPC  (modules/aws/vpc) ────────────────────────────────────────────────────
create_vpc = false

# ── RDS  (modules/aws/rds) ────────────────────────────────────────────────────
create_rds         = false
rds_engine         = "postgres"
rds_instance_class = "db.t3.micro"

# ── S3  (modules/aws/s3) ──────────────────────────────────────────────────────
create_s3      = false
s3_bucket_name = ""

# ── KMS  (modules/aws/kms) ────────────────────────────────────────────────────
create_kms      = false
kms_description = "Managed by infra-vending-machine"
