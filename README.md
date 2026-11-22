# terraform-finops-spike

A small Terraform project on AWS that builds FinOps (cloud cost management) practices into the infrastructure code: budgets, anomaly detection, cost allocation tags, cost-aware modules, remote state, and cost estimates on pull requests with Infracost.

It started from HashiCorp's "Get Started - AWS" tutorial and grew from there. See [docs/DECISIONS.md](docs/DECISIONS.md) for the problems I hit and the reasoning behind each design choice.

## What it builds

The project is split into three Terraform roots. Each has its own state, so they can be created and destroyed separately.

| Root | Creates | State stored in |
|---|---|---|
| `guardrails/` | A $15/month AWS Budget (measured before credits) and a Cost Anomaly Detection monitor with daily email alerts | Local file |
| `bootstrap/` | The S3 bucket that holds Terraform state for the main project | Local file |
| `.` (main) | An S3 bucket and one EC2 instance, built from two local modules | S3 bucket created by `bootstrap/` |

All resources are in `ap-southeast-2` (Sydney) and carry the same tags through the AWS provider's `default_tags`: `Owner`, `CostCentre`, `Environment` and `Project`.

## Layout

```
.
├── guardrails/            # budget and anomaly detection
├── bootstrap/             # state bucket for the main project
├── modules/
│   ├── storage/           # S3 bucket: encryption, versioning, lifecycle rule
│   └── compute/           # EC2 instance: gp3 root volume, no public IP
├── main.tf                # calls the storage and compute modules
├── variables.tf
├── outputs.tf
├── terraform.tf           # provider, default_tags, S3 backend
├── docs/DECISIONS.md      # incidents and design decisions
└── .github/workflows/     # Infracost on pull requests and on main
```

## FinOps practices in this project

- **Budget before credits:** the budget ignores promotional credits, so it shows real usage instead of $0.
- **Anomaly detection:** flags unusual spend per AWS service, not just a fixed limit.
- **Cost allocation tags:** every resource is tagged automatically, and the tags are activated in Billing so costs can be grouped by them.
- **S3 lifecycle rule:** old object versions are deleted after 30 days, objects move to Infrequent Access after 30 days, and failed uploads are cleaned up after 7 days.
- **Instance type allow-list:** the compute module only accepts `t3.micro`, `t3.small`, `t4g.micro` and `t4g.small`.
- **No public IP:** avoids the $0.005/hour public IPv4 charge.
- **No leftover disks:** the root volume is deleted with the instance.
- **Rightsizing:** moved from `t3.micro` to Graviton `t4g.micro`, checked with Infracost before applying (about 20% cheaper).
- **Cost estimates on pull requests:** Infracost comments on each PR with the monthly cost change.

## Requirements

- Terraform 1.10 or later (needed for S3 state locking with `use_lockfile`)
- AWS CLI with credentials for an IAM user or SSO profile, not the root account
- Optional: [Infracost CLI](https://www.infracost.io/) for local cost estimates

## Setup

Run each root in this order.

### 1. Guardrails

```sh
cd guardrails
cp terraform.tfvars.example terraform.tfvars   # then add your email address
terraform init
terraform apply
```

`terraform.tfvars` is ignored by git, so the email address stays out of the repo.

### 2. Bootstrap

```sh
cd bootstrap
terraform init
terraform apply
```

This creates a state bucket named `finops-spike-tfstate-<account-id>`.

### 3. Main project

The `backend "s3"` block in `terraform.tf` contains the state bucket name. Terraform does not allow variables there, so if you use a different AWS account, update the bucket name to match the one `bootstrap/` created.

```sh
terraform init
terraform plan
terraform apply
```

## Variables

### Main project

| Name | Default | Description |
|---|---|---|
| `instance_type` | `t4g.micro` | EC2 instance type (must be on the allow-list) |
| `instance_name` | `terraform-spike` | Value of the instance's `Name` tag |

The compute module also has `root_volume_size_gb` (default 8, allowed 8 to 20), `associate_public_ip` (default `false`) and `availability_zone` (default `ap-southeast-2a`).

### Guardrails

| Name | Default | Description |
|---|---|---|
| `alert_email` | none (set in `terraform.tfvars`) | Email address for budget and anomaly alerts |
| `monthly_budget_usd` | `15` | Monthly budget in USD |

## Outputs

| Root | Output | Description |
|---|---|---|
| Main | `bucket_name` | Name of the S3 data bucket |
| Main | `instance_id` | ID of the EC2 instance |
| Bootstrap | `state_bucket_name` | Name of the state bucket |

## Cost

Infracost estimate for the main project:

| Resource | Monthly |
|---|---|
| EC2 `t4g.micro` (730 hours) | about $7.74 |
| 8 GB gp3 root volume | about $0.77 |
| S3 buckets | depends on usage, close to $0 here |
| **Total** | **about $8.50** |

The budget and anomaly monitor are free. The EC2 instance is billed for as long as it runs, so destroy it when you are done.

## Infracost

Run locally from the project root:

```sh
infracost scan            # cost breakdown and policy checks
infracost diff            # cost change compared with the last scan
```

Two GitHub Actions workflows were generated with `infracost ci setup --pipeline`:

| Workflow | Runs on | What it does |
|---|---|---|
| `infracost-diff.yml` | Pull requests | Compares the PR with the base branch and comments the cost change on the PR |
| `infracost-scan.yml` | Pushes to `main` | Scans the main branch |

Both need an Infracost API key stored as the GitHub secret `INFRACOST_API_KEY`.

**Known issue:** Infracost 2.20 hangs on any project that contains a `terraform.tfvars` file (here, `guardrails/`). Locally, move the file out of the repo while scanning. In CI this does not happen, because the file is not committed.

## Teardown

```sh
terraform destroy                 # main project
cd guardrails && terraform destroy   # optional: budget and anomaly monitor are free to keep
```

The state bucket is protected by `prevent_destroy` and versioning. To remove it, first destroy the main project, then remove `prevent_destroy` from `bootstrap/main.tf`, empty the bucket (including old versions), and run `terraform destroy` in `bootstrap/`.
