# review.json schema

You author this file. `build.py` pulls diffs from git and renders the console.
Your job is the *judgment* — risk, category, what the reviewer should look at —
not the mechanics.

## Top level

| key        | required | meaning |
|------------|----------|---------|
| `title`    | yes | Review title. Shown in the tab + hero. |
| `slug`     | no  | Output filename + localStorage namespace. Defaults to a slug of `title`. **Keep it stable across re-runs of the same review** so the reviewer's decisions/comments persist. |
| `branch`   | no  | Branch label in the sidebar. Defaults to the repo's current branch. |
| `range`    | no  | git diff range applied to every file. Default `"HEAD"` (all uncommitted work). Use `"main...HEAD"` for a branch/PR review, `"--staged"` for staged only, `""` for unstaged working tree. |
| `heroDesc` | no  | One-paragraph intro: how to read this review. Plain text (inline `code`/`**bold**`/links ok). |
| `cap`      | no  | "The new capability, in brief" block. **Raw HTML** — see below. |
| `callout`  | no  | "Where to spend your attention" block. **Raw HTML** — see below. |
| `features` | no  | Feature-slice grouping. `{ "order": [keys], "meta": { key: {name, desc} } }`. Each file's `feature` key ties it to a slice. |
| `files`    | yes | Array of file cards, ordered most-important first *within* each risk group (the console groups by risk by default). |

### `cap` / `callout` raw HTML

These two render as `innerHTML`, matching the Rooms docs. Format:

```html
<div class="cap-label">The new capability, in brief</div>
<p>What this change set does, in 2–4 sentences. Use <code>code</code> and <b>bold</b>.</p>
```

```html
<b>Where to spend your attention.</b> The one or two invariants that carry
this change. Point at the high-risk cards. <br><br>
<b>Not shown here:</b> generated files, lockfiles, barrels you deliberately omitted.
```

Omit either by leaving it `""`.

## Each file object

| key        | required | meaning |
|------------|----------|---------|
| `path`     | yes | Repo-relative path. Used for the diff, the anchor id, and the "Type" grouping. |
| `risk`     | yes | `high` \| `med` \| `low`. Drives ordering, color, and the ⚠ High filter. |
| `cat`      | yes | `logic` \| `wiring` \| `test` \| `chore`. Drives the category dot + filters. |
| `catLabel` | no  | Display label. Defaults to the capitalized `cat`. Use for nuance: `"Logic · architecture"`, `"Chore · gotcha"`, `"Logic · API"`. |
| `title`    | yes | Short, human title for the card — *what the change does*, not the filename. e.g. "Create honors an explicit id (the 409 root cause)". |
| `pkg`      | no  | Package/service chip shown before the path. e.g. `"platform-frontend-api"`. |
| `isNew`    | no  | `true` for a brand-new file (adds a green "New" badge). |
| `why`      | yes | "Why it matters" — 1–3 sentences on *why this file is load-bearing* and what breaks if it's wrong. Plain text, inline markdown ok. |
| `points`   | no  | Array of "⚠ Review these" bullets — the specific things you want the reviewer to check/confirm/push back on. This is the highest-value field. Plain text, inline markdown ok. |
| `feature`  | no  | Feature-slice key (must exist in `features.meta`). |
| `diffText` | no  | Override: verbatim unified-diff text for this file. Use to show a **curated** diff (only the load-bearing hunks) instead of the full git diff — great for large files. If omitted, `build.py` runs `git diff <range> -- <path>`. |
| `add`/`del`| no  | Override the +/- counts (auto-computed from the diff otherwise). |

## Risk & category taxonomy

- **high** — logic/behavior/API/security a wrong review would ship a bug in. The
  files to argue about. Aim for a handful, not everything.
- **med** — wiring or config that touches many consumers, or a gotcha worth a look.
- **low** — faithful ports, mechanical changes, low-blast-radius wiring.
- **logic** — behavior, algorithms, domain rules, API shape.
- **wiring** — DI/composition, providers, config, exports.
- **test** — tests, demos, sandbox/proving harnesses.
- **chore** — deps, lockfiles, renames, formatting, generated files.

## Authoring guidance (this is the value-add)

- **Order and prune.** Lead with the high-risk cards. Summarize barrels,
  generated files, and lockfiles in the `callout`'s "Not shown here" — don't
  itemize them. The goal is *anti-overwhelm*.
- **`why` answers "why should I care about this file at all?"** — not what it does.
- **`points` are questions and confirmations**, phrased so the reviewer can act:
  "Confirm X fails loudly, not silently"; "Is exposing Y acceptable?"; "Check the
  mapping A→B". Call out deliberate-looking-odd choices so they aren't mistaken
  for bugs.
- **Curate huge diffs** with `diffText` — show the seam, not 400 lines of noise.
- Match the tone of the published Rooms reviews (`code-reviews` room): precise,
  points at invariants, honest about follow-ups and what's unverified.
