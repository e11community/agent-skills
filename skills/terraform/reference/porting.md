# Porting a flat Terraform layout into the regime

The common source shape: one root module per feature (`infra/<feature>/`), an
`environments/<env>.tfvars` per environment, a partial `backend "gcs" {}` filled with
`-backend-config` at init, `count` toggles for "not in this environment", and applies
from a laptop. This is the checklist for bringing such a root into the regime without
recreating anything live.

## 1. Inventory before designing

For every root × environment, record:

- [ ] Does the state object exist? `gcloud storage ls gs://<project>-remote-state/`
- [ ] Resource count and `terraform_version` in it (read metadata only — state may hold secrets):
      `gcloud storage cat …/default.tfstate | jq '{tv:.terraform_version, n:(.resources|length)}'`
- [ ] Does the code still declare everything the state holds? (A root whose state has
      resources its code dropped will **destroy** them on the next apply.)
- [ ] Which binary wrote it — a `registry.terraform.io` lock file or a `terraform_version`
      newer than the regime's `TOFU_VERSION` means `tofu` may refuse or need a provider
      address rewrite.
- [ ] Every hard-coded value that is really another stack's output or a fact
      (project numbers, default compute SA emails, instance connection names).
- [ ] Every toggle (`count = var.x == "" ? 0 : 1`, `enable_*`, `deploy_*`) and what it
      really means: environment presence, bring-up sequencing, or "owner not yet named".
- [ ] Objects created by hand that the root depends on (networks, bastions, topics,
      DNS records) — they become either adopted resources or documented prerequisites.

## 2. Decide the shape

| Source construct | Regime construct |
| --- | --- |
| `infra/<feature>/` root | Module `tf/gcp-projects/gcp-project-modules/<feature>` upstream + a `<feature>` stack (or a block in an existing stack) per project that has it |
| `environments/<env>.tfvars` existing for env X | The stack directory exists under `<platform>-<env>-NNN` |
| A tfvars file missing for env Y | The stack directory is absent in that project |
| `count` toggle = environment presence | Module block present / absent |
| `count` toggle = bring-up sequencing | Split into two stacks applied in order |
| `count` toggle = "nobody named yet" (empty email) | One owner stack for notification channels; consumers take a list of channel IDs |
| `gcp_project` / `environment` variables | Generated `gcp-project.auto.tfvars`; `module.this_environment` |
| SA created and bound in the same root | SA moves to `identities`; bindings stay in the feature stack |
| Grants to a deploy SA | Usually redundant: `github-actions@<project>` already has project roles; add any missing role upstream to `project_roles` |
| Cross-root reference by string | `terraform_remote_state` of the owning stack |
| Manual shell step (`gcloud …`, DNS script) | A resource, a stack in its own scope (e.g. a DNS zone), or an explicitly documented manual step |

## 3. Move state, don't recreate

Default (state exists and is trustworthy): **carry it**.

1. Freeze the source root (no applies; announce it).
2. Copy the state object to the new prefix
   (`gs://<project>-remote-state/<old-prefix>/default.tfstate` →
   `…/gcp-project-stacks/<stack>/default.tfstate`), or `tofu init -migrate-state` after
   pointing the source's backend at the new prefix.
3. In the new stack's `state.tf`, `moved { from = google_x.y  to = module.<feature>.google_x.y }`
   for every address that now lives in a module.
4. Plan. Required: **0 to add, 0 to destroy, 0 to replace** except changes you list and
   approve. Anything else is a mapping bug or real drift — resolve it before applying.
5. Apply, delete the `moved` blocks (leave a dated comment), archive the old prefix.

Fallback (state absent, empty, or unreadable by `tofu`): **adopt with `import` blocks**
in `state.tf`, same zero-diff gate. Resources that cannot be imported (e.g.
`terraform_data`) are re-created only if their side effect is idempotent; otherwise
replace them with a real resource first.

Never run both roots against the same objects: once a resource is in the new state,
remove the source root (or `removed { lifecycle { destroy = false } }` there) the same day.

## 4. Converge through CI

- Bootstrap any project the source used that the regime doesn't yet manage (human
  `remote-state`, then `bootstrap` mode from a production branch).
- Add new stack names to upstream `pipeline.conf` in the right order.
- After the zero-diff apply, the stack is CI-converged: PR plans, merge applies,
  nightly drift. Laptop applies stop.
