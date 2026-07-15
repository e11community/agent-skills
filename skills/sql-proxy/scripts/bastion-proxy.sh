#!/usr/bin/env bash
#
# Runs ON the bastion (piped in via `gcloud compute ssh … -- bash -s <instance> < bastion-proxy.sh`).
# Idempotent: verifies the dev's own ADC, then starts a per-user Cloud SQL Auth Proxy on a socket under
# $HOME (no port, no assigned id) and symlinks it to a colon-free path for `ssh -L`.
#
# Exit 10 + "ADC_INVALID": no usable ADC (missing, revoked, or a reauth policy fired) — the caller must
# run the interactive login, then re-run this. This same signal drives repair-on-expiry.
set -euo pipefail

INSTANCE_CONNECTION_NAME="${1:?instance connection name required (project:region:instance)}"
SOCK_DIR="$HOME/csql"
LINK="$HOME/db.sock"

# Handles existing ADC (skips login) but treats expiry/revoke as invalid (triggers re-login upstream).
if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
  echo "ADC_INVALID"
  exit 10
fi

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
