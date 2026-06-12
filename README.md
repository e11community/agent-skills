# Agent Agnostic Skills

Reusable, agent-agnostic [skills](https://github.com/vercel-labs/skills) for
coding agents (Claude Code, and others). Each skill is a directory under
[`skills/`](skills/) containing a `SKILL.md`.

## Available skills

| Skill                                    | What it's for                                                                       |
| ---------------------------------------- | ----------------------------------------------------------------------------------- |
| [`github-action`](skills/github-action/) | Authoring, modernizing, or reviewing a TypeScript GitHub Action (esbuild + node24). |
| [`terraform`](skills/terraform/)         | Authoring, reviewing, or modifying Terraform for the multi-environment GCP repo.     |

## Managing skills

Install and keep these skills current with the
[`vercel-labs/skills`](https://github.com/vercel-labs/skills) CLI:

- **[docs/installing-skills.md](docs/installing-skills.md)** — install skills
  into Claude Code (project or global scope), pick specific skills, and verify.
- **[docs/upgrading-skills.md](docs/upgrading-skills.md)** — update, re-pin, and
  remove installed skills.

Quick start (install everything here into the current project for Claude Code):

```bash
npx skills add e11community/agent-skills -a claude-code
```
