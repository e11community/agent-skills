---
name: terraform
description: Use when authoring, reviewing, or modifying Terraform for a multi-environment (dev/ci/qa/demo/prod) GCP + Cloudflare + Mailgun + Rollbar infrastructure repo that uses separate root modules per environment, per-stack GCS backends, and GitHub Actions plan/apply/drift CI/CD.
---

# Terraform Multi-Environment Infrastructure

## Overview

This skill describes conventions for a Terraform repo that provisions cloud
infrastructure across five environments — **dev, ci, qa, demo, prod** (these
five always exist, regardless of platform). Each environment owns one or more
**stacks**; each stack is a separate root module under
`hcl/environments/<env>/<stack>/`. Its `main.tf` explicitly declares which child
modules it uses. Shared per-project child modules live in `hcl/modules/`.

A repo may also manage **GCP Organization-wide** resources (folders, org IAM,
org policies, org log sinks, billing IAM). Organization resources are singletons
— there is one organization, not one per environment — so this layer is
environment-agnostic and NOT parameterized by dev/ci/qa/demo/prod. It has two
parts: child modules in `hcl/org-modules/<module>/` and the root modules that
wire them in `hcl/org-stacks/<stack>/`. All org-stacks store their state in the
**prod** project's bucket under prefix `org-stacks/<stack>`. See
"Organization-Wide Modules" and "Organization-Level Stacks" below.

**Core principle:** module presence is expressed structurally — a module block
is either present in a stack's `main.tf` or it isn't. Never gate modules with
`count` + `enable_*` booleans.

`terraform-repo-layout.md` in this directory is the canonical structural
reference — full directory tree, file templates, env/stack wiring, provider
config, CI/CD, and example modules. **Read it before writing or modifying any
Terraform.**

## Placeholders & Examples (read first)

This skill is a reusable template. Two things are deliberately generic:

- **`PLATFORM`** is a placeholder for the real platform/project short name. The
  examples use project IDs like `PLATFORM-dev-100` and the label
  `platform = "PLATFORM"`. In a realized repo, replace every `PLATFORM` with the
  actual platform name.
- **Module and stack names are examples.** Names like `networking`, `cloud-run`,
  `firebase`, and the stack `main` are illustrative — they do not necessarily
  exist in any given repo. In a realized repo, use the actual module and stack
  names present there.

The five environment names (dev, ci, qa, demo, prod) are NOT placeholders —
assume they always exist.

## When to Use

- Adding, removing, or editing child modules in `hcl/modules/`
- Sourcing a module from another (often cross-org) **private repo** via a
  `git::` source — see "Reusing Modules Across Repos"
- Adding, removing, or editing GCP Organization-wide child modules in
  `hcl/org-modules/` (folders, org IAM, org policies, org log sinks)
- Wiring org-modules into an org-stack (`hcl/org-stacks/<stack>/main.tf`)
- Wiring modules into a stack (`hcl/environments/<env>/<stack>/main.tf`)
- Promoting a module from a lower environment to a higher one
- Editing providers, backends, variables, locals, or tfvars
- Setting up the GitHub Actions plan/apply/drift workflows
- Bootstrapping this layout into a new repo (see "Installing into a repo")

## Architecture Decision: Separate Root Modules Per Environment

Separate root modules (not one root with feature-flag booleans) because
environments have structural variance — new modules roll out to lower
environments before promotion to upper ones. The diff in a promotion PR is
literally "add these lines to `hcl/environments/prod/<stack>/main.tf`."

Do NOT use `count` with `enable_*` booleans to control module presence.

## Stacks

A **stack** is a root module directory under an environment:
`hcl/environments/<env>/<stack>/`. Each stack has its own `backend.tf` whose
GCS `prefix` equals the stack name, so multiple stacks share one project state
bucket without colliding. `main` is the conventional default stack. Add a new
stack by creating a new subdirectory with the standard root-module files.

## Environment → GCP Project → State Bucket Mapping

