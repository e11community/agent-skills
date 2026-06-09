# Terraform Multi-Environment GCP Infrastructure — Repo Reference

> Production scaffold targeting GCP, GCP Beta, Firebase, Cloudflare, Mailgun,
> and Rollbar. Five environments with separate root modules per env, one GCS
> state bucket per GCP project, and GitHub Actions CI/CD.

---

## Directory Tree

```
talorai-infrastructure/
│
├── .github/
│   └── workflows/
│       ├── tf-plan.yml                    # PR → plan per env
│       ├── tf-apply.yml                   # Merge to main → apply per env
│       └── tf-drift.yml                   # Scheduled drift detection
|
├── AGENTS.md                          # Context for AI coding agents
├── CLAUDE.md                          # Claude Code–specific memory
├── README.md                          # Human-readable project overview
|
├── hcl/
|   ├── AGENTS.md                          # Context for AI coding agents
|   ├── CLAUDE.md                          # Claude Code–specific memory
|   ├── README.md                          # Human-readable project overview
│   |
|   ├── modules/                               # Shared child modules
|   |   ├── networking/                        # VPC, subnets, firewall, Cloud NAT
│   |   |   ├── main.tf
│   │   |   ├── variables.tf
│   │   |   ├── outputs.tf
│   │   |   └── versions.tf
|   |   ├── gke/                               # GKE cluster + node pools
│   │   |   ├── main.tf
│   │   |   ├── variables.tf
│   │   |   ├── outputs.tf
│   │   |   └── versions.tf
|   |   ├── cloud-sql/                         # Cloud SQL (Postgres/MySQL)
│   │   |   ├── main.tf
│   │   |   ├── variables.tf
│   │   |   ├── outputs.tf
│   │   |   └── versions.tf
|   |   ├── cloud-run/                         # Cloud Run services
│   │   |   ├── main.tf
│   │   |   ├── variables.tf
│   │   |   ├── outputs.tf
│   │   |   └── versions.tf
|   |   ├── firebase/                          # Firebase project, web apps, auth
│   │   |   ├── main.tf
│   │   |   ├── variables.tf
│   │   |   ├── outputs.tf
│   │   |   └── versions.tf
|   |   ├── dns/                               # Cloudflare zones, records, rules
│   │   |   ├── main.tf
│   │   |   ├── variables.tf
│   │   |   ├── outputs.tf
│   │   |   └── versions.tf
|   |   ├── email/                             # Mailgun domains, routes, creds
│   │   |   ├── main.tf
│   │   |   ├── variables.tf
│   │   |   ├── outputs.tf
│   │   |   └── versions.tf
|   |   └── observability/                     # Rollbar projects, teams, alerts
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── versions.tf
│   |
|   ├── environments/
│   |   ├── dev/
│   │   |   ├── main.tf                        # Wires modules — may include experimental ones
│   │   |   ├── providers.tf
│   │   |   ├── variables.tf
│   │   |   ├── outputs.tf
│   │   |   ├── versions.tf
│   │   |   ├── backend.tf
│   │   |   ├── locals.tf
│   │   |   ├── data.tf
│   │   |   └── terraform.tfvars               # Non-sensitive values for this env
│   |   ├── ci/
│   │   |   ├── main.tf
│   │   |   ├── providers.tf
│   │   |   ├── variables.tf
│   │   |   ├── outputs.tf
│   │   |   ├── versions.tf
│   │   |   ├── backend.tf
│   │   |   ├── locals.tf
│   │   |   ├── data.tf
│   │   |   └── terraform.tfvars
│   |   ├── qa/
│   │   |   ├── main.tf
│   │   |   ├── providers.tf
│   │   |   ├── variables.tf
│   │   |   ├── outputs.tf
│   │   |   ├── versions.tf
│   │   |   ├── backend.tf
│   │   |   ├── locals.tf
│   │   |   ├── data.tf
│   │   |   └── terraform.tfvars
│   |   ├── prod/
│   │   |   ├── main.tf                        # Only battle-tested modules
│   │   |   ├── providers.tf
│   │   |   ├── variables.tf
│   │   |   ├── outputs.tf
│   │   |   ├── versions.tf
│   │   |   ├── backend.tf
│   │   |   ├── locals.tf
│   │   |   ├── data.tf
│   │   |   └── terraform.tfvars
│   |   └── demo/
│   │       ├── main.tf
│   │       ├── providers.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       ├── versions.tf
│   │       ├── backend.tf
│   │       ├── locals.tf
│   │       ├── data.tf
│   |       └── terraform.tfvars
│   |
|   ├── tests/                                 # Native terraform test (v1.6+)
│   |   ├── networking.tftest.hcl
│   |   └── dns.tftest.hcl
│   |
|   └── scripts/
│       └── tf-init.sh                         # Convenience wrapper
│
├── .vscode/
│   └── settings.json                      # Format-on-save for TF + JS/TS
│
├── .pre-commit-config.yaml
├── .tflint.hcl
├── .terraform-version
├── .prettierignore
├── .eslintignore
├── .editorconfig
└── .gitignore
```

