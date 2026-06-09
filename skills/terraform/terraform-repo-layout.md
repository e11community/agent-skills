# Terraform Multi-Environment GCP Infrastructure — Repo Reference

> Production scaffold targeting GCP, GCP Beta, Firebase, Cloudflare, Mailgun,
> and Rollbar. Five environments (dev, ci, qa, demo, prod), separate root
> modules per env+stack, one GCS state bucket per GCP project, and GitHub
> Actions CI/CD.
>
> **Placeholders:** `PLATFORM` is the platform/project short name — replace it
> with the real name in a realized repo. Module names (`networking`, `cloud-run`,
> …), org-module names (`folders`, `org-iam`, …), and stack names (`main`) are
> examples — use the repo's actual names. The five environment names are fixed
> and always exist. See `SKILL.md` for conventions; this file is the structural
> reference.

---

## Directory Tree

```
PLATFORM-infrastructure/
│
├── .github/
│   └── workflows/
│       ├── tf-plan.yml                 # Reusable plan, keyed by project_id
│       ├── tf-plan-matrix.yml          # PR → detect changed envs → fan out
│       ├── tf-apply.yml                # Push/dispatch → apply
│       └── tf-drift.yml                # Scheduled drift detection
│
├── README.md
├── .terraform-version
├── .tflint.hcl
├── .pre-commit-config.yaml
├── .prettierignore
├── .eslintignore
├── .editorconfig
├── .gitignore
├── .vscode/
│   └── settings.json
│
└── hcl/
    ├── AGENTS.md                       # Thin pointer to the terraform skill + project context
    ├── CLAUDE.md                       # Thin pointer to the terraform skill + project context
    ├── README.md
    │
    ├── modules/                        # Shared per-project child modules (names are examples)
    │   ├── networking/                 # VPC, subnets, firewall, Cloud NAT
    │   │   ├── main.tf
    │   │   ├── variables.tf
    │   │   ├── outputs.tf
    │   │   └── versions.tf
    │   ├── gke/                         # GKE cluster + node pools
    │   ├── cloud-sql/                   # Cloud SQL (Postgres/MySQL)
    │   ├── cloud-run/                   # Cloud Run services
    │   ├── firebase/                    # Firebase project, web apps, auth
    │   ├── dns/                         # Cloudflare zones, records, rules
    │   ├── email/                       # Mailgun domains, routes, creds
    │   └── observability/               # Rollbar projects, teams, alerts
    │       ├── main.tf
    │       ├── variables.tf
    │       ├── outputs.tf
    │       ├── versions.tf
    │       └── iam.tf                   # Only when the module manages IAM
    │
    ├── org-modules/                     # GCP Organization-wide child modules (singletons; names are examples)
    │   ├── folders/                     # google_folder hierarchy
    │   │   ├── main.tf
    │   │   ├── variables.tf
    │   │   ├── outputs.tf
    │   │   └── versions.tf
    │   ├── org-iam/                     # Org-level IAM bindings + custom roles
    │   │   ├── main.tf                  # Minimal — data sources/locals only
    │   │   ├── variables.tf
    │   │   ├── outputs.tf
    │   │   ├── versions.tf
    │   │   └── iam.tf                   # google_organization_iam_* lives here
    │   ├── org-policies/                # google_org_policy_policy (Org Policy v2)
    │   └── org-log-sinks/               # google_logging_organization_sink
    │
    ├── org-stacks/                      # Org-level root modules (env-agnostic; stack names are examples)
    │   └── main/                        # `main` is the example default org stack
    │       ├── main.tf                  # Wires org-modules (source = ../../org-modules/<name>)
    │       ├── providers.tf
    │       ├── variables.tf
    │       ├── outputs.tf
    │       ├── versions.tf
    │       ├── backend.tf               # prod bucket; prefix = org-stacks/<stack>
    │       ├── locals.tf
    │       ├── data.tf
    │       └── terraform.tfvars
    │   # NOTE: ALL org-stacks store state in the prod bucket
    │   # (PLATFORM-prod-100-remote-state) under prefix org-stacks/<stack>.
    │
    ├── environments/                    # One root module per env + stack
    │   ├── dev/
    │   │   └── main/                     # `main` is the example default stack
    │   │       ├── main.tf               # Wires modules — may include experimental ones
    │   │       ├── providers.tf
    │   │       ├── variables.tf
    │   │       ├── outputs.tf
    │   │       ├── versions.tf
    │   │       ├── backend.tf
    │   │       ├── locals.tf
    │   │       ├── data.tf
    │   │       └── terraform.tfvars      # Non-sensitive values for this env+stack
    │   ├── ci/
    │   │   └── main/                      # (same file set)
    │   ├── qa/
    │   │   └── main/
    │   ├── prod/
    │   │   └── main/                      # Only battle-tested modules
    │   └── demo/
    │       └── main/
    │
    ├── tests/                            # Native terraform test (v1.6+)
    │   ├── networking.tftest.hcl
    │   └── dns.tftest.hcl
    │
    └── scripts/
        └── tf-init.sh                    # Convenience wrapper
```

