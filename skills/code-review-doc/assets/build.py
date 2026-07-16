#!/usr/bin/env python3
"""Build an interactive ReviewQueue code-review console from a review.json.

Usage:
    python3 build.py review.json [--repo DIR] [--out DIR]

Reads the authored review.json (see reference/schema.md), pulls each file's
diff from git (unless an explicit `diffText` is provided), renders everything
into the fixed console template, and writes two files next to --out:

    <slug>.html            standalone page (open in a browser, or upload to Rooms)
    <slug>.artifact.html   body-only fragment for the Artifact tool (no <html>/<head>/<body>)

The template + renderer are fixed (assets/template.html); this script only
injects data. All diff HTML is escaped here, so review.json never contains raw
HTML in the diff.
"""
import json, re, subprocess, sys, os, argparse, html as _html

HERE = os.path.dirname(os.path.abspath(__file__))
TEMPLATE = os.path.join(HERE, "template.html")

RISKS = {"high", "med", "low"}
CATS = {"logic", "wiring", "test", "chore"}
CAT_DEFAULT_LABEL = {"logic": "Logic", "wiring": "Wiring", "test": "Test", "chore": "Chore"}


def esc(s):
    return _html.escape(str(s), quote=False)


def inline_md(s):
    """Tiny inline markdown -> HTML for authored prose: `code`, **bold**, links.
    Everything is escaped first, so authors write plain text."""
    s = esc(s)
    s = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", s)
    s = re.sub(r"`([^`]+?)`", r"<code>\1</code>", s)
    s = re.sub(r"\[([^\]]+?)\]\((https?://[^)]+?)\)", r'<a href="\2">\1</a>', s)
    return s