---

## AGENTS.md

````markdown
# AGENTS.md — AI Agent Context for terraform-infra

## Project Summary

This repo provisions cloud infrastructure across five environments (dev, ci, qa,
prod, demo). Each environment is a separate root module under `environments/<env>/`
with its own `main.tf` that explicitly declares which child modules it uses.
Shared child modules live in `modules/`.

## Architecture Decision: Separate Root Modules Per Environment

We use separate root modules (not a single root with feature-flag booleans)
because environments have structural variance — new modules are rolled out to
lower environments before being promoted to upper environments. The diff in a PR
to promote a module to prod is literally "add these lines to
`environments/prod/main.tf`."

Do NOT use `count` with `enable_*` booleans to control module presence. The
module block is either present in an env's `main.tf` or it isn't.

## Providers (verified registry sources)

| Service    | Provider source         | Notes                                                                                                                                                                                                                      |
| ---------- | ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| GCP        | `hashicorp/google`      | registry.terraform.io/providers/hashicorp/google                                                                                                                                                                           |
| GCP Beta   | `hashicorp/google-beta` | registry.terraform.io/providers/hashicorp/google-beta                                                                                                                                                                      |
| Firebase   | `hashicorp/google-beta` | No separate firebase provider. Resources like `google_firebase_project`, `google_firebase_web_app`, `google_identity_platform_config` all live in google-beta. See firebase.google.com/docs/projects/terraform/get-started |
| Cloudflare | `cloudflare/cloudflare` | registry.terraform.io/providers/cloudflare/cloudflare                                                                                                                                                                      |
| Mailgun    | `wgebis/mailgun`        | registry.terraform.io/providers/wgebis/mailgun                                                                                                                                                                             |
| Rollbar    | `rollbar/rollbar`       | registry.terraform.io/providers/rollbar/rollbar                                                                                                                                                                            |

## Environment → GCP Project → State Bucket Mapping

Each environment maps to a dedicated GCP project with its own state bucket:

| Env  | GCP Project ID    | State Bucket              |
| ---- | ----------------- | ------------------------- |
| dev  | myapp-dev-123456  | myapp-dev-123456-tfstate  |
| ci   | myapp-ci-234567   | myapp-ci-234567-tfstate   |
| qa   | myapp-qa-345678   | myapp-qa-345678-tfstate   |
| prod | myapp-prod-789012 | myapp-prod-789012-tfstate |
| demo | myapp-demo-567890 | myapp-demo-567890-tfstate |

## Stack Emulation

"Stacks" (the CDKTF concept) are emulated via the GCS `prefix` value in each
environment's `backend.tf`. Multiple root configs or the same root config with
different prefixes = different stacks within the same project bucket.

Convention: `<stack-name>` (e.g. `services`, `frontend`, `backend`)

## Directory Conventions

- `modules/<name>/` — one child module per infrastructure concern
- Each module has exactly: main.tf, variables.tf, outputs.tf, versions.tf
- `environments/<env>/` — one root module per environment
- Each env root has: main.tf, providers.tf, variables.tf, outputs.tf,
  versions.tf, backend.tf, locals.tf, data.tf, terraform.tfvars
- `tests/*.tftest.hcl` — native Terraform tests (v1.6+)

## Key Commands

```bash
# Work in a specific environment
cd environments/dev
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Or from repo root with chdir
terraform -chdir=environments/dev init
terraform -chdir=environments/dev plan

# Run tests (from modules or test dir)
terraform test

# Lint (from repo root, recursive)
tflint --init && tflint --recursive

# Format check
terraform fmt -check -recursive
```
````

## Promoting Modules Across Environments

1. Build the module in `modules/<name>/` with full variable/output contracts
2. Wire it into `environments/dev/main.tf` first
3. After validation, copy the module block to ci → qa → prod in separate PRs
4. The PR diff IS the promotion — reviewers see exactly what's introduced
5. Do NOT use feature-flag booleans (`enable_x = true/false`)

## State & Backend