A **stack** is a root-module subdirectory under an environment
(`environments/<env>/<stack>/`). Each stack has its own `backend.tf` whose GCS
`prefix` equals the stack name, so multiple stacks share one project state
bucket. `main` is the conventional default; add stacks by creating sibling
subdirectories with the same file set.

---

## AGENTS.md / CLAUDE.md

Conventions, commands, and authoring rules live in this skill's `SKILL.md`. In a
realized repo, keep `hcl/AGENTS.md` and `hcl/CLAUDE.md` as thin files that point
to the terraform skill and hold only repo-specific context (real platform name,
real module/stack names, anything not derivable from the code).

---

## Environment → GCP Project → State Bucket

| Env  | GCP Project ID    | State Bucket                   |
| ---- | ----------------- | ------------------------------ |
| dev  | PLATFORM-dev-100  | PLATFORM-dev-100-remote-state  |
| ci   | PLATFORM-ci-100   | PLATFORM-ci-100-remote-state   |
| qa   | PLATFORM-qa-100   | PLATFORM-qa-100-remote-state   |
| demo | PLATFORM-demo-100 | PLATFORM-demo-100-remote-state |
| prod | PLATFORM-prod-100 | PLATFORM-prod-100-remote-state |

---

## Shared Files (duplicated per env+stack — this is intentional)

### environments/\<env\>/\<stack\>/versions.tf

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

### environments/dev/main/backend.tf

```hcl
# Remember, no var or interpolation
terraform {
  backend "gcs" {
    bucket = "PLATFORM-dev-100-remote-state"
    prefix = "main"
  }
}
```

### environments/prod/main/backend.tf

```hcl
# Remember, no var or interpolation
terraform {
  backend "gcs" {
    bucket = "PLATFORM-prod-100-remote-state"
    prefix = "main"
  }
}
```

> **Why hardcode the backend?** Each directory IS a specific env+stack, so there
> is no ambiguity. The `prefix` is the stack name.
>
> **Can you interpolate the bucket name?** No. The `backend` block is resolved
> during `terraform init` before any HCL evaluation. Variables, locals, and data
> sources are not available. Use hardcoded values, `-backend-config` flags, or a
> wrapper script.

### environments/\<env\>/\<stack\>/providers.tf

```hcl
# ── GCP ─────────────────────────────────────────────────────────────────────
provider "google" {
  project = var.project_id
  region  = var.gcp_region
}

# ── GCP Beta (required for Firebase + beta features) ─────────────────────────
provider "google-beta" {
  project               = var.project_id
  region                = var.gcp_region
  user_project_override = true
}

provider "google-beta" {
  alias                 = "no_user_project_override"
  user_project_override = false
}

# ── Cloudflare ───────────────────────────────────────────────────────────────
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# ── Mailgun ───────────────────────────────────────────────────────────────────
provider "mailgun" {
  api_key = var.mailgun_api_key
  region  = var.mailgun_region
}

# ── Rollbar ────────────────────────────────────────────────────────────────────
provider "rollbar" {
  api_key = var.rollbar_api_key
}
```