def slugify(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-") or "review"


# ---- git helpers -----------------------------------------------------------

def git(repo, *args):
    return subprocess.run(["git", "-C", repo, *args],
                          capture_output=True, text=True).stdout


def file_diff(repo, rng, path):
    """Unified diff for one path. Falls back to --no-index for untracked files."""
    args = ["diff"]
    if rng:
        args += rng.split()
    args += ["--", path]
    out = git(repo, *args)
    if out.strip():
        return out
    # untracked / new file not yet added
    out = subprocess.run(["git", "-C", repo, "diff", "--no-index", "--", os.devnull, path],
                         capture_output=True, text=True).stdout
    return out


# ---- diff -> HTML table ----------------------------------------------------

HUNK_RE = re.compile(r"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@")


def diff_to_table(diff_text, max_lines=400):
    """Render a unified diff as the console's <table class="diff"> HTML.
    Returns (html, added, removed)."""
    rows = []
    added = removed = 0
    oldn = newn = 0
    emitted = 0
    truncated = False
    for line in diff_text.splitlines():
        if emitted >= max_lines:
            truncated = True
            break
        if line.startswith("diff --git") or line.startswith("index ") \
                or line.startswith("--- ") or line.startswith("+++ ") \
                or line.startswith("new file") or line.startswith("deleted file") \
                or line.startswith("similarity ") or line.startswith("rename ") \
                or line.startswith("old mode") or line.startswith("new mode") \
                or line.startswith("\\ No newline"):
            rows.append(f'<tr class="dl meta"><td class="ln"></td><td class="ln"></td>'
                        f'<td class="code">{esc(line)}</td></tr>')
            continue
        m = HUNK_RE.match(line)
        if m:
            oldn, newn = int(m.group(1)), int(m.group(2))
            rows.append(f'<tr class="dl hunk"><td class="ln"></td><td class="ln"></td>'
                        f'<td class="code">{esc(line)}</td></tr>')
            emitted += 1
            continue
        sign = line[:1]
        body = esc(line[1:])
        if sign == "+":
            rows.append(f'<tr class="dl add"><td class="ln"></td><td class="ln">{newn}</td>'
                        f'<td class="code"><span class="sg">+</span>{body}</td></tr>')
            newn += 1; added += 1
        elif sign == "-":
            rows.append(f'<tr class="dl del"><td class="ln">{oldn}</td><td class="ln"></td>'
                        f'<td class="code"><span class="sg">−</span>{body}</td></tr>')
            oldn += 1; removed += 1
        else:  # context
            rows.append(f'<tr class="dl ctx"><td class="ln">{oldn}</td><td class="ln">{newn}</td>'
                        f'<td class="code"><span class="sg"> </span>{body}</td></tr>')
            oldn += 1; newn += 1
        emitted += 1
    if truncated:
        rows.append('<tr class="dl meta"><td class="ln"></td><td class="ln"></td>'
                    '<td class="code">… diff truncated — open the file to see the rest …</td></tr>')
    return '<table class="diff">' + "".join(rows) + "</table>", added, removed


# ---- why / points prose ----------------------------------------------------

def build_why(text):
    return '<div class="why-label">Why it matters</div><p>' + inline_md(text) + "</p>"


def build_points(points):
    if not points:
        return ""
    lis = "".join(f"<li>{inline_md(p)}</li>" for p in points)
    return '<div class="points-label">⚠ Review these</div><ul>' + lis + "</ul>"


# ---- main ------------------------------------------------------------------

def build_file(repo, rng, f):
    path = f["path"]
    risk = f.get("risk", "low")
    cat = f.get("cat", "logic")
    if risk not in RISKS:
        raise SystemExit(f"file {path}: bad risk {risk!r} (want {RISKS})")
    if cat not in CATS:
        raise SystemExit(f"file {path}: bad cat {cat!r} (want {CATS})")
    diff_text = f.get("diffText")
    if diff_text is None:
        diff_text = file_diff(repo, rng, path)
    table, added, removed = diff_to_table(diff_text)
    return {
        "id": slugify(path),
        "risk": risk,
        "cat": cat,
        "catLabel": f.get("catLabel", CAT_DEFAULT_LABEL[cat]),
        "isNew": bool(f.get("isNew", False)),
        "title": f.get("title", os.path.basename(path)),
        "pkg": f.get("pkg", ""),
        "path": path,
        "add": f.get("add", added),
        "del": f.get("del", removed),
        "why": build_why(f.get("why", "")),
        "points": build_points(f.get("points", [])),
        "diff": table,
        "feature": f.get("feature", ""),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("review", help="path to review.json")
    ap.add_argument("--repo", default=".", help="git repo root (default: cwd)")
    ap.add_argument("--out", default=".", help="output directory")
    args = ap.parse_args()

    with open(args.review) as fh:
        spec = json.load(fh)

    repo = os.path.abspath(args.repo)
    rng = spec.get("range", "HEAD")
    title = spec.get("title", "Change Review")
    slug = spec.get("slug") or slugify(title)
    branch = spec.get("branch") or git(repo, "rev-parse", "--abbrev-ref", "HEAD").strip() or "working tree"

    files = [build_file(repo, rng, f) for f in spec["files"]]

    review_data = {
        "heroTitle": title,
        "heroDesc": spec.get("heroDesc", ""),
        "cap": spec.get("cap", ""),        # raw HTML block or "" (see schema.md)
        "callout": spec.get("callout", ""),  # raw HTML block or ""
        "files": files,
    }

    # feature slices (optional). map is derived from each file's `feature`.
    feats = spec.get("features", {}) or {}
    fmap = {f["id"]: f["feature"] for f in files if f.get("feature")}
    review_features = {
        "order": feats.get("order", []),
        "meta": feats.get("meta", {}),
        "map": fmap,
    }

    tmpl = open(TEMPLATE).read()
    store_key = "cvproto:" + slug + ":v1"
    filled = (tmpl
              .replace("__CVR_TITLE__", esc(title))
              .replace("__CVR_BRANCH__", esc(branch))
              .replace("__CVR_STORE_KEY__", store_key)
              .replace("__CVR_REVIEW_DATA__", json.dumps(review_data))
              .replace("__CVR_REVIEW_FEATURES__", json.dumps(review_features)))

    os.makedirs(args.out, exist_ok=True)
    standalone = os.path.join(args.out, f"{slug}.html")
    with open(standalone, "w") as fh:
        fh.write(filled)

    # Artifact-ready fragment: strip the doctype/html/head wrapper, keep <style>
    # + body content + scripts (the Artifact tool re-wraps head/body itself).
    style = re.search(r"<style>.*?</style>", filled, re.S).group(0)
    body = re.search(r"<body>(.*)</body>", filled, re.S).group(1)
    fragment = style + "\n" + body
    artifact = os.path.join(args.out, f"{slug}.artifact.html")
    with open(artifact, "w") as fh:
        fh.write(fragment)

    print(json.dumps({
        "slug": slug,
        "files": len(files),
        "high": sum(1 for f in files if f["risk"] == "high"),
        "standalone": standalone,
        "artifact": artifact,
    }, indent=2))


if __name__ == "__main__":
    main()