- One GCS bucket per GCP project (bucket name = `<project-id>-remote-state`)
- Backend block in each env's `backend.tf` has hardcoded bucket + prefix
- Backend CANNOT use interpolation — this is a hard Terraform limitation
  (backend is resolved during `init`, before any HCL evaluation)
- Never run `terraform state` commands manually — use `moved`, `import`, or
  `removed` blocks in HCL instead

## Naming Conventions

Labels always include: `environment`, `managed_by = "terraform"`, `repo`, `platform=talorai`

## Secrets

- Provider credentials: GitHub Actions secrets + Workload Identity Federation
- App-level secrets: GCP Secret Manager, referenced via data sources
- NEVER put secrets in .tfvars files or backend.tf

## Formatting & Linting

- `.tf` and `.tfvars` files: `terraform fmt` (formatting) + `tflint` (linting)
- Prettier and ESLint do NOT understand HCL — `*.tf` is in ignore files
- VSCode: `hashicorp.terraform` extension with format-on-save enabled
- Pre-commit: `pre-commit` framework with terraform-fmt and tflint hooks

## CI/CD

- GitHub Actions with service key files stored as repo environment secrets
- Secret `GCP_SA_KEY` is mainly used. But if a service performs compute, use secret `GCP_COMPUTE_SA_KEY`.
- PR → `terraform plan` per env (posted as PR comment)
- Merge to main → `terraform apply` (sequential: dev → ci → qa → prod → demo)
- Drift detection on schedule, auto-opens GitHub Issues

## Module Authoring Rules

1. Every variable must have a `description` and a `type`
2. Use `validation` blocks on variables where constraints exist
3. Expose only what consumers need via `outputs.tf`
4. Pin provider version constraints in each module's `versions.tf`
5. Never hardcode project IDs, project numbers, locations, regions, or zones — accept them as variables
6. Source path from env root to module: `source = "../../modules/<name>"`

## Things to Watch Out For

- Firebase resources require `google-beta` provider, not `google`
- Mailgun provider (`wgebis/mailgun`) requires `region` ("us" or "eu")
- Rollbar needs account-level API key for projects, project-level for notifications
- Cloudflare API tokens should be scoped per zone, not global keys
- `google_app_engine_application` silently provisions a Firestore in Datastore mode
- As of Oct 2024, default Cloud Storage bucket can't be provisioned via TF for Firebase
- Backend blocks CANNOT use variables or interpolation of any kind

````

---

## CLAUDE.md

```markdown
# CLAUDE.md

Read AGENTS.md at the repo root for full project context, conventions, and commands.

## Additional Claude Code Notes

- Each environment is a separate root module at `environments/<env>/`.
  Always `cd` into the correct env directory before running terraform commands.
- When editing Terraform, run `terraform fmt` and `terraform validate` after changes.
- Prefer `moved` blocks over `terraform state mv`.
- Prefer `import` blocks over `terraform import` CLI.
- Prefer `removed` blocks with `lifecycle { destroy = false }` over `terraform state rm`.
- When adding a new child module, scaffold with: main.tf, variables.tf, outputs.tf, versions.tf.
- When promoting a module to an env, copy the module block from a lower env's main.tf.
  Do not add feature-flag booleans.
- Source paths from env roots to modules use `../../modules/<name>`.
- When suggesting provider resource names, verify against the Terraform Registry.
  Do not guess names from patterns.
````

---

## Shared Files (duplicated per env — this is intentional)

### environments/\<env\>/versions.tf

```hcl
terraform {
  required_version = "~> 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.14"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.14"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.48"
    }
    mailgun = {
      source  = "wgebis/mailgun"
      version = "~> 0.7"
    }
    rollbar = {
      source  = "rollbar/rollbar"
      version = "~> 1.14"
    }
  }
}
```

### environments/dev/backend.tf

```hcl
# Remember, no var or interpolation
terraform {
  backend "gcs" {
    bucket = "myapp-dev-100-remote-state"
    prefix = "main"
  }
}
```

### environments/prod/backend.tf

```hcl
# Remember, no var or interpolation
terraform {
  backend "gcs" {
    bucket = "myapp-prod-100-remote-state"
    prefix = "main"
  }
}
```

> **Why hardcode the backend?** Each directory IS a specific environment, so
> there's no ambiguity. No `-backend-config` gymnastics needed. If you want
> a different stack in the same project, create a second env directory (or a
> second root module) with a different `prefix`.

> **Can you interpolate the bucket name?** No. The `backend` block is resolved
> during `terraform init` before any HCL evaluation. Variables, locals, and data
> sources are not available. Use hardcoded values, `-backend-config` flags, or
> a wrapper script.

### environments/\<env\>/providers.tf

```hcl
# ── GCP ───────────────────────────────────────────────────────────────────
provider "google" {
  project = var.project_id
  region  = var.gcp_region
}