### environments/\<env\>/\<stack\>/variables.tf

```hcl
# ── Environment ──────────────────────────────────────────────────────────────
variable "environment" {
  description = "Environment name: dev, ci, qa, demo, prod"
  type        = string
  validation {
    condition     = contains(["dev", "ci", "qa", "demo", "prod"], var.environment)
    error_message = "environment must be one of: dev, ci, qa, demo, prod"
  }
}

variable "project_prefix" {
  description = "Short prefix for resource naming and labels (e.g. 'PLATFORM')"
  type        = string
}

# ── GCP ─────────────────────────────────────────────────────────────────────
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

# ── Cloudflare ───────────────────────────────────────────────────────────────
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

# ── Mailgun ───────────────────────────────────────────────────────────────────
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

# ── Rollbar ────────────────────────────────────────────────────────────────────
variable "rollbar_api_key" {
  description = "Rollbar account-level API key"
  type        = string
  sensitive   = true
}
```

### environments/\<env\>/\<stack\>/locals.tf

```hcl
locals {
  common_labels = {
    environment = var.environment
    managed_by  = "terraform"
    platform    = var.project_prefix
  }

  is_production = var.environment == "prod"
}
```

---

## Per-Stack main.tf Examples

Module source paths from a stack root go up three levels:
`../../../modules/<name>` (`<stack>` → `<env>` → `environments` → `hcl`).

### environments/dev/main/main.tf — includes experimental modules

```hcl
# ── Networking ────────────────────────────────────────────────────────────────
module "networking" {
  source = "../../../modules/networking"

  gcp_region = var.gcp_region
  labels     = local.common_labels
}

# ── Cloud Run ──────────────────────────────────────────────────────────────────
module "cloud_run" {
  source = "../../../modules/cloud-run"

  gcp_region = var.gcp_region
  labels     = local.common_labels
}

# ── Firebase ───────────────────────────────────────────────────────────────────
module "firebase" {
  source = "../../../modules/firebase"

  project_id  = var.project_id
  environment = var.environment
  apex_domain = var.apex_domain

  providers = {
    google-beta                          = google-beta
    google-beta.no_user_project_override = google-beta.no_user_project_override
  }
}

# ── DNS (Cloudflare) ────────────────────────────────────────────────────────────
module "dns" {
  source = "../../../modules/dns"

  zone_id         = var.cloudflare_zone_id
  apex_domain     = var.apex_domain
  environment     = var.environment
  cloud_run_url   = module.cloud_run.service_url
  mailgun_records = module.email.dns_records
}

# ── Email (Mailgun) ─────────────────────────────────────────────────────────────
module "email" {
  source = "../../../modules/email"

  apex_domain = "mail.${var.apex_domain}"
  environment = var.environment
}

# ── Observability (Rollbar) ─────────────────────────────────────────────────────
module "observability" {
  source = "../../../modules/observability"

  project_name = var.project_prefix
  environment  = var.environment
}

# ── EXPERIMENTAL: new service being tested in dev only ──────────────────────────
# Promote to ci/qa/prod/demo after validation.
module "cloud_sql" {
  source = "../../../modules/cloud-sql"

  network_id = module.networking.vpc_id
  gcp_region = var.gcp_region
  labels     = local.common_labels
}
```

### environments/prod/main/main.tf — only battle-tested modules

