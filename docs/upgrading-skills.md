# Upgrading skills

Skills evolve — this repo's `github-action`, `terraform`, and other skills get
new conventions and templates over time. Use the
[`vercel-labs/skills`](https://github.com/vercel-labs/skills) CLI to pull the
latest. Examples use **Claude / Claude Code** as the agent.

## Update everything

```bash
npx skills update            # update all installed skills in this project
npx skills update -y         # ...without confirmation prompts
```

`update` re-fetches each installed skill from the source it was installed from
and overwrites the local copy with the latest version.

## Update a specific skill

```bash
npx skills update github-action
```

## Project vs. global

Updates apply to the scope you target — mirror the scope you installed into:

```bash
npx skills update            # project scope (./.claude/skills/)
npx skills update -g         # global scope (~/.claude/skills/)
```

## Check what's installed first

```bash
npx skills list                 # all installed skills (this project)
npx skills ls -a claude-code    # filter to Claude Code
npx skills ls -g                # global installs
```

## Re-pin / re-point a skill

To move a skill to a different source or re-add it cleanly, re-run `add` — it
overwrites the existing install:

```bash
npx skills add e11community/agent-skills --skill github-action -a claude-code -y
```

## Remove a skill

```bash
npx skills remove github-action        # interactive
npx skills rm github-action -y         # skip prompts
npx skills remove github-action -g     # from global scope
npx skills remove github-action -a claude-code   # from a specific agent only
```

## Recommended workflow for project-scoped skills

Because project-scoped skills live in `./.claude/skills/` and are committed:

1. `npx skills update -y` (or update a specific skill).
2. Review the diff — `git diff .claude/skills/` — so you see exactly what
   changed before adopting it.
3. Commit the update so teammates pick up the same version.

This keeps skill upgrades reviewable and reproducible across the team, the same
way you'd treat a dependency bump.

## See also

- [Installing skills](installing-skills.md)