# ── GCP Beta (required for Firebase + beta features) ─────────────────────
provider "google-beta" {
  project               = var.project_id
  region                = var.gcp_region
  user_project_override = true
}

provider "google-beta" {
  alias                 = "no_user_project_override"
  user_project_override = false
}

# ── Cloudflare ────────────────────────────────────────────────────────────
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# ── Mailgun ───────────────────────────────────────────────────────────────
provider "mailgun" {
  api_key = var.mailgun_api_key
  region  = var.mailgun_region
}

# ── Rollbar ───────────────────────────────────────────────────────────────
provider "rollbar" {
  api_key = var.rollbar_api_key
}
```

### environments/\<env\>/variables.tf

```hcl
# ── Environment ───────────────────────────────────────────────────────────
variable "environment" {
  description = "Environment name: dev, ci, qa, prod, demo"
  type        = string
  validation {
    condition     = contains(["dev", "ci", "qa", "prod", "demo"], var.environment)
    error_message = "environment must be one of: dev, ci, qa, prod, demo"
  }
}

variable "project_prefix" {
  description = "Short prefix for resource naming (e.g. 'myapp')"
  type        = string
}

# ── GCP ───────────────────────────────────────────────────────────────────
variable "project_id" {
  description = "GCP project ID for this environment"
  type        = string
}

variable "gcp_region" {
  description = "Default GCP region"
  type        = string
  default     = "us-central1"
}

variable "gcp_zone" {
  description = "Default GCP zone"
  type        = string
  default     = "us-central1-a"
}

# ── Cloudflare ────────────────────────────────────────────────────────────
variable "cloudflare_api_token" {
  description = "Cloudflare scoped API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for the primary domain"
  type        = string
}

variable "apex_domain" {
  description = "Primary domain (e.g. example.com)"
  type        = string
}

# ── Mailgun ───────────────────────────────────────────────────────────────
variable "mailgun_api_key" {
  description = "Mailgun API key"
  type        = string
  sensitive   = true
}

variable "mailgun_region" {
  description = "Mailgun region: us or eu"
  type        = string
  default     = "us"
  validation {
    condition     = contains(["us", "eu"], var.mailgun_region)
    error_message = "mailgun_region must be 'us' or 'eu'"
  }
}

# ── Rollbar ───────────────────────────────────────────────────────────────
variable "rollbar_api_key" {
  description = "Rollbar account-level API key"
  type        = string
  sensitive   = true
}
```

### environments/\<env\>/locals.tf

```hcl
locals {
  common_labels = {
    environment        = var.environment
    managed_by = "terraform"
    platform       = "myapp"
  }

  is_production = var.environment == "prod"
}
```

---

## Per-Environment main.tf Examples

### environments/dev/main.tf — Includes experimental modules

```hcl
# ── Networking ────────────────────────────────────────────────────────────
module "networking" {
  source = "../../modules/networking"

  gcp_region  = var.gcp_region
  labels      = local.common_labels
}

# ── Cloud Run ─────────────────────────────────────────────────────────────
module "cloud_run" {
  source = "../../modules/cloud-run"

  gcp_region  = var.gcp_region
  labels      = local.common_labels
}

# ── Firebase ──────────────────────────────────────────────────────────────
module "firebase" {
  source = "../../modules/firebase"

  project_id  = var.project_id
  environment = var.environment
  apex_domain = var.apex_domain

  providers = {
    google-beta                          = google-beta
    google-beta.no_user_project_override = google-beta.no_user_project_override
  }
}

# ── DNS (Cloudflare) ─────────────────────────────────────────────────────
module "dns" {
  source = "../../modules/dns"

  zone_id         = var.cloudflare_zone_id
  apex_domain     = var.apex_domain
  environment     = var.environment
  cloud_run_url   = module.cloud_run.service_url
  mailgun_records = module.email.dns_records
}

# ── Email (Mailgun) ──────────────────────────────────────────────────────
module "email" {
  source = "../../modules/email"

  apex_domain = "mail.${var.apex_domain}"
  environment = var.environment
}

# ── Observability (Rollbar) ──────────────────────────────────────────────
module "observability" {
  source = "../../modules/observability"

  project_name = local.name_prefix
  environment  = var.environment
}

# ── EXPERIMENTAL: New service being tested in dev only ────────────────────
# This module will be promoted to ci/qa/prod after validation.
module "cloud_sql" {
  source = "../../modules/cloud-sql"

