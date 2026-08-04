# ---------------------------------------------------------------------------
# infra/terraform.tfvars  —  YOUR CONTROL PANEL
#
# HOW TO USE:
#   1. Set the toggle for the resource you want (e.g. create_ec2 = true)
#   2. Fill in the configuration below it
#   3. Push to main  →  the pipeline runs plan → apply automatically
#   4. To destroy:   set the toggle back to false and push
#                    OR dispatch the Destroy workflow from GitHub Actions
#
# Every toggle defaults to false — a bare push is always a no-op.
# ---------------------------------------------------------------------------

# ── Global ──────────────────────────────────────────────────────────────────
region      = "us-east-1"
environment = "dev" # dev | staging | production

# ── EC2 Instance  (modules/aws/ec2 + modules/aws/security-group) ─────────────
# Set create_ec2 = true and push to provision an EC2 instance.
create_ec2              = true
ec2_instance_type       = "t3.micro"
ec2_ami_id              = "" # leave blank → auto-selects latest Amazon Linux 2023
ec2_root_volume_size    = 30 # AL2023 latest AMI snapshot requires >= 30GB
ec2_associate_public_ip = true

# Restrict SSH to your IP for better security (replace with your CIDR):
ec2_allowed_ssh_cidrs  = ["0.0.0.0/0"]
ec2_allowed_http_cidrs = ["0.0.0.0/0"]

# ── VPC  (modules/aws/vpc) ────────────────────────────────────────────────────
# Set create_vpc = true when you need a dedicated VPC instead of the default one.
# Requires infra/vpc.tf — ask the agent to add it.
create_vpc = false

# ── RDS  (modules/aws/rds) ────────────────────────────────────────────────────
# Set create_rds = true to provision a Postgres or MySQL RDS instance.
# Requires infra/rds.tf — ask the agent to add it.
create_rds         = false
rds_engine         = "postgres" # postgres | mysql
rds_instance_class = "db.t3.micro"

# ── S3  (modules/aws/s3) ──────────────────────────────────────────────────────
# Set create_s3 = true to provision an S3 bucket with versioning + encryption.
# Requires infra/s3.tf — ask the agent to add it.
create_s3      = false
s3_bucket_name = "" # must be globally unique; leave empty to auto-generate

# ── KMS  (modules/aws/kms) ────────────────────────────────────────────────────
# Set create_kms = true to provision a KMS key with rotation enabled.
# Requires infra/kms.tf — ask the agent to add it.
create_kms      = false
kms_description = "Managed by infra-vending-machine"
