# Project Notes — infra-vending-machine

## What This Is
A Terraform IaC orchestration repo ("vending machine") where the user requests AWS resources
by editing terraform.tfvars and pushing. The pipeline (GitHub Actions via UDAP) handles
plan → apply → verify using modules from rafatusa/terraform-enterprise-modules.

## Key Decisions
- **Pure IaC project** — no application runtime, no scaffold, no web server
- **Toggle pattern** — every resource type has a `create_<resource>` bool variable defaulting to false
  so a bare push never creates anything until explicitly opted in
- **Module source** — using github.com/rafatusa/terraform-enterprise-modules//modules/ec2?ref=main
  IMPORTANT: the exact sub-module path (modules/ec2) was inferred from the README link.
  If it differs, update the source in infra/ec2.tf
- **Default VPC** — probe confirmed vpc-06e83f344275bbd92 exists; using data sources, not recreating
- **AMI** — data source for latest Amazon Linux 2023 (al2023-ami-*-x86_64); SSH_USER = ec2-user
- **State** — empty S3 backend block; bucket/key/region from platform secrets via -backend-config

## Module Repo Assumptions
- Module org: rafatusa/terraform-enterprise-modules
- EC2 module path assumed: //modules/ec2
- Expected inputs: instance_type, ami_id, subnet_id, key_name, security_group_ids,
  associate_public_ip_address, root_volume_size, tags
- Expected outputs: public_ip, instance_id
- IF the module interface differs, user must update infra/ec2.tf to match actual variable names

## AWS Account
- Account: 241533126054 (user: talha)
- Region: us-east-1
- Default VPC: vpc-06e83f344275bbd92 (6 subnets)
- EC2 quota: 64 vCPUs on-demand standard

## Pipeline Stages
1. lint — terraform fmt check + validate (backend=false for validate)
2. provision — terraform init (with state backend) + plan + apply
3. configure — re-init + confirm outputs (self-sufficient job, reads own terraform output)
4. verify — re-init + terraform show -json → prints all resources in state
5. destroy (separate workflow) — init + destroy

## Potential Day-2 Additions
- RDS: add infra/rds.tf + create_rds toggle
- S3: add infra/s3.tf + create_s3 toggle
- VPC: add infra/vpc.tf + create_vpc toggle (replace default VPC usage)
- Azure Key Vault: once Azure is connected, add azurerm provider to versions.tf
- Cost gate: add infracost in lint stage
- Policy gate: add OPA/Conftest step in lint stage

## Status
- [ ] Repo created
- [ ] First deploy run