  network_id  = module.networking.vpc_id
  gcp_region  = var.gcp_region
  labels      = local.common_labels
}
```

### environments/prod/main.tf — Only battle-tested modules

```hcl
# ── Networking ────────────────────────────────────────────────────────────
module "networking" {
  source = "../../modules/networking"

  gcp_region  = var.gcp_region
  labels      = local.common_labels
}

# ── Cloud Run ─────────────────────────────────────────────────────────────
module "cloud_run" {
  source = "../../modules/cloud-run"

  gcp_region  = var.gcp_region
  labels      = local.common_labels
}

# ── Firebase ──────────────────────────────────────────────────────────────
module "firebase" {
  source = "../../modules/firebase"

  project_id  = var.project_id
  environment = var.environment
  apex_domain = var.apex_domain

  providers = {
    google-beta                          = google-beta
    google-beta.no_user_project_override = google-beta.no_user_project_override
  }
}

# ── DNS (Cloudflare) ─────────────────────────────────────────────────────
module "dns" {
  source = "../../modules/dns"

  zone_id         = var.cloudflare_zone_id
  apex_domain     = var.apex_domain
  environment     = var.environment
  cloud_run_url   = module.cloud_run.service_url
  mailgun_records = module.email.dns_records
}

# ── Email (Mailgun) ──────────────────────────────────────────────────────
module "email" {
  source = "../../modules/email"

  apex_domain = "notifications.${var.apex_domain}"
  environment = var.environment
}

# ── Observability (Rollbar) ──────────────────────────────────────────────
module "observability" {
  source = "../../modules/observability"

  project_name = local.name_prefix
  environment  = var.environment
}

# Note: cloud_sql is NOT here yet — still being validated in dev/ci/qa
```

---

## Per-Environment terraform.tfvars Examples

### environments/dev/terraform.tfvars

```hcl
environment    = "dev"
platform = "myapp"
project_id     = "myapp-dev-100"
gcp_region     = "us-central1"
gcp_zone       = "us-central1-a"
apex_domain    = "dev.example.com"

cloudflare_zone_id = "abc123..."
mailgun_region     = "us"
```

### environments/prod/terraform.tfvars

```hcl
environment    = "prod"
platform = "myapp"
project_id     = "myapp-prod-100"
gcp_region     = "us-central1"
gcp_zone       = "us-central1-a"
apex_domain    = "example.com"

cloudflare_zone_id = "xyz789..."
mailgun_region     = "us"
```

---

## Example Child Modules

### modules/firebase/main.tf

```hcl
# Firebase resources live in the google-beta provider.
# There is no separate firebase provider.
# See: firebase.google.com/docs/projects/terraform/get-started

resource "google_firebase_project" "this" {
  provider = google-beta
  project  = var.project_id
}

resource "google_firebase_web_app" "this" {
  provider        = google-beta
  project         = google_firebase_project.this.project
  display_name    = "${var.environment}-web"
  deletion_policy = "DELETE"
}

resource "google_identity_platform_config" "this" {
  provider = google-beta
  project  = google_firebase_project.this.project

  sign_in {
    allow_duplicate_emails = false

    email {
      enabled           = true
      password_required = true
    }
  }
}
```

### modules/email/main.tf

```hcl
resource "mailgun_domain" "this" {
  name          = var.apex_domain
  region        = "us"
  spam_action   = "disabled"
  dkim_key_size = 1024
}
```

### modules/observability/main.tf

```hcl
resource "rollbar_project" "this" {
  name = var.project_name
}