```hcl
# ── Networking ────────────────────────────────────────────────────────────────
module "networking" {
  source = "../../../modules/networking"

  gcp_region = var.gcp_region
  labels     = local.common_labels
}

# ── Cloud Run ──────────────────────────────────────────────────────────────────
module "cloud_run" {
  source = "../../../modules/cloud-run"

  gcp_region = var.gcp_region
  labels     = local.common_labels
}

# ── Firebase ───────────────────────────────────────────────────────────────────
module "firebase" {
  source = "../../../modules/firebase"

  project_id  = var.project_id
  environment = var.environment
  apex_domain = var.apex_domain

  providers = {
    google-beta                          = google-beta
    google-beta.no_user_project_override = google-beta.no_user_project_override
  }
}

# ── DNS (Cloudflare) ────────────────────────────────────────────────────────────
module "dns" {
  source = "../../../modules/dns"

  zone_id         = var.cloudflare_zone_id
  apex_domain     = var.apex_domain
  environment     = var.environment
  cloud_run_url   = module.cloud_run.service_url
  mailgun_records = module.email.dns_records
}

# ── Email (Mailgun) ─────────────────────────────────────────────────────────────
module "email" {
  source = "../../../modules/email"

  apex_domain = "notifications.${var.apex_domain}"
  environment = var.environment
}

# ── Observability (Rollbar) ─────────────────────────────────────────────────────
module "observability" {
  source = "../../../modules/observability"

  project_name = var.project_prefix
  environment  = var.environment
}

# Note: cloud_sql is NOT here yet — still being validated in dev/ci/qa
```

---

## Per-Stack terraform.tfvars Examples

### environments/dev/main/terraform.tfvars

```hcl
environment    = "dev"
project_prefix = "PLATFORM"
project_id     = "PLATFORM-dev-100"
gcp_region     = "us-central1"
gcp_zone       = "us-central1-a"
apex_domain    = "dev.example.com"

cloudflare_zone_id = "abc123..."
mailgun_region     = "us"
```

### environments/prod/main/terraform.tfvars

```hcl
environment    = "prod"
project_prefix = "PLATFORM"
project_id     = "PLATFORM-prod-100"
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

## Example Organization-Wide Modules

Org-modules live in `hcl/org-modules/<name>/` and follow the same file
convention as `hcl/modules/`. They are GCP Organization singletons: scoped by
`org_id` (and sometimes `folder_id` / `billing_account`), never by
`environment` or `project_id`, and never promoted across environments. Like any
module they define no provider or backend of their own — they are wired into an
org-stack (see "Organization-Level Stacks"). Most org-level resources do not
accept `labels`, so these modules usually omit the `labels` variable.

### org-modules/folders/main.tf

```hcl
resource "google_folder" "this" {
  for_each = var.folders

  display_name = each.value.display_name
  parent       = each.value.parent_folder_id != null ? "folders/${each.value.parent_folder_id}" : "organizations/${var.org_id}"
}
```

### org-modules/folders/variables.tf

```hcl
variable "folders" {
  description = "Map of folders to create, keyed by a stable logical name"
  type = map(object({
    display_name     = string
    parent_folder_id = optional(string)
  }))
}

variable "org_id" {
  description = "GCP Organization ID (numeric, no 'organizations/' prefix)"
  type        = string
}
```

### org-modules/org-iam/iam.tf

```hcl
# Org-level IAM resources live in iam.tf, not main.tf — see SKILL.md.
resource "google_organization_iam_member" "this" {
  for_each = var.org_iam_members

  org_id = var.org_id
  role   = each.value.role
  member = each.value.member
}

resource "google_organization_iam_custom_role" "this" {
  for_each = var.custom_roles

  org_id      = var.org_id
  role_id     = each.key
  title       = each.value.title
  description = each.value.description
  permissions = each.value.permissions
}
```

### org-modules/org-policies/main.tf

```hcl
# Org Policy v2. Boolean constraints, e.g. compute.disableSerialPortAccess.
resource "google_org_policy_policy" "boolean" {
  for_each = var.boolean_constraints

  name   = "organizations/${var.org_id}/policies/${each.key}"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = each.value ? "TRUE" : "FALSE"
    }
  }
}
```

### org-modules/org-log-sinks/main.tf

```hcl
resource "google_logging_organization_sink" "this" {
  name             = var.sink_name
  org_id           = var.org_id
  destination      = var.destination
  filter           = var.filter
  include_children = true
}
```

### org-modules/\<name\>/versions.tf

```hcl
terraform {
  required_version = "~> 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.14"
    }
  }
}
```

---

## Organization-Level Stacks

Org-stacks live in `hcl/org-stacks/<stack>/` and are root modules — the same
file set as an environment stack — that wire org-modules. They are
environment-agnostic. State for ALL org-stacks lives in the prod bucket under
prefix `org-stacks/<stack>`; the prod project ID is fixed for every org-stack.
Module source paths go up two levels: `../../org-modules/<name>` (`<stack>` →
`org-stacks` → `hcl`).

### org-stacks/\<stack\>/backend.tf

```hcl
# Remember, no var or interpolation
terraform {
  backend "gcs" {
    bucket = "PLATFORM-prod-100-remote-state"
    prefix = "org-stacks/main"
  }
}
```

> The bucket is ALWAYS the prod project's state bucket — org state is not owned
> by any single environment, and prod is its designated home. The `prefix`
> carries the `org-stacks/` segment (not just the stack name) so org state never
> collides with prod's environment stacks in the shared bucket.

### org-stacks/\<stack\>/versions.tf

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
  }
}
```

