# infra-vending-machine

> **Ask for a resource. Get it provisioned.** An IaC orchestration platform that
> calls [`rafatusa/terraform-enterprise-modules`](https://github.com/rafatusa/terraform-enterprise-modules)
> to create, modify and destroy AWS infrastructure — with a full CI/CD pipeline.

## How It Works

```
You edit terraform.tfvars  →  push to main  →  GitHub Actions pipeline runs
  └─ lint (fmt + validate)
  └─ provision (terraform plan → apply)      ← calls enterprise modules
  └─ configure (reads outputs, confirms state)
  └─ verify (terraform show → lists all resources)
```

To destroy everything: dispatch the **Destroy** workflow from GitHub Actions → Actions tab.

---

## Module Catalog

This repo is a **caller** — it never writes raw AWS resources from scratch.
Every resource type maps to an enterprise module:

| Resource | Module Path | Toggle |
|----------|-------------|--------|
| EC2 instance | `modules/aws/ec2` | `create_ec2 = true` |
| Security Group | `modules/aws/security-group` | auto (with EC2) |
| VPC | `modules/aws/vpc` | `create_vpc = true` |
| RDS (Postgres/MySQL) | `modules/aws/rds` | `create_rds = true` |
| S3 bucket | `modules/aws/s3` | `create_s3 = true` |
| KMS key | `modules/aws/kms` | `create_kms = true` |

> Modules are pinned by git tag (`?ref=v1.0.0`) — never by branch.

---

## Quickstart

### Provision an EC2 instance

1. Open `infra/terraform.tfvars`
2. Set:
   ```hcl
   create_ec2        = true
   ec2_instance_type = "t3.micro"   # or whatever size you need
   ```
3. Commit and push to `main`
4. Watch the pipeline: **Actions → deploy**

### Destroy the EC2 instance

Option A — toggle off:
```hcl
create_ec2 = false
```
Push → the pipeline removes the resource.

Option B — full teardown:
GitHub Actions → **Actions** → **destroy** → **Run workflow**

---

## Control Panel (`infra/terraform.tfvars`)

```hcl
# Global
region      = "us-east-1"
environment = "dev"          # dev | staging | production

# EC2
create_ec2              = false
ec2_instance_type       = "t3.micro"
ec2_root_volume_size    = 20
ec2_associate_public_ip = true
ec2_allowed_ssh_cidrs   = ["0.0.0.0/0"]

# RDS (requires infra/rds.tf)
create_rds    = false
rds_engine    = "postgres"

# S3 (requires infra/s3.tf)
create_s3      = false
s3_bucket_name = ""

# KMS (requires infra/kms.tf)
create_kms = false
```

---

## Adding a New Resource Type

Ask the agent: *"Add an RDS instance"* and it will:
1. Create `infra/rds.tf` calling `modules/aws/rds`
2. Add variables + outputs
3. Update `terraform.tfvars` with the toggle
4. Update the pipeline if needed

---

## Enterprise Standards (enforced by the module library)

| Standard | Implementation |
|----------|---------------|
| Encryption at rest | KMS-managed EBS + S3 |
| Least-privilege IAM | Scoped policies via `modules/aws/iam-role` |
| Tagging | `ManagedBy=terraform`, `Module=<path>` auto-applied |
| Input validation | `validation {}` blocks on critical variables |
| Version pinning | Modules pinned to `?ref=v1.0.0` |

---

## Repository Layout

```
infra/
  versions.tf      # provider + backend (empty S3 block — bucket injected by platform)
  data.tf          # data sources (default VPC, subnets, latest AL2023 AMI)
  locals.tf        # common_tags, AMI resolution
  variables.tf     # all variables with validation blocks
  ec2.tf           # module "ec2_sg" + module "ec2_instance"
  outputs.tf       # all outputs (conditional — "none" when disabled)
  terraform.tfvars # YOUR CONTROL PANEL
```
