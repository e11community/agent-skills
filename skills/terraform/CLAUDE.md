# CLAUDE.md

Read AGENTS.md in this directory for full project context, conventions, and commands.
Read `terraform-repo-layout.md` in this directory for the full repo layout reference —
it is the canonical source for file structure, module examples, env wiring, CI/CD, and
provider configuration. Read it before writing or modifying any Terraform.

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

## New Module Workflow

When creating a new child module, follow this sequence exactly:

1. **Read context first.** Read `terraform-repo-layout.md`, then read an existing
   module that is similar to what you're building (check its main.tf, variables.tf,
   outputs.tf, versions.tf). Read `environments/dev/main.tf` to see how modules are
   wired, and `environments/dev/providers.tf` to see what the provider config supplies.

2. **Verify resource arguments against the Terraform Registry.** Do not assume a
   resource inherits `project`, `region`, or other arguments from the provider — check
   the docs. If a required argument isn't supplied by the provider, accept it as a
   variable in the module.

3. **Scaffold the module files** in `modules/<name>/`: main.tf, variables.tf,
   outputs.tf, versions.tf.

4. **Wire the module into `environments/dev/main.tf`** before validating. Add a
   `module "<name>"` block with source and all required variables.

5. **Validate from the env root, not the module directory.** Modules have no backend
   and no provider config — `terraform validate` in a module dir will either fail or
   give misleading errors. Always:
   ```bash
   cd hcl/environments/dev
   terraform init -upgrade
   terraform validate
   ```