resource "rollbar_project_access_token" "post_server" {
  project_id = rollbar_project.this.id
  name       = "${var.environment}-post-server"
  scopes     = ["post_server_item"]
}
```

### modules/dns/main.tf

```hcl
resource "cloudflare_record" "app" {
  zone_id = var.zone_id
  name    = var.environment == "prod" ? "@" : var.environment
  content = var.cloud_run_url
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "mailgun" {
  for_each = { for r in var.mailgun_records : r.name => r }

  zone_id = var.zone_id
  name    = each.value.name
  content = each.value.value
  type    = each.value.type
  proxied = false
}
```

---

## GitHub Actions

### .github/workflows/tf-plan.yml

```yaml
name: Terraform Plan
on:
  pull_request:
    paths:
      - 'modules/**'
      - 'environments/**'
      - '.github/workflows/tf-*.yml'

permissions:
  contents: read
  pull-requests: write
  id-token: write

env:
  TF_VERSION: '1.9.8'
  TF_IN_AUTOMATION: 'true'

jobs:
  detect-changes:
    name: Detect changed environments
    runs-on: ubuntu-latest
    outputs:
      envs: ${{ steps.changes.outputs.envs }}
    steps:
      - uses: actions/checkout@v4
      - id: changes
        run: |
          # If modules/ changed, plan all envs. Otherwise only changed envs.
          if git diff --name-only origin/main...HEAD | grep -q '^modules/'; then
            echo 'envs=["dev","ci","qa","prod","demo"]' >> "$GITHUB_OUTPUT"
          else
            ENVS=$(git diff --name-only origin/main...HEAD \
              | grep '^environments/' \
              | cut -d'/' -f2 \
              | sort -u \
              | jq -R -s -c 'split("\n") | map(select(length > 0))')
            echo "envs=${ENVS}" >> "$GITHUB_OUTPUT"
          fi

  plan:
    name: Plan — ${{ matrix.env }}
    needs: detect-changes
    if: needs.detect-changes.outputs.envs != '[]'
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        env: ${{ fromJson(needs.detect-changes.outputs.envs) }}
        include:
          - env: dev
            wif_provider: projects/111/locations/global/workloadIdentityPools/gh-pool/providers/gh-provider
            wif_service_account: terraform@myapp-dev-123456.iam.gserviceaccount.com
          - env: ci
            wif_provider: projects/222/locations/global/workloadIdentityPools/gh-pool/providers/gh-provider
            wif_service_account: terraform@myapp-ci-234567.iam.gserviceaccount.com
          - env: qa
            wif_provider: projects/333/locations/global/workloadIdentityPools/gh-pool/providers/gh-provider
            wif_service_account: terraform@myapp-qa-345678.iam.gserviceaccount.com
          - env: prod
            wif_provider: projects/444/locations/global/workloadIdentityPools/gh-pool/providers/gh-provider
            wif_service_account: terraform@myapp-prod-789012.iam.gserviceaccount.com
          - env: demo
            wif_provider: projects/555/locations/global/workloadIdentityPools/gh-pool/providers/gh-provider
            wif_service_account: terraform@myapp-demo-567890.iam.gserviceaccount.com

    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - id: auth
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ matrix.wif_provider }}
          service_account: ${{ matrix.wif_service_account }}

      - name: Terraform Init
        working-directory: environments/${{ matrix.env }}
        run: terraform init

      - name: Terraform Validate
        working-directory: environments/${{ matrix.env }}
        run: terraform validate

      - name: Terraform Plan
        id: plan
        working-directory: environments/${{ matrix.env }}
        run: |
          terraform plan \
            -var="cloudflare_api_token=${{ secrets.CLOUDFLARE_API_TOKEN }}" \
            -var="mailgun_api_key=${{ secrets.MAILGUN_API_KEY }}" \
            -var="rollbar_api_key=${{ secrets.ROLLBAR_API_KEY }}" \
            -no-color \
            -out=tfplan \
          2>&1 | tee plan-output.txt

      - name: Comment PR
        uses: actions/github-script@v7
        if: always()
        with:
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync(
              'environments/${{ matrix.env }}/plan-output.txt', 'utf8'
            );
            const truncated = plan.length > 60000
              ? plan.substring(0, 60000) + '\n\n... truncated ...'
              : plan;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `### 📋 Plan: \`${{ matrix.env }}\`\n<details><summary>Show</summary>\n\n\`\`\`\n${truncated}\n\`\`\`\n</details>`
            });
```

### .github/workflows/tf-apply.yml

```yaml
name: Terraform Apply
on:
  push:
    branches: [main]
    paths:
      - 'modules/**'
      - 'environments/**'

  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to apply'
        required: true
        type: choice
        options: [dev, ci, qa, prod, demo]

permissions:
  contents: read
  id-token: write

concurrency:
  group: terraform-apply
  cancel-in-progress: false

env:
  TF_VERSION: '1.9.8'
  TF_IN_AUTOMATION: 'true'

