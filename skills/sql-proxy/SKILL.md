---
name: sql-proxy
description: Connect a local psql/GUI/app on localhost to a private-IP-only Cloud SQL for PostgreSQL instance through an IAP bastion, using a per-developer Cloud SQL Auth Proxy (IAM auth, auto-refreshing token). Use for "/sql-proxy", "tunnel to the private database", "connect to Cloud SQL locally". Handles bastion discovery, the one-time browser login (and re-login when ADC expires/revokes), the SSH tunnel, health checks, and repairs.
---

# sql-proxy — laptop → private Cloud SQL over an IAP bastion

Puts a local `localhost:<port>` in front of a **private-IP-only** Cloud SQL for PostgreSQL instance:
laptop → **IAP SSH tunnel** → **bastion** → a **per-developer Cloud SQL Auth Proxy** that does IAM auth
with an **auto-refreshing** token. Background lives in the engineering11 repo:
[Postgres-at-GCP findings](https://github.com/engineering11/engineering11/blob/main/architecture/postgres-gcp/README.md)
and the [developer guide](https://github.com/engineering11/engineering11/blob/main/architecture/postgres-gcp/DEVELOPERS.md).

**Prerequisite:** an IAP bastion VM — provision one with [BASTION.md](./BASTION.md).

## Invariants (never trade these away)

- **One proxy per developer**, never a single shared proxy — each dev's own identity + own auto-refresh
  token, so Postgres logs attribute every statement to the individual (full per-user audit).
- **No developer is assigned a reference/ID** (no handed-out ports). The rendezvous is the dev's own
  `$HOME` socket on the bastion, namespaced by their OS Login identity — collision-free across
  concurrent devs, nothing assigned.
- **Auto-refresh** comes from the Auth Proxy; **private-IP reach** comes from the IAP SSH tunnel.

## Inputs

- **`/sql-proxy` with no args = redial**: reuse the last `iam_user` + `instance` from state (below) and
  reconnect — the common case, no questions asked.
- **First run / no state**: collect the target via the one-at-a-time bootstrap below.
- **Overrides (any run)**: `--iam-user`, `--instance` (full `project:region:instance`) or the pieces
  `--project` / `--region` / `--instance-name`; plus `--bastion NAME`, `--zone ZONE`,
  `--bastion-project PROJECT_ID`, `--local-port PORT`. A provided value skips its question.
- **Teardown modes**: `/sql-proxy --stop` (local tunnel cleanup only) and `/sql-proxy --revoke`
  (revoke your bastion creds + stop). See Teardown.

`iam_user` is auto-detected from `gcloud config get-value account` (the dev's own identity); only ask
if that's empty. Remember it.

## Bootstrap (no remembered state) — ask one question at a time

Ask each on its own turn; accept empty as the default where noted:

1. **Project ID?** (required — no default)
2. **Region?** — tell them it defaults to **`us-central1`** on empty.
3. **Cloud SQL instance name?** — tell them it defaults to **`db-main-${ENV}`**, where `ENV` is derived
   from the project ID: split on `-`; **exactly 2 parts → `ENV` = last part**; **3+ parts → `ENV` =
   second-to-last part** (e.g. `cindex-dev` → `dev`; `cindex-dev-100` → `dev`). If `ENV` can't be
   determined (e.g. no hyphen in the project ID), **don't guess — ask for the instance name (or `ENV`)
   explicitly.**

Then build `${PROJECT}:${REGION}:${INSTANCE_NAME}`, auto-detect `iam_user`, save state, and proceed.
(The Postgres *database* isn't collected — the tunnel is database-agnostic; the dev picks their database
in their client. Health checks use `dbname=postgres`.)

## State

`~/.config/sql-proxy/state.json`: `{ iam_user, instance, bastion, zone, bastion_project, local_port }`.
Read at start, merge with args (args win), write back after a successful start. Confirm before
overwriting a remembered value with a different one.

## Defaults & discovery

- Parse `project:region:instance` from `--instance`. `bastion_project` defaults to that project.
- **Zone** defaults to `${REGION}-a` — tell the user they can pin it with `--zone`.
- **Bastion**: if `--bastion` not given, discover it —
  `gcloud compute instances list --project <bastion_project> --filter="labels.bastion=sql AND zone:( ${REGION}-a )" --format="value(name,zone)"`, take the first. If none in `${REGION}-a`, list the region's zones (`gcloud compute zones list --filter="region:( <region> )"`) and query each until a labeled VM appears. If still none, stop and ask the user to re-run with `--bastion NAME --zone ZONE --bastion-project PROJECT_ID`.
- **Local port** defaults to `5432`; say it's overridable with `--local-port`. On a bind conflict, run `lsof -Pni :<port>` to show what holds it, then have the user re-run with `--local-port PORT`.

## Procedure

1. Resolve config (state + args + discovery).
2. **Probe ADC + start the proxy** on the bastion:
   `gcloud compute ssh <bastion> --zone <zone> --project <bastion_project> --tunnel-through-iap -- bash -s <instance> < scripts/bastion-proxy.sh`.
   If it prints `ADC_INVALID` (exit 10), run **Login** below, then re-run this step. On success it prints
   `SOCKET=/home/<user>/db.sock` — capture that path.
3. **Start the tunnel in the background** (auto-reconnecting) with `run_in_background`:
   `BASTION=<b> ZONE=<z> PROJECT_ID=<p> LOCAL_PORT=<port> REMOTE_SOCK=<socket> scripts/tunnel.sh`.
4. **Verify**: `psql "host=127.0.0.1 port=<port> user=<iam_user> dbname=postgres" -c 'select current_user, now()'`
   (or a plain TCP check if psql is absent). Report `localhost:<port>` ready — connect as `<iam_user>`,
   no password, no SSL.
5. Save state.

## Login (one-time — and repair on expiry/revoke)

The bastion is headless and the OOB copy/paste-code flow is deprecated, so use the `--no-browser`
remote-bootstrap handshake via `scripts/login-helper.sh`. **Run it with `run_in_background`** so you can
act between its prompts:

1. `BASTION=<b> ZONE=<z> PROJECT_ID=<p> scripts/login-helper.sh` → it starts
   `gcloud auth application-default login --no-browser` on the bastion and prints `BOOTSTRAP_CMD=<…>`
   and `RESP_FILE=<path>`.
2. Run `BOOTSTRAP_CMD` **locally** (you run it): the local gcloud auto-launches the browser — guide the
   user through Google login/MFA/consent. The command then prints a verification code.
3. Write that code to `RESP_FILE`. The helper relays it to the bastion and prints `ADC_LOGIN_DONE`.

**Existing ADC** is handled by only entering this flow when the probe says `ADC_INVALID`. **Repair on
expiry/revoke:** if the proxy later can't refresh (revoked token or a reauth policy fired), the health
check surfaces `ADC_INVALID` again → re-run this Login flow (browser again), then restart the proxy.

## Health & repair

On request or periodically:
- Local tunnel alive (it self-reconnects via `tunnel.sh`'s loop).
- Remote proxy alive: `gcloud compute ssh … -- 'pgrep -f cloud-sql-proxy'`.
- ADC valid: re-run the `bastion-proxy.sh` probe; `ADC_INVALID` → re-Login (browser).
- End-to-end: `psql … -c 'select 1'`.

Repair the specific broken layer (relaunch proxy / re-login / restart tunnel). **Confirm before killing
anything** the user might be actively using.

## Diagnostics

Answer "is it up / who am I / what's wrong" with: tunnel status+PID, remote proxy PID, ADC validity,
the socket path, and the last `select current_user`. On a port conflict, show `lsof -Pni :<port>`.

## Teardown

### `/sql-proxy --stop` (local only)

Stop and clean up the local → bastion tunnel(s) this skill started — and nothing else (the bastion
proxy and your creds are left intact). Run `scripts/stop-local.sh`: it kills each PID in
`~/.config/sql-proxy/tunnel.pid`, then a `pkill` signature fallback catches orphans from older
sessions. Also stop any tunnel task still tracked in this session.

### `/sql-proxy --revoke` (bastion + local)

Best-effort **full** teardown — try hard, but **warn and continue on any failure, including if the
bastion is unreachable**:

1. SSH to the bastion and run the revoke script:
   `gcloud compute ssh <bastion> --zone <zone> --project <bastion_project> --tunnel-through-iap -- bash -s < scripts/bastion-revoke.sh`.
   It stops **only this user's** proxy (`pkill -u $(id -un) -f cloud-sql-proxy`), revokes ADC
   (`gcloud auth application-default revoke`) and the gcloud account creds (`gcloud auth revoke --all`),
   and removes `~/csql` + `~/db.sock`. Each step is independent — warn on any that fail. If the SSH
   itself fails (bastion down, no access), warn and continue to step 2.
2. Then do the local `--stop` cleanup (`scripts/stop-local.sh`).

Multi-user-safe: the bastion step only ever touches the calling user's own processes/creds, so it's
safe on a shared bastion.

### On session end (nicety — not guaranteed)

Background tasks started via `run_in_background` are normally terminated by the harness when the
session ends. For extra orphan cleanup you *may* wire a Claude Code **SessionEnd** hook (in
`settings.json`) that runs `scripts/stop-local.sh`. This is optional and depends on harness support —
treat it as best-effort, never relied upon.

## Caveats

- The one-time login leaves the dev's refresh token on the bastion (`~/.config/gcloud`) — credential at
  rest on a shared host; clear it with `/sql-proxy --revoke` when done / at offboarding.
- Never assign or hardcode per-dev ports/IDs; keep the rendezvous `$HOME`-namespaced.
