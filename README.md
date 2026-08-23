# 🏭 Infra Vending Machine

A **Universal Infrastructure-as-Code Vending Machine** for AWS. Teams request cloud resources via GitHub Issues — the platform validates, plans, and applies Terraform using production-hardened modules from `enterprise-infra-module`. No Terraform knowledge required for consumers.

---

## How It Works

```
Team opens GitHub Issue        Platform Ops dispatches        Auto or manual apply
(resource-request template)    validate-resource workflow     (VALIDATE_AND_EXECUTE
         │                              │                       or PLAN_ONLY + merge)
         ▼                              ▼                              │
  Issue labelled             Parse → Validate → Generate              ▼
  resource-request           vend/<name> branch + commit      terraform apply
                             PR opened with plan output       State: S3 per resource
                             Issue commented with status      Issue: apply result
```

### UDAP Actions

| `UDAP_ACTION` | What happens |
|---|---|
| `VALIDATE_AND_EXECUTE` | Plan runs; if clean, PR is auto-merged and `terraform apply` runs immediately |
| `PLAN_ONLY` | Plan runs and PR opens for Platform Ops review; dispatch `apply-resource` after merge |
| `DESTROY` | Generates empty config; apply runs `terraform destroy` for the named resource |

---

## Submitting a Request

1. Go to **Issues → New Issue → Infrastructure Resource Request**
2. Fill in all required fields
3. Submit — issue is labelled `resource-request` automatically
4. Platform Ops dispatches the **validate-resource** workflow from the Actions tab
5. A PR is opened with the Terraform plan; for `VALIDATE_AND_EXECUTE` it auto-merges and applies

### Example Request Fields

| Field | Example |
|---|---|
| Request Name | `customer-api-dev-ec2` |
| UDAP Action | `VALIDATE_AND_EXECUTE` |
| Resource Type | `EC2` |
| Environment | `DEV` |
| AWS Account | `customer-platform-nonprod` |
| Region | `us-east-1` |
| VPC (tag:Name) | `vpc-customer-dev` |
| Subnet (tag:Name) | `private-app-subnet` |
| Instance Type | `t3.medium` |
| Public Access Required | `NO` |

---

## Resource Catalog

| Type | Module | Key Parameters |
|---|---|---|
| `EC2` | `enterprise-infra-module//infra/modules/aws/ec2` | `instance_type`, `public_access`, `root_volume_size` |
| `EKS` | `enterprise-infra-module//infra/modules/aws/eks` | `kubernetes_version`, `node_count`, `instance_type` |

Catalog specs live in `catalog/ec2.yaml` and `catalog/eks.yaml`.

---

## Repository Layout

```
infra-vending-machine/
├── catalog/                   # Resource type definitions (allowed params, defaults)
│   ├── ec2.yaml
│   └── eks.yaml
│
├── engine/                    # Vending machine brain (Python)
│   ├── parse_issue.py         # GitHub Issue form → request YAML
│   ├── validate.py            # Request YAML → catalog schema check
│   ├── generate.py            # Request YAML → Terraform module call
│   ├── open_pr.py             # PR creation / update helper
│   └── templates/             # Jinja2 Terraform templates per resource type
│       ├── ec2.tf.j2
│       ├── eks.tf.j2
│       ├── backend.tf.j2
│       ├── data.tf.j2
│       ├── outputs.tf.j2
│       └── versions.tf.j2
│
├── requests/                  # Audit trail — one YAML per submitted request
│   └── <account>/<env>/<name>.yaml
│
├── generated/                 # Auto-generated Terraform (committed for review)
│   └── <account>/<env>/<name>/
│       ├── main.tf            # Module call → enterprise-infra-module
│       ├── backend.tf         # Empty backend block (flags injected by CI)
│       ├── data.tf            # VPC / subnet data sources
│       ├── versions.tf        # Provider pinning
│       └── outputs.tf         # Useful outputs
│
├── infra/                     # Shared / platform-level Terraform (toggle-gated)
│   ├── ec2.tf                 # Platform EC2 (create_ec2 toggle)
│   ├── eks.tf                 # Platform EKS (create_eks toggle)
│   ├── data.tf                # Shared data sources
│   ├── locals.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   └── terraform.tfvars       # Toggle control panel
│
├── pulumi/                    # Pulumi Go engine (parallel, independent state)
│   ├── main.go
│   ├── Pulumi.yaml
│   └── Pulumi.prod.yaml
│
└── .github/
    ├── ISSUE_TEMPLATE/
    │   └── resource-request.yml   # Team intake form
    └── workflows/
        ├── deploy.yml             # Push to main → Terraform (shared infra)
        ├── destroy.yml            # Manual → terraform destroy (shared infra)
        ├── validate-resource.yml  # Dispatch → validate + plan + PR + auto-apply
        ├── apply-resource.yml     # Dispatch → apply pending PLAN_ONLY requests
        ├── deploy-pulumi.yml      # Dispatch → Pulumi EC2 provision
        └── destroy-pulumi.yml     # Dispatch → Pulumi destroy
```

---

## Workflows Reference

### validate-resource *(dispatch)*
Processes the oldest open `resource-request` issue that does not yet have the `vend-processed` label.

Steps: parse → validate → generate TF → create `vend/<name>-<issue>` branch → terraform plan → open PR with plan → (if `VALIDATE_AND_EXECUTE` and plan clean) merge PR + terraform apply.

### apply-resource *(dispatch)*
For `PLAN_ONLY` requests: after a Platform Ops engineer reviews and merges the `vend/*` PR, dispatch this workflow. It applies every `generated/<account>/<env>/<name>/` directory that does not yet have a `.applied` marker, then commits the markers.

### deploy *(push to main)*
Provisions shared platform infrastructure (toggles in `infra/terraform.tfvars`). All toggles default to `false` — a bare push is always a no-op.

### destroy *(dispatch)*
Tears down all shared platform infrastructure managed by `infra/`.

### deploy-pulumi / destroy-pulumi *(dispatch)*
Parallel Pulumi Go engine for EC2. Requires `PULUMI_ACCESS_TOKEN` secret.

---

## State Management

Each team resource gets its own isolated Terraform state key:

```
s3://<TF_STATE_BUCKET>/<account>/<env>/<request-name>/terraform.tfstate
```

Shared platform infra state:

```
s3://<TF_STATE_BUCKET>/<PROJECT_NAME>/terraform.tfstate
```

Pulumi state is stored in Pulumi Cloud (independent backend, separate from S3).

---

## Modifying or Destroying a Resource

Submit a new issue with the **same Request Name** and:
- `UDAP_ACTION: VALIDATE_AND_EXECUTE` (or `PLAN_ONLY`) to modify parameters
- `UDAP_ACTION: DESTROY` to tear down the resource

The engine identifies the resource by `account/env/request-name` and the correct state key is used automatically.

---

## Platform Ops Setup (one-time)

1. Ensure `TF_STATE_BUCKET`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` secrets are set on the repo
2. For Pulumi: add `PULUMI_ACCESS_TOKEN` secret
3. Create the `resource-request` and `vend-processed` labels in the repo (or let the workflow create `vend-processed` on first run)
4. Optional: add a CODEOWNERS rule so Platform Ops is auto-requested as reviewer on `vend/*` PRs