| Env  | GCP Project ID    | State Bucket                     |
| ---- | ----------------- | -------------------------------- |
| dev  | PLATFORM-dev-100  | PLATFORM-dev-100-remote-state    |
| ci   | PLATFORM-ci-100   | PLATFORM-ci-100-remote-state     |
| qa   | PLATFORM-qa-100   | PLATFORM-qa-100-remote-state     |
| demo | PLATFORM-demo-100 | PLATFORM-demo-100-remote-state   |
| prod | PLATFORM-prod-100 | PLATFORM-prod-100-remote-state   |

State bucket name = `<project-id>-remote-state`, one bucket per GCP project.
Backend `prefix` = stack name.

## Providers (verified registry sources)

| Service    | Provider source         | Notes                                                         |
| ---------- | ----------------------- | ------------------------------------------------------------- |
| GCP        | `hashicorp/google`      | registry.terraform.io/providers/hashicorp/google              |
| GCP Beta   | `hashicorp/google-beta` | registry.terraform.io/providers/hashicorp/google-beta         |
| Firebase   | `hashicorp/google-beta` | No separate firebase provider. Resources live in google-beta. |
| Cloudflare | `cloudflare/cloudflare` | registry.terraform.io/providers/cloudflare/cloudflare         |
| Mailgun    | `wgebis/mailgun`        | registry.terraform.io/providers/wgebis/mailgun                |
| Rollbar    | `rollbar/rollbar`       | registry.terraform.io/providers/rollbar/rollbar               |

## Directory Conventions

- `hcl/modules/<name>/` — one per-project child module per infrastructure concern
- `hcl/org-modules/<name>/` — one child module per GCP Organization-wide concern
  (folders, org IAM, org policies, org log sinks). Same file convention as
  `hcl/modules/`. See "Organization-Wide Modules".
