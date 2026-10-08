# Authoring reference

Style rules for modules and stacks. Upstream `AGENTS.md` is authoritative; this is the
working summary.

## Module files

```
<module>/
├── main.tf          most resources
├── variables.tf     every variable AND locals (locals.tf is deprecated)
├── outputs.tf       every output
├── versions.tf      required_version + required_providers with version constraints
├── README.md        one-line description + empty <!-- BEGIN_TF_DOCS --> / <!-- END_TF_DOCS -->
├── data.tf          data sources, when needed
├── iam.tf           IAM resources (below), when needed
├── <topic>.tf       lb.tf, monitoring.tf, secrets.tf … when main.tf would be unwieldy
├── state.tf         moved blocks for the module's own refactors, when needed
└── tests/<module>.tftest.hcl
```

Never `backend.tf`, `providers.tf`, or `terraform.tfvars` in a module (stackules
excepted). Templates a module renders (`startup.sh.tftpl`) ship inside the module and
are read with `"${path.module}/…"`.

## What belongs in `iam.tf`

`*_iam_member`, `*_iam_policy`, `*_iam_custom_role`, `*_iam_audit_config`,
`google_service_account`, `google_service_account_key`, `google_cloud_identity_group`,
`google_cloud_identity_group_membership`, `kubernetes_service_account`.

Prefer `google_service_account.x.member` over `"serviceAccount:${…email}"`. Stacks that
publish identities output both `<name>_email` and `<name>_member`, because a binding in
another stack can't call `.member`.

A module may create a service account and bind it entirely within itself (nothing
outside depends on that timing). A service account that **other** stacks bind belongs
in the project's `identities` stack.

## Variables

- Every variable has a `description` and an explicit `type`; add `validation` wherever
  a constraint exists, and make defaults satisfy it.
- **No presence toggles.** A boolean may tune a resource's argument (`deletion_protection`,
  `enable_iam_authentication` on an instance that always exists); it may not decide
  whether a feature exists in an environment.
- Never hard-code project IDs, project numbers, regions, zones. For resources that may
  be regional or zonal: `gcp_region` + `gcp_zone` (default `null`),
  `location = coalesce(var.gcp_zone, var.gcp_region)`.
- A module that takes `labels` receives `local.common_labels` (or a merge) from the stack:
  `{ environment, managed_by = "terraform", platform }`, built from the declaration modules.

## Grouping and ordering

- Group header: `# ── Group Name ──…` padded with U+2500 to **exactly 80 characters**
  (count characters, not bytes; `wc -c` and `awk length()` lie).
- Variable groups first, in order **Naming, Location, Network**, then any other sparing
  groups; ungrouped variables follow in lexicographic order. A header's scope ends at
  the next header or the ungrouped tail. Same rules for outputs.
- Resource argument order:
  1. `count` / `for_each`, then `provider` — blank line after
  2. Naming (`name`, `display_name`, `description`, `address`, `instance`, `secret_id`, `type`, …)
  3. Location (`project`, `location`, `region`, `zone`, …)
  4. Network (`network`, `subnetwork`) — blank line after
  5. Other scalars, A–Z
  6. Complex arguments and blocks, A–Z, separated by blank lines
  7. Tail, in strict order: `source_ranges`, `destination_ranges` · `labels`, `target_tags` · `lifecycle` · `depends_on`

## Stacks

- `main.tf` opens with `# ── Bootstrap ──` calling `this_org`, `this_platform`,
  `this_environment`, `this_project` as needed. Stack variables are only: project
  identity (from the symlinked tfvars), stack-specific settings, and secrets (`TF_VAR_*`).
- `providers.tf` configures providers from `var.project_id` / `var.gcp_region`; Kubernetes
  and Helm providers are built from `seed` remote state + `google_client_config`.
- Secrets never go in `.tfvars` or `backend.tf`. App secrets live in Secret Manager;
  values are added out of band unless Terraform generates them.

## Tests

Native `tofu test` only (no Terratest). `<module>/tests/<module>.tftest.hcl`:

- one `mock_provider` per required provider; no real credentials
- `command = plan` by default; `apply` only to inspect set-typed nested blocks or computed attrs
- `expect_failures` to prove validations
- never assert GCP-computed values (`self_link`, `id`, `etag`) in plan runs

```bash
tofu -chdir=<module> init -backend=false && tofu -chdir=<module> test
```

## New module workflow

1. Read a similar module and a stack that wires modules (upstream:
   `tf/_impl/gcp-projects/terralab-dev-100/gcp-project-stacks/main/`).
2. Verify every resource argument against the provider registry; don't assume
   inheritance of `project`/`region` from the provider.
3. Scaffold the files above in `tf/gcp-projects/gcp-project-modules/<name>/`.
4. Wire it into a terralab project stack, `tofu fmt`, `validate` from the stack, `tofu test`.
5. Release a minor (additive) or major (breaking) tag; downstream picks up minors via the
   moving major tag.
