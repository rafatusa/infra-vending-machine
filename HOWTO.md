# How to Request Infrastructure

This document is your step-by-step guide for every supported resource type.

---

## General Workflow

1. **Edit** `infra/terraform.tfvars` — flip the resource toggle to `true`
2. **Commit and push** to `main`
3. **Watch the pipeline** in the GitHub Actions tab
4. **Get the result** from the `verify` step output (IPs, IDs, etc.)
5. **To destroy**: flip the toggle back to `false` and push again

---

## EC2 Instance

### Create

```hcl
# infra/terraform.tfvars
create_ec2            = true
ec2_instance_type     = "t3.micro"    # Change size here
ec2_ami_id            = ""            # blank = latest Amazon Linux 2023
ec2_root_volume_size  = 20            # GB
ec2_associate_public_ip = true

# Restrict SSH access (replace with your IP/CIDR for security):
allowed_ssh_cidrs = ["0.0.0.0/0"]
```

Commit & push. After ~3 minutes the `verify` stage will print:
```
Resources in state: 3
  - aws_key_pair.this (registry.terraform.io/hashicorp/aws)
  - aws_security_group.ec2 (registry.terraform.io/hashicorp/aws)
  - module.ec2_instance (...)
```

### SSH into the Instance

```bash
# Get the IP from the verify stage output, then:
ssh -i ~/.ssh/your-key ec2-user@<INSTANCE_IP>
```

### Change Instance Type

Edit `ec2_instance_type` and push — Terraform will replace the instance.

### Destroy

```hcl
create_ec2 = false
```

Commit & push. The instance, key pair, and security group are all removed.

---

## Adding a New Resource (request it from the AI)

Just ask! For example:
- *"Add an RDS PostgreSQL instance"*
- *"Add an S3 bucket for uploads"*
- *"Add a VPC with private subnets"*

The agent will:
1. Add the module call in `infra/<resource>.tf`
2. Add the toggle variable in `infra/variables.tf`
3. Add the toggle to `terraform.tfvars` (defaulting to `false`)
4. Update `outputs.tf` and this guide

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Pipeline fails at `lint` | Run `terraform fmt -recursive infra/` locally |
| `Error: Module not found` | Check the module path in `ec2.tf` matches the repo structure |
| `Error: Invalid instance type` | Check available types in your region: `aws ec2 describe-instance-type-offerings` |
| `Permission denied (publickey)` | The platform manages SSH keys — re-trigger the pipeline to refresh the key pair |
| Resources not destroyed | Run the **Destroy** workflow from GitHub Actions → Actions tab |