jobs:
  apply:
    name: Apply — ${{ matrix.env }}
    runs-on: ubuntu-latest
    environment: ${{ matrix.env }} # GitHub Environment with protection rules
    strategy:
      max-parallel: 1 # Sequential: dev → ci → qa → prod → demo
      fail-fast: true
      matrix:
        env: [dev, ci, qa, prod, demo]
        include:
          - env: dev
            wif_provider: projects/111/locations/global/workloadIdentityPools/gh-pool/providers/gh-provider
            wif_service_account: terraform@myapp-dev-123456.iam.gserviceaccount.com
          - env: ci
            wif_provider: projects/222/locations/global/workloadIdentityPools/gh-pool/providers/gh-provider
            wif_service_account: terraform@myapp-ci-234567.iam.gserviceaccount.com
          - env: qa
            wif_provider: projects/333/locations/global/workloadIdentityPools/gh-pool/providers/gh-provider
            wif_service_account: terraform@myapp-qa-345678.iam.gserviceaccount.com
          - env: prod
            wif_provider: projects/444/locations/global/workloadIdentityPools/gh-pool/providers/gh-provider
            wif_service_account: terraform@myapp-prod-789012.iam.gserviceaccount.com
          - env: demo
            wif_provider: projects/555/locations/global/workloadIdentityPools/gh-pool/providers/gh-provider
            wif_service_account: terraform@myapp-demo-567890.iam.gserviceaccount.com

    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - id: auth
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ matrix.wif_provider }}
          service_account: ${{ matrix.wif_service_account }}

      - name: Terraform Init
        working-directory: environments/${{ matrix.env }}
        run: terraform init

      - name: Terraform Apply
        working-directory: environments/${{ matrix.env }}
        run: |
          terraform apply \
            -var="cloudflare_api_token=${{ secrets.CLOUDFLARE_API_TOKEN }}" \
            -var="mailgun_api_key=${{ secrets.MAILGUN_API_KEY }}" \
            -var="rollbar_api_key=${{ secrets.ROLLBAR_API_KEY }}" \
            -auto-approve
```

### .github/workflows/tf-drift.yml

```yaml
name: Drift Detection
on:
  schedule:
    - cron: '0 8 * * 1-5'

permissions:
  contents: read
  id-token: write
  issues: write

env:
  TF_VERSION: '1.9.8'

jobs:
  drift:
    name: Drift — ${{ matrix.env }}
    runs-on: ubuntu-latest
    strategy:
      matrix:
        env: [dev, qa, prod]
        include:
          - env: dev
            wif_provider: projects/111/locations/global/workloadIdentityPools/gh-pool/providers/gh-provider
            wif_service_account: terraform@myapp-dev-123456.iam.gserviceaccount.com
          - env: qa
            wif_provider: projects/333/locations/global/workloadIdentityPools/gh-pool/providers/gh-provider
            wif_service_account: terraform@myapp-qa-345678.iam.gserviceaccount.com
          - env: prod
            wif_provider: projects/444/locations/global/workloadIdentityPools/gh-pool/providers/gh-provider
            wif_service_account: terraform@myapp-prod-789012.iam.gserviceaccount.com

    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - id: auth
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ matrix.wif_provider }}
          service_account: ${{ matrix.wif_service_account }}

      - name: Init
        working-directory: environments/${{ matrix.env }}
        run: terraform init

      - name: Detect Drift
        id: drift
        working-directory: environments/${{ matrix.env }}
        run: |
          set +e
          terraform plan \
            -var="cloudflare_api_token=${{ secrets.CLOUDFLARE_API_TOKEN }}" \
            -var="mailgun_api_key=${{ secrets.MAILGUN_API_KEY }}" \
            -var="rollbar_api_key=${{ secrets.ROLLBAR_API_KEY }}" \
            -detailed-exitcode \
            -no-color 2>&1 | tee drift.txt
          echo "exitcode=$?" >> "$GITHUB_OUTPUT"

      - name: Open Issue on Drift
        if: steps.drift.outputs.exitcode == '2'
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: `⚠️ Drift detected: ${{ matrix.env }}`,
              body: `Drift in **${{ matrix.env }}** on ${new Date().toISOString().split('T')[0]}.\n\n\`\`\`\ncd environments/${{ matrix.env }}\nterraform plan\n\`\`\``,
              labels: ['drift', 'terraform']
            });
```

---

## Example Test: tests/networking.tftest.hcl

```hcl
variables {
  environment    = "test"
  project_prefix = "myapp"
  project_id     = "myapp-test-000000"
  gcp_region     = "us-central1"
  gcp_zone       = "us-central1-a"
  apex_domain    = "test.example.com"

  cloudflare_api_token = "test-token"
  cloudflare_zone_id   = "test-zone"
  mailgun_api_key      = "test-key"
  mailgun_region       = "us"
  rollbar_api_key      = "test-key"
}