### org-stacks/\<stack\>/providers.tf

```hcl
# The provider's quota/billing project is the prod project (fixed for org work).
provider "google" {
  project = var.project_id
  region  = var.gcp_region
}

provider "google-beta" {
  project               = var.project_id
  region                = var.gcp_region
  user_project_override = true
}
```

### org-stacks/\<stack\>/variables.tf

```hcl
# ── GCP Organization ──────────────────────────────────────────────────────────
variable "org_id" {
  description = "GCP Organization ID (numeric, no 'organizations/' prefix)"
  type        = string
}

variable "billing_account" {
  description = "Billing account ID for org-level billing IAM"
  type        = string
}

# ── GCP ─────────────────────────────────────────────────────────────────────
variable "project_id" {
  description = "Quota/billing project for org-level API calls — the prod project"
  type        = string
}

variable "project_prefix" {
  description = "Short prefix for resource naming and labels (e.g. 'PLATFORM')"
  type        = string
}

variable "gcp_region" {
  description = "Default GCP region"
  type        = string
  default     = "us-central1"
}
```

### org-stacks/\<stack\>/main.tf

```hcl
# ── Folders ───────────────────────────────────────────────────────────────────
module "folders" {
  source = "../../org-modules/folders"

  org_id  = var.org_id
  folders = var.folders
}

# ── Org IAM ───────────────────────────────────────────────────────────────────
module "org_iam" {
  source = "../../org-modules/org-iam"

  org_id          = var.org_id
  org_iam_members = var.org_iam_members
  custom_roles    = var.custom_roles
}

# ── Org Policies ──────────────────────────────────────────────────────────────
module "org_policies" {
  source = "../../org-modules/org-policies"

  org_id              = var.org_id
  boolean_constraints = var.boolean_constraints
}
```

### org-stacks/\<stack\>/terraform.tfvars

```hcl
org_id          = "123456789012"
billing_account = "ABCDEF-012345-6789AB"
project_id      = "PLATFORM-prod-100"
project_prefix  = "PLATFORM"
gcp_region      = "us-central1"
```

---

## GitHub Actions

The full workflow YAML ships with this skill in `.github/workflows/` — install
those files into `<project-root>/.github/workflows/` rather than re-authoring
them here. Summary:

| Workflow              | Trigger                              | What it does                                                              |
| --------------------- | ------------------------------------ | ------------------------------------------------------------------------- |
| `tf-plan.yml`         | `workflow_call` / `workflow_dispatch` | Reusable plan for one `project_id`; derives env from the ID; comments PR. |
| `tf-plan-matrix.yml`  | `pull_request`                        | Detects changed envs and fans out to `tf-plan.yml` per project.           |
| `tf-apply.yml`        | push to deploy branch / dispatch      | Plans then applies for the selected env+stack.                            |
| `tf-drift.yml`        | scheduled (cron) / dispatch           | `terraform plan -detailed-exitcode`; opens a GitHub Issue on drift.       |

Notes:

- Auth uses `google-github-actions/auth@v2` with `credentials_json` from
  `secrets.GCP_SA_KEY` (use `GCP_COMPUTE_SA_KEY` for compute services).
