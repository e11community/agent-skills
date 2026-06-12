# Installing skills

This repo is a collection of **agent-agnostic skills**. The easiest way to pull
them into an agent is the [`vercel-labs/skills`](https://github.com/vercel-labs/skills)
CLI, run via `npx` (no global install required). The examples below use
**Claude / Claude Code** as the agent.

## Prerequisites

- Node.js (so `npx` is available). Nothing else — `npx skills …` fetches the CLI
  on demand.

## Quick start

Install all skills from this repo into the **current project**, targeting Claude
Code:

```bash
npx skills add e11community/agent-skills -a claude-code
```

- `-a, --agent <agents…>` — target agent(s). For Claude Code the agent id is
  `claude-code`.
- Omit `-a` and the CLI will prompt for which detected agents to install into.
- Add `-y` to skip confirmation prompts (useful in scripts/CI).

## See what a repo offers before installing

```bash
npx skills add e11community/agent-skills -l        # list available skills, install nothing
npx skills find terraform                          # search the wider ecosystem
```

## Install specific skills

```bash
# one skill
npx skills add e11community/agent-skills --skill github-action -a claude-code

# several
npx skills add e11community/agent-skills --skill github-action --skill terraform -a claude-code

# everything in the repo
npx skills add e11community/agent-skills --all -a claude-code
```

## Project vs. global scope

| Scope       | Flag           | Claude Code install path | Use when                                    |
| ----------- | -------------- | ------------------------ | ------------------------------------------- |
| **Project** | _(default)_    | `./.claude/skills/`      | Skill should travel with the repo / team    |
| **Global**  | `-g, --global` | `~/.claude/skills/`      | You want it available across all your repos |

```bash
# project (committed alongside the repo that needs it)
npx skills add e11community/agent-skills --skill github-action -a claude-code

# global (your machine, every project)
npx skills add e11community/agent-skills --skill github-action -a claude-code -g
```

For Claude Code, an installed skill is a directory containing a `SKILL.md` under
`.claude/skills/<skill-name>/`. Project-scoped skills are normal files — commit
them so teammates get the same skill set.

## Verify the install

```bash
npx skills list                 # everything installed in this project
npx skills ls -a claude-code    # filter to Claude Code
npx skills ls -g                # global installs
```

## Try a skill without installing

Pipe a skill's content straight into Claude for a one-off, leaving nothing on
disk:

```bash
npx skills use e11community/agent-skills --skill github-action --agent claude-code | claude
```

## Source formats

`add` accepts any of these for the source argument:

```bash
npx skills add e11community/agent-skills                       # GitHub shorthand
npx skills add https://github.com/e11community/agent-skills    # full URL
npx skills add git@github.com:e11community/agent-skills.git    # git URL (SSH)
npx skills add ./path/to/local/skills                         # local path
```

> For SSH/private sources, the CLI uses your existing git credentials — the same
> ones `git clone` would use.

## Next

- [Upgrading skills](upgrading-skills.md) — keep installed skills current and
  remove ones you no longer need.