- Each module has exactly: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`
  (plus `iam.tf` when the module manages IAM resources)
- `hcl/org-stacks/<stack>/` — one root module per GCP Organization-level stack.
  Same root-module file set as an environment stack (below). State lives in the
  prod bucket; prefix = `org-stacks/<stack>`. See "Organization-Level Stacks".
- Source path from an org-stack root to an org-module: `source =
  "../../org-modules/<name>"` (two levels up: `<stack>` → `org-stacks` → `hcl`)
- `hcl/environments/<env>/<stack>/` — one root module per env+stack
- Each stack root has: `main.tf`, `providers.tf`, `variables.tf`, `outputs.tf`,
  `versions.tf`, `backend.tf`, `locals.tf`, `data.tf`, `terraform.tfvars`
- `hcl/tests/*.tftest.hcl` — native Terraform tests (v1.6+)
- Source path from a stack root to a module: `source = "../../../modules/<name>"`
  (three levels up: `<stack>` → `<env>` → `environments` → `hcl`)

## Key Commands

```bash
# Work in a specific environment + stack
cd hcl/environments/dev/main
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Or from repo root with chdir
terraform -chdir=hcl/environments/dev/main init
terraform -chdir=hcl/environments/dev/main plan

# Run tests
terraform test

# Lint (recursive)
tflint --init && tflint --recursive

# Format check
terraform fmt -check -recursive
```

## Module Authoring Rules

- Every variable must have a `description` and a `type`.
- Use `validation` blocks where constraints exist. When a variable has a
  `validation` condition (e.g. `contains([...], var.x)`), ensure any supplied or
  default value matches the allowed set.
- Keep variables and outputs in lexicographic order.
  - If variables feed the same resource argument block, sparingly group them.
  - Groups use a `# ── Group Name ──` comment header, padded with emdashes so the
    line is 79 characters long (last char at column 80 in a 1-indexed editor):
    `# ── Data Disk ────────────────────────────────────────────────────────────────`
  - Sparingly group related outputs the same way.
  - Ungrouped variables/outputs go in lexicographic order AFTER all groups, not
    inside a preceding group. A group header's scope ends at the next group
    header or at the start of the ungrouped tail.
- Stack (environment root) modules may group related resources with the group
  comment header.
- Expose only what consumers need via `outputs.tf`.
- Pin provider version constraints in each module's `versions.tf`.
- Never hardcode project IDs, project numbers, locations, regions, or zones —
  accept them as variables.
- Place all IAM resources in `iam.tf`. Only create the file when the module has
  IAM resources. IAM resource types:
  - `google_service_account`, `google_service_account_key`,
    `google_service_account_iam_*`
  - `google_project_iam_member`, `google_project_iam_binding`,
    `google_project_iam_policy`, `google_project_iam_audit_config`
  - `google_project_iam_custom_role`, `google_organization_iam_custom_role`
  - `google_organization_iam_*`, `google_folder_iam_*`,
    `google_billing_account_iam_*`
  - `google_cloud_identity_group`, `google_cloud_identity_group_membership`
  - Any other `*_iam_member`, `*_iam_binding`, `*_iam_policy` resource
    (e.g. `google_storage_bucket_iam_member`)
- If a module has a `labels` variable, the stack should pass `local.common_labels`
  (or a merge of it with module-specific labels).

## Resource Argument Ordering

Add arguments to a resource in this order, but only if applicable:

- `count` or `for_each` FIRST, separated from the rest by a newline
- `provider`
- `name` or equivalent (e.g. `secret_id` for `google_secret_manager_secret`)
- `description`
- Resource-specific naming arguments (see below)
- Location hierarchy: `project`, `location`, `region`, `zone`, `network`,
  `subnetwork`
- remaining string, number, boolean, and array arguments (unless listed below)
- block/object arguments, separated from other arguments by newlines (leading
  newline omitted if first line in a scope)
- `source_ranges`
- `destination_ranges`
- `effective_labels`
- `labels`
- `target_tags`
- `lifecycle`
- `depends_on`

### Resource-Specific Naming

- `google_compute_global_address` → `address`
- `google_compute_subnetwork` → `ip_cidr_range`
- `cloudflare_record` → `type`
- `google_firebase_web_app` → `display_name`
- `google_sql_database` → `instance`
- `google_sql_user` → `instance`

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
  count = var.service_account_email != null ? 1 : 0

  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${var.service_account_email}"
}
```

## New Module Workflow

When creating a new child module, follow this sequence exactly:

1. **Read context first.** Read `terraform-repo-layout.md`, then read an existing
   module similar to what you're building (its main.tf, variables.tf, outputs.tf,
   versions.tf). Read `hcl/environments/dev/main/main.tf` to see how modules are
   wired, and `hcl/environments/dev/main/providers.tf` to see what the provider
   config supplies.
2. **Verify resource arguments against the Terraform Registry.** Do not assume a
   resource inherits `project`, `region`, or other arguments from the provider —
   check the docs. If a required argument isn't supplied by the provider, accept
   it as a variable in the module.
3. **Scaffold the module files** in `hcl/modules/<name>/`: main.tf, variables.tf,
   outputs.tf, versions.tf (plus iam.tf if it manages IAM).
4. **Wire the module into a dev stack** (`hcl/environments/dev/main/main.tf`)
   before validating. Add a `module "<name>"` block with source and all required
   variables.
5. **Validate from the stack root, not the module directory.** Modules have no
   backend or provider config — `terraform validate` in a module dir will fail or
   mislead. Always:
   ```bash
   cd hcl/environments/dev/main
   terraform init -upgrade
   terraform validate
   ```

## Reusing Modules Across Repos (private git sources)

Most modules here are local (`source = "../../../modules/<name>"`). To reuse a
module that lives in **another repo** — often a **different org** — Terraform
supports git sources via go-getter:

```hcl
module "shared_networking" {
  source = "git::https://github.com/other-org/tf-modules.git//networking?ref=v1.4.0"

  project_id = var.project_id
  # ...module inputs
}
```

- `git::` forces the git getter. Use the **HTTPS** form (not `git@…`) so the
  credential rewrite below applies.
- `//` separates the repo from the **subdirectory** of the module within it
  (omit it when the repo root *is* the module).
- `?ref=` pins a **tag or commit SHA** — always pin, for the same reason you pin
  provider versions. A moving branch ref makes builds non-reproducible.

### Auth: Repo Reacher (CI)

The default `GITHUB_TOKEN` can read only the workflow's own repo, so cloning a
private module repo in another org fails. Authorize it once at the top of the job
with [`e11community/repo-reacher`](https://github.com/e11community/repo-reacher) —
a GitHub App that mints scoped, short-lived tokens and rewrites global git config
so every later `git::https://github.com/<owner>/…` clone (and therefore
`terraform init`) authenticates transparently:

```yaml
steps:
  - uses: e11community/repo-reacher@v1
    env:
      # An action can't read vars/secrets by name — map them in here once.
      REPO_REACHER_APP_ID: ${{ vars.REPO_REACHER_APP_ID }} # org/repo variable (App ID, not secret)
      REPO_REACHER_KEY: ${{ secrets.REPO_REACHER_KEY }} # org/repo secret (App private key, PEM)
    with:
      friends: |
        other-org # owner(s) whose private module repos you source
      # permissions: contents:read   # default — least privilege needed to clone
  - uses: actions/checkout@v6
  - run: terraform -chdir=hcl/environments/dev/main init
```

The `REPO_REACHER_APP_ID` **variable** and `REPO_REACHER_KEY` **secret** must
exist in each org that runs these workflows — a one-time setup (org-level is
cleanest). No per-module tokens, no credentials in `source`. (Locally, give your
laptop's git its own GitHub credential so `init` can clone the same private
sources — see repo-reacher's `docs/MACOS.md`.)

### Run `terraform init` after adding or re-pinning a git source

Terraform fetches remote modules into `.terraform/modules/` at **`init`** time —
nothing reads the remote repo during `plan`/`validate`. So after you **add a new
git-sourced `module` block, or change its `?ref=`**, run init (use `-upgrade` to
re-fetch a moved ref):

```bash
terraform -chdir=hcl/environments/dev/main init -upgrade
```

This isn't only for planning. The **Terraform language server (`terraform-ls`)
can only introspect a remote module once it's present in `.terraform/modules/`.**
Until you init, the editor has nothing to read for that block — **no
autocompletion of the module's input variables/outputs, no go-to-definition, no
validation.** The classic symptom: you add a `module "x"` with a git source,
start typing its inputs, and the editor offers nothing — run `init` and
IntelliSense lights up. Re-init after bumping the `ref`, or the editor keeps
offering the *old* version's inputs.

## Organization-Wide Modules (`hcl/org-modules/`)

GCP Organization-level resources (folders, org IAM, org policies, org log sinks,
billing IAM) are managed by child modules under `hcl/org-modules/<name>/`. They
follow the same conventions as `hcl/modules/` modules, with these differences:

- **Singletons, not per-environment.** There is one GCP Organization, so an
  org-module is NOT parameterized by `environment` and is never promoted across
  dev/ci/qa/demo/prod. Do not add an `environment` variable or env-specific
  branching to an org-module.
- **Scope by `org_id`, not `project_id`.** Org-level resources are anchored to
  the organization (and sometimes a `folder_id` or `billing_account`). Accept
  `org_id` (and `folder_id` / `billing_account` where relevant) as variables;
  never hardcode them. Most org-modules take no `project_id` at all.
- **Self-contained child modules.** Like any module, an org-module defines no
  provider or backend config of its own — it declares `required_providers` in
  `versions.tf` and is wired into an org-stack (`hcl/org-stacks/<stack>/`), which
  supplies provider config and state. File set: `main.tf`, `variables.tf`,
  `outputs.tf`, `versions.tf`, plus `iam.tf` when it manages IAM.
- **Most org resources do not support `labels`.** Folders, org IAM bindings, and
  org policies have no `labels` argument, so an org-module usually omits the
  `labels` variable. Add it only for resources that actually accept labels
  (verify against the Registry).
- **IAM-centric modules still use `iam.tf`.** An org-module whose purpose is IAM
  (e.g. an `org-iam` module) puts its `google_organization_iam_*` /
  `google_billing_account_iam_*` / `google_folder_iam_*` resources in `iam.tf`;
  `main.tf` may then hold only data sources/locals or be minimal.

Common org-level resource types (verify each against the Terraform Registry
before use — do not guess argument names):

- `google_folder`, `google_folder_iam_*`
- `google_organization_iam_member` / `_binding` / `_policy` / `_audit_config`
- `google_organization_iam_custom_role`
- `google_org_policy_policy` (Org Policy v2)
- `google_logging_organization_sink`, `google_logging_organization_bucket_config`
- `google_billing_account_iam_member` / `_binding`
- `google_essential_contacts_contact` (parented to the org)
- `google_tags_tag_key` / `google_tags_tag_value` (org-scoped)

**Validation:** like any child module, never run `terraform validate` inside an
`hcl/org-modules/` directory — modules have no provider or backend config.
Validate from the org-stack root that wires the module:

```bash
cd hcl/org-stacks/<stack>
terraform init -upgrade
terraform validate
```

See `terraform-repo-layout.md` for example org-modules and org-stacks.

## Organization-Level Stacks (`hcl/org-stacks/`)

An **org-stack** is a root module under `hcl/org-stacks/<stack>/` that wires
org-modules, exactly as an environment stack wires per-project modules. It has
the same root-module file set: `main.tf`, `providers.tf`, `variables.tf`,
`outputs.tf`, `versions.tf`, `backend.tf`, `locals.tf`, `data.tf`,
`terraform.tfvars`. Differences from environment stacks:

- **State always lives in the prod bucket.** The prod project ID is fixed for
  ALL org-stacks — the organization is not owned by any one environment, and
  prod is the designated home. Every org-stack's `backend.tf` is:

  ```hcl
  # Remember, no var or interpolation
  terraform {
    backend "gcs" {
      bucket = "PLATFORM-prod-100-remote-state"
      prefix = "org-stacks/<stack>"
    }
  }
  ```

  Replace `PLATFORM` with the platform name and `<stack>` with the stack name.
- **Prefix is `org-stacks/<stack>`, not just the stack name.** This is a
  deliberate deviation from the environment-stack rule (where prefix = stack
  name). The `org-stacks/` segment namespaces all org state within the shared
  prod bucket so it never collides with prod's environment stacks.
- **No `environment` variable.** Org-stacks are environment-agnostic. Scope by
  `org_id` (and `billing_account` / `folder_id` where needed). The provider's
  quota/billing `project` is the prod project ID (fixed), accepted as
  `project_id`.
- **Module source path is two levels up:** `source = "../../org-modules/<name>"`
  (`<stack>` → `org-stacks` → `hcl`), versus three levels for environment stacks.
- **The executing identity needs org-level roles.** Whatever service account
  runs the org-stack plan/apply must hold the relevant organization-level roles
  (e.g. `roles/resourcemanager.organizationAdmin`,
  `roles/orgpolicy.policyAdmin`), not just prod-project roles.

Add a new org-stack by creating `hcl/org-stacks/<stack>/` with the standard
root-module files and the `backend.tf` above.

## Promoting Modules Across Environments

1. Build the module in `hcl/modules/<name>/` with full variable/output contracts.
2. Wire it into a dev stack first.
3. After validation, copy the module block to ci → qa → prod → demo in separate
   PRs. The PR diff IS the promotion — reviewers see exactly what's introduced.
4. Do NOT use feature-flag booleans (`enable_x = true/false`).

## State & Backend

- One GCS bucket per GCP project (`<project-id>-remote-state`).
- Each environment stack's `backend.tf` hardcodes bucket + prefix (prefix =
  stack name).
- Org-stacks are the exception: they ALL use the prod bucket
  (`PLATFORM-prod-100-remote-state`) with prefix `org-stacks/<stack>`. See
  "Organization-Level Stacks".
- Backend blocks CANNOT use variables or interpolation of any kind — the backend
  is resolved during `init`, before any HCL evaluation.
- Never run `terraform state` commands manually. Prefer in-HCL blocks:
  - `moved` blocks over `terraform state mv`
  - `import` blocks over `terraform import` CLI
  - `removed` blocks with `lifecycle { destroy = false }` over `terraform state rm`

## Secrets

- Provider credentials: GitHub Actions secrets + GCP service account key.
  Secret `GCP_SA_KEY` is the default; if a service performs compute, use
  `GCP_COMPUTE_SA_KEY`.
- App-level secrets: GCP Secret Manager, referenced via data sources.
- NEVER put secrets in `.tfvars` files or `backend.tf`.

## Naming & Labels

Labels always include: `environment`, `managed_by = "terraform"`, and
`platform = "PLATFORM"`.

## Formatting & Linting

- `.tf` / `.tfvars`: `terraform fmt` for formatting, `tflint` for linting.
- Prettier and ESLint do NOT understand HCL — keep `*.tf` in their ignore files.
- After editing Terraform, run `terraform fmt` and `terraform validate` (from a
  stack root, never a module dir).

## CI/CD

GitHub Actions workflows (see `terraform-repo-layout.md` and the shipped files in
`.github/workflows/`):

- `tf-plan.yml` — reusable plan workflow, keyed by GCP `project_id`; posts the
  plan as a PR comment.
- `tf-plan-matrix.yml` — PR trigger; detects changed environments and fans out to
  `tf-plan.yml` per project.
- `tf-apply.yml` — apply on push to the deploy branch or via `workflow_dispatch`.
- `tf-drift.yml` — scheduled drift detection; opens a GitHub Issue on drift.

Auth uses `google-github-actions/auth@v2` with `credentials_json` from
`secrets.GCP_SA_KEY`. The environment name is derived from the project ID
(`PLATFORM-<env>-100`).

For org-stacks the working directory is `hcl/org-stacks/<stack>/` and the
project is always the prod project (`PLATFORM-prod-100`). The credentials used
must belong to an identity that holds organization-level roles, not just
prod-project roles.

## Things to Watch Out For

- Firebase resources require the `google-beta` provider, not `google`.
- Mailgun provider (`wgebis/mailgun`) requires `region` ("us" or "eu").
- Rollbar needs an account-level API key for projects, project-level for
  notifications.
- Cloudflare API tokens should be scoped per zone, not global keys.
- `google_project_iam_member` requires an explicit `project` argument — it does
  NOT inherit project from the provider config. Same for other project-level IAM
  resources. Always verify required arguments against the Terraform Registry; do
  not guess names from patterns.
- Backend blocks CANNOT use variables or interpolation of any kind.
- Never run `terraform validate` inside a `hcl/modules/` directory — validate
  from a stack root (`hcl/environments/<env>/<stack>/`).
- Identity Platform multi-tenancy CAN be enabled via Terraform using the
  `multi_tenant` block in `google_identity_platform_config` (google ≥ 7.21):
  registry.terraform.io/providers/hashicorp/google/latest/docs/resources/identity_platform_config#nested_multi_tenant
- `google_app_engine_application` silently provisions a Firestore in Datastore mode.
- A git-sourced (`git::https://…?ref=`) module is invisible to `terraform-ls`
  until `terraform init` fetches it into `.terraform/modules/` — no IntelliSense
  for its inputs/outputs until then, and re-init after changing `?ref=`. Cloning
  private cross-org sources in CI needs Repo Reacher. See "Reusing Modules Across
  Repos".

## Installing into a Repo

This skill ships ready-to-use assets. When bootstrapping the layout into a repo,
copy them to the project root:

- `.github/workflows/tf-plan.yml`, `tf-plan-matrix.yml`, `tf-apply.yml`,
  `tf-drift.yml` → `<project-root>/.github/workflows/`
- `.terraform-version` → `<project-root>/.terraform-version`

Then create the remaining structure and template files (modules, org-modules,
environments, org-stacks, tests, scripts, `.tflint.hcl`, `.editorconfig`,
`.gitignore`, `.pre-commit-config.yaml`, etc.) from `terraform-repo-layout.md`.
Create `hcl/org-modules/` and `hcl/org-stacks/` only if the repo manages GCP
Organization-wide resources.

After copying, **realize the placeholders**:

1. Replace every `PLATFORM` with the actual platform/project short name (in the
   workflow files, project IDs, state buckets, and the `platform` label).
2. Replace the example module and stack names with the repo's actual names.
3. Confirm the five environments (dev, ci, qa, demo, prod) and verify each GCP
   project ID and state bucket exists.
