# ci-cd-terragrunt-research-v2

Terragrunt-based infrastructure with full CI/CD via GitHub Actions and self-hosted runners.

## Architecture

```
environments/dev/us-east-1/
├── vpc/    → VPC + Subnets + IGW + Route Tables + Security Groups (1 state)
└── ec2/    → EC2 instances + EBS volumes + ALB + Target Group (1 state)
```

**Modules** are co-located inside this repo under `modules/` — no separate SSH key needed.

## Stack

| Component | Details |
|-----------|---------|
| Terraform | >= 1.11.0 |
| Terragrunt | >= 1.0.4 |
| AWS Provider | >= 6.0 |
| State Backend | S3 + native locking (`use_lockfile = true`) |
| CI Runner | Self-hosted EC2 (Ubuntu 24.04) |
| Auth (CI) | GitHub OIDC → `GitHubActionRole` |

## Bootstrap Order

Run these **once** before CI/CD is active:

```bash
# 1. Create S3 state bucket + GitHub OIDC provider + IAM role (single state).
#    Config is split by component: backend.tf, oidc.tf
#    (shared versions.tf / providers.tf / outputs.tf).
cd bootstrap
terraform init && terraform apply

# 2. Launch self-hosted runner EC2
cd runner
# Edit terraform.tfvars: set runner_token (get from GitHub → Settings → Actions → Runners → New)
terraform init && terraform apply
```

## CI/CD Workflows

| Workflow | Trigger | Action |
|----------|---------|--------|
| `pr-plan.yml` | PR to `main` touching `environments/**` | `terragrunt plan` per changed unit |
| `merge-apply.yml` | Push to `main` touching `environments/**` | `terragrunt run --all -- apply` per region |

## Local Development

```bash
# Configure AWS profile
aws configure --profile cloud_user

# Plan a specific unit
cd environments/dev/us-east-1/vpc
terragrunt plan

# Apply locally (uses local backend by default override)
USE_LOCAL_BACKEND=true terragrunt apply
```

## Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| *(none — uses OIDC)* | OIDC auth via `GitHubActionRole` |