- The environment name is derived from the project ID `PLATFORM-<env>-100`.
- Working directory is `hcl/environments/<env>/<stack>/` (e.g. `.../dev/main`).
- The matrix workflow ships with a `prototype_phase` that limits envs to
  `dev`/`ci`; switch to `smart_detect` when out of the prototype phase.
- Provider secret `-var` flags (Cloudflare/Mailgun/Rollbar) are present but
  commented out in the shipped files — uncomment when those providers are wired.

---

## Example Test: tests/networking.tftest.hcl

```hcl
variables {
  environment    = "ci"
  project_prefix = "PLATFORM"
  project_id     = "PLATFORM-ci-100"
  gcp_region     = "us-central1"
  gcp_zone       = "us-central1-a"
  apex_domain    = "ci.example.com"

  cloudflare_api_token = "test-token"
  cloudflare_zone_id   = "test-zone"
  mailgun_api_key      = "test-key"
  mailgun_region       = "us"
  rollbar_api_key      = "test-key"
}

run "vpc_name_follows_convention" {
  command = plan

  assert {
    condition     = module.networking.vpc_name == "PLATFORM-ci-vpc"
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

The HashiCorp extension supports autocomplete inside `"${var.` — the dot after
`var` triggers it. Run `terraform init` first so the language server has context,
and ensure no syntax errors above the cursor. Bare `var.` inside a string without
`${}` is literal text and won't trigger autocomplete.

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

Prettier and ESLint do not understand HCL. Use `terraform fmt` for formatting and
`tflint` for linting.

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

Ships with this skill. Install to `<project-root>/.terraform-version`:

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
# Example: ./scripts/tf-init.sh dev main
set -euo pipefail

ENV="${1:?Usage: tf-init.sh <env> [stack]}"
STACK="${2:-main}"
STACK_DIR="hcl/environments/${ENV}/${STACK}"

if [[ ! -d "$STACK_DIR" ]]; then
  echo "Error: ${STACK_DIR} does not exist" >&2
  exit 1
fi

cd "$STACK_DIR"
terraform init
echo ""
echo "Initialized: ${STACK_DIR} (env: ${ENV}, stack: ${STACK})"
```

---

## Quick-Reference: What Goes Where

| Question                                | Answer                                                                  |
| --------------------------------------- | ----------------------------------------------------------------------- |
| Where do I add a new GCP service?       | New module in `hcl/modules/`, wire it into the target stack's `main.tf` |
| Where do I manage org-wide resources?   | New module in `hcl/org-modules/` (folders, org IAM, org policies, sinks) |
| Where do I wire org-modules?            | An org-stack root: `hcl/org-stacks/<stack>/main.tf`                      |
| Where does org-stack state live?        | Prod bucket `PLATFORM-prod-100-remote-state`, prefix `org-stacks/<stack>` |
| Where do I change a value per env?      | `hcl/environments/<env>/<stack>/terraform.tfvars`                       |
| Where do I add a shared variable?       | Each stack's `variables.tf` (yes, duplicated — intentional)             |
| Where do I add derived/computed values? | Each stack's `locals.tf`                                                |
| Where do I add a new provider?          | Each stack's `versions.tf` + `providers.tf`                             |
| Where do I rename a resource safely?    | `moved` block in the relevant module's `main.tf`                        |
| Where do I import existing infra?       | `import` block in the relevant module or stack's `main.tf`              |
| Where do I stop managing a resource?    | `removed` block with `lifecycle { destroy = false }`                    |
| How do I promote a module to prod?      | Copy the module block from a lower env's stack `main.tf` to prod's      |
| What is a stack?                        | A root-module subdir `environments/<env>/<stack>/`; prefix = stack name |
| Where do secrets come from in CI?       | GitHub Actions secrets → `GCP_SA_KEY` / `-var` flags                    |
| Can I interpolate the backend bucket?   | No — backend resolves before HCL evaluation                             |
| What formats .tf files?                 | `terraform fmt` — NOT Prettier                                          |
| What lints .tf files?                   | `tflint` — NOT ESLint                                                   |
```
