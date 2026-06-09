# AGENTS.md — AI Agent Context for talorai-infrastructure

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

| Service    | Provider source         | Notes                                                         |
| ---------- | ----------------------- | ------------------------------------------------------------- |
| GCP        | `hashicorp/google`      | registry.terraform.io/providers/hashicorp/google              |
| GCP Beta   | `hashicorp/google-beta` | registry.terraform.io/providers/hashicorp/google-beta         |
| Firebase   | `hashicorp/google-beta` | No separate firebase provider. Resources live in google-beta. |
| Cloudflare | `cloudflare/cloudflare` | registry.terraform.io/providers/cloudflare/cloudflare         |
| Mailgun    | `wgebis/mailgun`        | registry.terraform.io/providers/wgebis/mailgun                |
| Rollbar    | `rollbar/rollbar`       | registry.terraform.io/providers/rollbar/rollbar               |

## Environment → GCP Project → State Bucket Mapping

| Env  | GCP Project ID   | State Bucket                  |
| ---- | ---------------- | ----------------------------- |
| dev  | talorai-dev-100  | talorai-dev-100-remote-state  |
| ci   | talorai-ci-100   | talorai-ci-100-remote-state   |
| qa   | talorai-qa-100   | talorai-qa-100-remote-state   |
| prod | talorai-prod-100 | talorai-prod-100-remote-state |
| demo | talorai-demo-100 | talorai-demo-100-remote-state |

## Directory Conventions

- `modules/<name>/` — one child module per infrastructure concern
- Each module has exactly: main.tf, variables.tf, outputs.tf, versions.tf
  (plus iam.tf when the module manages IAM resources)
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

## Module Authoring Rules

- Every variable must have a `description` and a `type`
- Use `validation` blocks on variables where constraints exist.
  When a variable has a `validation` condition (e.g. `contains([...], var.x)`),
  ensure any supplied or default value matches the allowed set.
- Keep variables and outputs in lexicographic order
  - But if variables will go into the same resource argument block, sparingly group them together
  - Groups use the `# ── Group Name ──` comment header, padded with emdashes
    so the line is 79 characters long (last char at column 80 in a 1-indexed editor).
    Example: `# ── Data Disk ────────────────────────────────────────────────────────────────`
  - Sparingly group related outputs together, with group comment header
  - Ungrouped variables/outputs go in lexicographic order AFTER all groups, not inside
    a preceding group's section. A group header's scope ends at the next group header
    or at the start of the ungrouped tail.
- Environment stack modules may group related resources together with the group comment header
- Expose only what consumers need via `outputs.tf`
- Pin provider version constraints in each module's `versions.tf`
- Never hardcode project IDs, project numbers, locations, regions, or zones — accept them as variables
- Source path from env root to module: `source = "../../modules/<name>"`
- Place all IAM resources in `iam.tf`. Only create this file when the module has
  IAM resources. IAM resource types:
  - `google_service_account`, `google_service_account_key`,
    `google_service_account_iam_*`
  - `google_project_iam_member`, `google_project_iam_binding`,
    `google_project_iam_policy`, `google_project_iam_audit_config`
  - `google_project_iam_custom_role`, `google_organization_iam_custom_role`
  - `google_organization_iam_*`, `google_folder_iam_*`,
    `google_billing_account_iam_*`
  - `google_cloud_identity_group`, `google_cloud_identity_group_membership`
  - Any other `*_iam_member`, `*_iam_binding`, `*_iam_policy` resources
    (e.g. `google_storage_bucket_iam_member`)
- If a module has a variable for `labels`, enviroment should pass in `local.common_labels` (or a merge of this with other module-specific labels)

## Resource argument ordering

Add arguments to a resource in this order, but only if applicable

- `count` or `for_each` FIRST, separated from rest by a newline
- `provider`
- `name` or equivalent for that resource, ex. `secret_id` for `google_secret_manager_secret`
- `description`
- Resource Specific Naming arguments, detailed in section below. When the resource type matches, include the arguments nested beneath in that section
- Location hierarchy. Where is this resource located?
  - `project`
  - `location`
  - `region`
  - `zone`
  - `network`
  - `subnetwork`
- remamining string, number, boolean, and array arguments; unless mentioned below
- arguments that are a block/object must be separated from other arguments by newlines. Leading newline omitted if first line in a scope
- `source_ranges`
- `destination_ranges`
- `effective_labels`
- `labels`
- `target_tags`
- `lifecycle`
- `depends_on`

### Resource Specific Naming

- `google_compute_global_address`
  - `address`
- `google_compute_subnetwork`
  - `ip_cidr_range`
- `cloudflare_record`
  - `type`
- `google_firebase_web_app`
  - `display_name`
- `google_sql_database`
  - `instance`
- `google_sql_user`
  - `instance`

### Examples

```hcl
resource "google_compute_subnetwork" "internal" {
  name                     = "sub-internal"
  ip_cidr_range            = "10.0.1.0/26"
  project                  = var.project_id
  region                   = var.gcp_region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}

resource "google_compute_global_address" "managed" {
  name          = "managed"
  address       = "10.240.0.0"
  project       = var.project_id
  network       = google_compute_network.vpc.id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20

  labels = var.labels
}

resource "google_project_iam_member" "artifact_registry_reader" {
  count   = var.service_account_email != null ? 1 : 0

  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${var.service_account_email}"
}
```

## Secrets

- Provider credentials: GitHub Actions secrets + service account keys
- App-level secrets: GCP Secret Manager, referenced via data sources
- NEVER put secrets in .tfvars files or backend.tf

## Things to Watch Out For

- Firebase resources require `google-beta` provider, not `google`
- Mailgun provider (`wgebis/mailgun`) requires `region` ("us" or "eu")
- Rollbar needs account-level API key for projects, project-level for notifications
- Cloudflare API tokens should be scoped per zone, not global keys
- Backend blocks CANNOT use variables or interpolation of any kind
- `google_project_iam_member` requires an explicit `project` argument — it does NOT
  inherit project from the provider config. Same applies to other project-level IAM
  resources. Always verify required arguments against the Terraform Registry.
- Never run `terraform validate` inside a `modules/` directory — modules have no
  provider or backend config. Validate from an env root (`environments/<env>/`).
- Identity Platform multi-tenancy CAN be enabled via Terraform using the
  `multi_tenant` block in `google_identity_platform_config` (google provider ≥ 7.21).
  See: registry.terraform.io/providers/hashicorp/google/latest/docs/resources/identity_platform_config#nested_multi_tenant