run "vpc_name_follows_convention" {
  command = plan

  assert {
    condition     = module.networking.vpc_name == "myapp-test-vpc"
    error_message = "VPC name should follow <prefix>-<env>-vpc convention"
  }
}
```

---

## VSCode Configuration

### .vscode/settings.json

```jsonc
{
  // Terraform — format via HashiCorp extension (calls terraform fmt)
  "[terraform]": {
    "editor.defaultFormatter": "hashicorp.terraform",
    "editor.formatOnSave": true,
  },
  "[terraform-vars]": {
    "editor.defaultFormatter": "hashicorp.terraform",
    "editor.formatOnSave": true,
  },

  // JS/TS — format via Prettier
  "[javascript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true,
  },
  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true,
  },

  // Terraform language server
  "terraform.languageServer.enable": true,
}
```

### Autocomplete for `var.` inside strings

The HashiCorp extension supports autocomplete inside `"${var.` — the dot after
`var` triggers it. Requirements: run `terraform init` first so the language
server has context, and no syntax errors above the cursor. Bare `var.` inside a
string without `${}` is literal text and won't trigger autocomplete.

---

## Prettier & ESLint: Ignore .tf Files

### .prettierignore

```
*.tf
*.tfvars
*.tfbackend
.terraform/
```

### .eslintignore

```
*.tf
*.tfvars
*.tfbackend
.terraform/
```

Prettier and ESLint do not understand HCL. Do not try to make them parse `.tf`
files. Use `terraform fmt` for formatting and `tflint` for linting.

---

## Pre-Commit Hooks

### .pre-commit-config.yaml

```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-tf-docs
    rev: v0.3.0
    hooks:
      - id: terraform-fmt
      - id: terraform-validate

  - repo: https://github.com/terraform-linters/tflint
    rev: v0.53.0
    hooks:
      - id: tflint
        args: ['--recursive']

  - repo: https://github.com/pre-commit/mirrors-prettier
    rev: v3.1.0
    hooks:
      - id: prettier
        types_or: [javascript, typescript, json, yaml, markdown]
```

---

## Other Supporting Files

### .terraform-version

```
1.9.8
```

### .tflint.hcl

```hcl
plugin "google" {
  enabled = true
  version = "0.30.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}

config {
  call_module_type = "local"
}
```

### .editorconfig

```ini
root = true

[*.tf]
indent_style = space
indent_size = 2
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.tfvars]
indent_style = space
indent_size = 2
```

### .gitignore

```gitignore
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
crash.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraform.lock.hcl
```

---

## Convenience Script: scripts/tf-init.sh

```bash
#!/usr/bin/env bash
# Usage: ./scripts/tf-init.sh <env> [stack]
# Example: ./scripts/tf-init.sh dev platform/core
set -euo pipefail

ENV="${1:?Usage: tf-init.sh <env> [stack]}"
STACK="${2:-platform/core}"
ENV_DIR="environments/${ENV}"

if [[ ! -d "$ENV_DIR" ]]; then
  echo "Error: ${ENV_DIR} does not exist" >&2
  exit 1
fi

cd "$ENV_DIR"
terraform init
echo ""
echo "✅ Initialized: ${ENV_DIR} (stack: ${STACK})"
```

---

## Quick-Reference: What Goes Where

| Question                                    | Answer                                                          |
| ------------------------------------------- | --------------------------------------------------------------- |
| Where do I add a new GCP service?           | New module in `modules/`, wire it in the target env's `main.tf` |
| Where do I change a value per env?          | `environments/<env>/terraform.tfvars`                           |
| Where do I add a shared variable?           | Each env's `variables.tf` (yes, duplicated — intentional)       |
| Where do I add derived/computed values?     | Each env's `locals.tf`                                          |
| Where do I add a new provider?              | Each env's `versions.tf` + `providers.tf`                       |
| Where do I rename a resource safely?        | `moved` block in the relevant module's `main.tf`                |
| Where do I import existing infra?           | `import` block in the relevant module or env's `main.tf`        |
| Where do I stop managing a resource?        | `removed` block with `lifecycle { destroy = false }`            |
| How do I promote a module to prod?          | Copy the module block from a lower env's `main.tf` to prod's    |
| How do I emulate CDKTF stacks?              | Different `prefix` values in `backend.tf` per stack             |
| Where do secrets come from in CI?           | GitHub Actions secrets → `-var` flags                           |
| Can I interpolate the backend bucket?       | No — backend resolves before HCL evaluation                     |
| How does Claude/Codex understand this repo? | `AGENTS.md` (universal) + `CLAUDE.md` (Claude-specific)         |
| What formats .tf files?                     | `terraform fmt` — NOT Prettier                                  |
| What lints .tf files?                       | `tflint` — NOT ESLint                                           |
