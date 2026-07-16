---
name: code-review-doc
description: Generate an interactive local code-review console (the Engineering11 "Code Review Prototype" / ReviewQueue format) so the user can double-check a change set without getting overwhelmed — one file card in focus at a time, approve/request-changes/skip with keyboard shortcuts, progress, per-file comments, and a Copy-as-Markdown summary. Use when the user wants to review changes you (or they) made, "make a code review", "review this diff", "let me check your code", or stay in the loop on a change set. Renders locally as an Artifact by default; only upload to the Engineering11 Rooms "Code Reviews" room when explicitly asked.
---

# Code Review Console (ReviewQueue)

Produce the interactive triage console the user reviews changes in. It is the
locally-runnable twin of the Engineering11 Rooms **Code Reviews** docs: a
`window.REVIEW_DATA` blob rendered by a fixed engine into a review *queue* —
sidebar with progress + filters + risk/service/type/feature grouping, one file
card in focus at a time, `a`/`r`/`s` to approve / request-changes / skip,
`j`/`k` to move, `c` to comment, `e` to expand the diff, and a summary drawer
with **Copy as Markdown**. Decisions persist in the browser via localStorage.

**Your job is the judgment, not the plumbing.** The template + renderer are
fixed. You decide, per file: risk, category, a "why it matters", and the "⚠
Review these" points. That triage is the whole value — it's what lets the user
check the load-bearing changes without drowning in the diff.

## Workflow

1. **Scope the change set.** Pick the git range:
   - working tree / uncommitted work → `range: "HEAD"` (default)
   - a branch or PR → `range: "main...HEAD"` (or the base branch)
   - staged only → `range: "--staged"`
   Get the file list: `git diff --stat <range>`.

2. **Read the diff and form judgment.** Actually read the changes. For each file
   that carries meaning, decide `risk` (high/med/low) and `cat`
   (logic/wiring/test/chore), and write:
   - `title` — what the change *does* (not the filename)
   - `why` — why this file is load-bearing / what breaks if it's wrong
   - `points` — the specific things the reviewer should check, confirm, or push
     back on. Phrase as questions/confirmations. This is the highest-value field.
   Lead with high-risk files. **Prune aggressively** — summarize barrels,
   lockfiles, and generated files in the `callout`'s "Not shown here" instead of
   giving each a card. Anti-overwhelm is the point. Full authoring guidance and
   the field-by-field schema: **`reference/schema.md`**. Worked example:
   **`reference/example-review.json`**.

3. **Write `review.json`** to the scratchpad directory (not the repo, unless the
   user wants it kept). Curate huge diffs with a per-file `diffText` (show the
   seam, not 400 lines); otherwise `build.py` pulls the diff from git.

4. **Build:**
   ```sh
   python3 ~/.claude/skills/code-review-doc/assets/build.py <review.json> \
       --repo <repo-root> --out <scratchpad>/review-out
   ```
   It writes `<slug>.html` (standalone) and `<slug>.artifact.html` (body-only
   fragment for the Artifact tool). It prints the paths + file/high-risk counts.

5. **Present it (default = local Artifact).** Call the **Artifact** tool on the
   `<slug>.artifact.html` fragment. The design is fixed by this template — it is
   the pre-calibrated E11 review standard — so do **not** run artifact-design or
   restyle it; publish the fragment as-is. Use a **stable `file_path`** (reuse it
   on re-runs of the same review so the artifact updates in place). Suggested
   `favicon: "🔍"`, title = the review title. Then tell the user the loop:
   > Review each card, decide with `a`/`r`/`s` (`?` for all shortcuts). When
   > done, open **📋 Review summary → Copy as Markdown** and paste it back here —
   > I'll address the flagged items.

   The console follows the viewer's light/dark theme automatically; there's also
   a 🌓 toggle in the top bar (`t`) that overrides it and persists across reviews.

   Also mention the standalone `<slug>.html` path — they can `open` it directly
   in a browser (works offline; "Submit review" is a local no-op, the Markdown
   copy is the handoff).

6. **The review loop.** When the user pastes back the Markdown summary, work the
   ⚑ flagged items and comments. Regenerate/redeploy the same artifact if the
   change set moved.

## Uploading to Rooms — only when asked

Do **not** upload automatically. When the user explicitly asks to publish/share
it in Rooms:

- Room: company `engineering11`, collection `code-reviews` (standard + direct →
  goes live immediately, no publish step).
- Use the **standalone `<slug>.html`** (full self-contained doc), and pass
  `raw: true` — a code-review viewer is a self-contained doc and the existing
  docs in that room are stored raw (verbatim, no brand theme, no banner). Don't
  silently brand it.
  ```
  createDoc(company:"engineering11", collection:"code-reviews",
            doc:"<slug>", title:"<review title>", html:<standalone html>, raw:true)
  ```
- If `createDoc` returns `{needsConfirmation:true, duplicatesFound:[...]}`, show
  the user the matches; only re-call with `confirmNew:true` if it's genuinely new.
- To revise an existing review doc later, use `updateDoc` (stays raw on edit).

## Notes

- The console is fully self-contained (inline CSS/JS, no network) — safe under
  the Artifact CSP and openable offline.
- `slug` is the localStorage namespace. Keep it stable across re-runs of the
  same review so the user's decisions/comments survive a rebuild; use a new slug
  for a genuinely different review.
- `build.py` needs only `git` + Python 3 (stdlib). No install.
