# Layout reference

Everything lives under `tf/`. The split is **reusable definitions** (upstream, name no
real project) versus **`tf/_impl/`** (concrete instantiations with real IDs).

## Reusable definitions (engineering11/sdk-terraform)

| Path | Scope |
| --- | --- |
| `tf/gcp-base/gcp-base-modules/` | Provider-free constants (named Google CIDRs) |
| `tf/gcp-organizations/gcp-organization-modules/main` | Org facts (outputs only) |
| `tf/gcp-organizations/gcp-organization-stackules/` | Org whole-stack bodies (reserved) |
| `tf/gcp-folders/gcp-folder-modules/{main,bootstrap-admin}` | Folder facts; bootstrap-admin's folder roles + billing |
| `tf/platforms/platform-modules/main` | Platform facts: `platform`, `github_org`, production ref regex + branch patterns |
| `tf/platforms/platform-gcp-project-modules/` | Platform × project (e.g. `bootstrap-admin` SA + federation) |
| `tf/platforms/platform-gcp-organization-modules/` | Platform × org (Cloud Identity groups) |
| `tf/platforms/platform-github-repository-modules/main` | Platform × repo: `protect-default`, `production-branches`, environments |
| `tf/github-repositories/github-repository-modules/` | Repo, no platform (e.g. `branch-ruleset`) |
| `tf/gcp-projects/gcp-project-modules/<name>` | Per-project building blocks |
| `tf/gcp-projects/gcp-project-stackules/{remote-state,services}` | Whole-stack bodies |
| `tf/environments/environment-modules/main` | Environment identity schema |
| `tf/environments/environment-declarations/{dev,ci,qa,demo,prod}` | One declaration per environment key |
| `tf/pipeline/` | `run.sh`, `pipeline.conf`, `steps/`, `templates/` |

- **module** — composed with others in a stack's `main.tf`. No `backend.tf`,
  `providers.tf`, or `terraform.tfvars`.
- **stackule** — a module that is the *entire* body of one stack. May carry those files
  as inert templates; don't strip them.
- **stack** — a root module, applied by its own invocation. Exists only under
  `_impl/**/<scope>-stacks/<stack>/`.
- **declaration** — an outputs-only module in `_impl/` (org, folder, platform). Never
  applied; calling it adds nothing to a plan.

## `tf/_impl/` (sdk-terraform's own terralab, or a downstream repo)

```
tf/_impl/
├── gcp-organizations/<domain>/gcp-organization-modules/main/        declaration
├── gcp-folders/<folder>/
│   ├── gcp-folder-modules/main/                                     declaration (folder_id)
│   └── gcp-folder-stacks/bootstrap-admin/                           human-applied; admin bucket
├── platforms/<platform>/platform-modules/main/                      declaration (+ workload_identity_pool)
├── github-repositories/<org>/<repo>/github-repository-stacks/main/  repo admin applies; admin bucket
└── gcp-projects/
    ├── <platform>-admin-100/                                        control plane, environment = "admin"
    │   ├── gcp-project.auto.tfvars
    │   └── gcp-project-stacks/{remote-state,admin}/
    └── <platform>-<env>-<serial>/
        ├── gcp-project.auto.tfvars
        └── gcp-project-stacks/<stack>/…
```

A downstream repo additionally has `tf/sdk-terraform.ref` (e.g. `v3`) and
`tf/pipeline/run.sh` (wrapper; sets `PIPELINE_REPO_ROOT` and `PIPELINE_PROJECT_PREFIX`).
The pipeline cache `tf/.sdk-terraform/` is gitignored.

## Module sources

From a project stack (five levels below `tf/`):

```hcl
# upstream repo (terralab)
source = "../../../../../gcp-projects/gcp-project-modules/<name>"
# downstream repo
source = "git::https://github.com/engineering11/sdk-terraform.git//tf/gcp-projects/gcp-project-modules/<name>?ref=v3"
# downstream's own declarations stay relative
source = "../../../../../_impl/platforms/<platform>/platform-modules/main"
```

Repository stacks sit six levels deep. `vN` is a **moving major tag**; a breaking
upstream release is `vN+1`, adopted by a deliberate sed over `tf/_impl` plus
`tf/sdk-terraform.ref`. CI clones private sources through `e11community/repo-reacher@v1`
(`friends: engineering11/sdk-terraform`) run **before** `actions/checkout` with
`persist-credentials: false`.

## Backends

| Stack kind | Bucket | Prefix | Written by |
| --- | --- | --- | --- |
| project stack | `<project-id>-remote-state` | `gcp-project-stacks/<stack>` | pipeline `gen backends` |
| project `remote-state` | local `terraform.remote-state.tfstate` (gitignored) | — | pipeline, by stack name |
| folder stack | `<platform>-admin-100-remote-state` | `gcp-folder-stacks/<stack>` | hand |
| repository stack | `<platform>-admin-100-remote-state` | `github-repository-stacks/<org>/<repo>/<stack>` | hand |

State buckets are per project, never centralized; the admin bucket holds only the
control plane's and the non-project stacks' state.

## Bootstrap order

```
once per platform:  admin/remote-state → admin/admin → folder/bootstrap-admin   (human)
                    repository stacks                                          (repo admin)
per project:        remote-state                                               (human, local state)
                    → services → identities → github                           (bootstrap-admin, once,
                                                                                from a production branch)
                    → seed → postgresql → postgresql-access
                    → postgresql-gcp-project → main                            (github-actions@<project>)
afterwards:         github-actions@<project> converges every stack (services…main)
```

`pipeline.conf` (upstream) is the authoritative order. A project that lacks a stack
directory skips it with a warning — that is how a project omits a whole stack. Before
`remote-state` has applied, every GCS-backed stack fails `init` with "bucket doesn't
exist": that is the expected resting state of an un-bootstrapped project, not a defect.

## Actors

| Actor | Scope | Runs |
| --- | --- | --- |
| a human | once per platform / project | control plane; each project's `remote-state` |
| repository admin | GitHub repo | repository stacks (`TF_VAR_github_token="$(gh auth token)"`) |
| `bootstrap-admin@<platform>-admin-100` | the platform's folder | `services → identities → github`, once per project |
| `github-actions@<project>` | its own project: `editor` + the admin roles that set access, never `owner` | every stack from `seed` on, then all stacks forever |
| repo-reacher | GitHub only | module clones; `PROJECT_NUMBER` on the backend repo's environment |

No other service account runs pipeline steps. A permission a stack lacks is added
upstream to `github-gcp-project`'s `project_roles`, not granted by hand.

## CI (reference implementation: cultureindex-infrastructure)

| Workflow | Trigger | Does |
| --- | --- | --- |
| `tf-converge.yml` | reusable + dispatch | one project: `--check`, then stacks; modes `bootstrap` / `plan` / `apply` / `drift`; fails first step if `bootstrap` or prod is not on a production ref |
| `tf-plan.yml` | PR touching `tf/**` | plan affected non-prod projects (a change outside `tf/_impl/gcp-projects/` plans all), comment on PR |
| `tf-apply.yml` | push to `main` / `production(-.+)?` | `main`: non-prod in order (ci → qa). Production branch: prod only |
| `tf-drift.yml` | nightly + dispatch | drift-plan; open/update an issue |

Auth: `google-github-actions/auth` with `workload_identity_provider: vars.GCP_WIF_PROVIDER`
and the bootstrap SA or `github-actions@<project>`. Tool: `opentofu/setup-opentofu`
with `tofu_wrapper: false` and a `TOFU_VERSION` equal to what writes state. Consult the
`github-action` skill's pinning table for every `uses:` ref.
