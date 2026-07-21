#!/usr/bin/env bash
#
# Runs ON the bastion (piped in via `gcloud compute ssh … -- bash -s <instance> < bastion-proxy.sh`).
# Idempotent: verifies the dev's own ADC, then starts a per-user Cloud SQL Auth Proxy on a socket under
# $HOME (no port, no assigned id) and symlinks it to a colon-free path for `ssh -L`.
#
# Exit 10 + "ADC_INVALID": no usable *developer* ADC — missing, revoked, a reauth policy fired, or the
# ADC resolved to the GCE metadata service account instead of a person (which would break per-user
# audit). The caller must run the interactive login, then re-run this. This drives repair-on-expiry too.
set -euo pipefail

INSTANCE_CONNECTION_NAME="${1:?instance connection name required (project:region:instance)}"
SOCK_DIR="$HOME/csql"
LINK="$HOME/db.sock"

# The per-developer audit invariant (see SKILL.md) requires the ADC to be the *developer's own*
# identity. A bare `print-access-token` check is NOT enough: on a GCE VM, gcloud silently falls back
# to the attached compute service account via the metadata server whenever no user ADC file exists —
# so the probe passes for a brand-new user who never logged in, the browser gate never fires, and the
# proxy would run under the shared SA (defeating per-user audit; the SA token also lacks
# sqlservice.login, so --auto-iam-authn can't even authenticate with it). Require the ADC to resolve
# to a real user email (tokeninfo carries `email` for user creds; the metadata-SA token does not).
# Missing/revoked ADC, or an SA identity, all yield ADC_INVALID -> caller runs the interactive login.
ADC_TOKEN="$(gcloud auth application-default print-access-token 2>/dev/null || true)"
ADC_EMAIL=""
if [ -n "$ADC_TOKEN" ]; then
  ADC_EMAIL="$(curl -s "https://oauth2.googleapis.com/tokeninfo?access_token=${ADC_TOKEN}" \
    | sed -n 's/.*"email"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1 || true)"
fi
case "$ADC_EMAIL" in
  "" | *.gserviceaccount.com)
    echo "ADC_INVALID"
    exit 10
    ;;
esac

mkdir -p "$SOCK_DIR"

if pgrep -f "cloud-sql-proxy.*${INSTANCE_CONNECTION_NAME}" >/dev/null 2>&1; then
  echo "PROXY_ALREADY_RUNNING"
else
  # nohup + detached stdio so the SSH command can return while the proxy keeps running
  nohup cloud-sql-proxy --private-ip --auto-iam-authn --unix-socket "$SOCK_DIR" \
    "$INSTANCE_CONNECTION_NAME" </dev/null >"$HOME/.cloud-sql-proxy.log" 2>&1 &
  disown || true
  sleep 2
fi

# The proxy nests the postgres socket under the (colon-bearing) instance name; symlink to a colon-free
# path so `ssh -L port:$HOME/db.sock` parses.
ln -sfn "$SOCK_DIR/${INSTANCE_CONNECTION_NAME}/.s.PGSQL.5432" "$LINK"
echo "SOCKET=${LINK}"
