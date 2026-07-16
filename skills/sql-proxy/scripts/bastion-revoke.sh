#!/usr/bin/env bash
#
# Runs ON the bastion (piped via `gcloud compute ssh … -- bash -s < bastion-revoke.sh`). Best-effort
# teardown of THIS user's Cloud SQL access: stop this user's proxy (confirming it actually exits,
# escalating to SIGKILL if needed — same as bastion-stop-proxy.sh), revoke their long-lived creds
# (gcloud account + ADC), and remove their socket. Never hard-fails — each step is independent, so a
# failure just prints a warning and the rest still runs.
#
# Multi-user-safe: only ever touches the current OS Login user's own processes and files, so it's safe
# to run on a bastion shared by other developers.
set -uo pipefail
me="$(id -un)"
TIMEOUT="${TIMEOUT:-30}"

if pgrep -u "$me" -f cloud-sql-proxy >/dev/null 2>&1; then
  pkill -u "$me" -f cloud-sql-proxy 2>/dev/null || true
  waited=0
  while pgrep -u "$me" -f cloud-sql-proxy >/dev/null 2>&1; do
    if [ "$waited" -ge "$TIMEOUT" ]; then
      pkill -9 -u "$me" -f cloud-sql-proxy 2>/dev/null || true
      sleep 1
      break
    fi
    sleep 1
    waited=$((waited + 1))
  done
  if pgrep -u "$me" -f cloud-sql-proxy >/dev/null 2>&1; then
    echo "WARN: cloud-sql-proxy for ${me} did not stop within ${TIMEOUT}s"
  else
    echo "stopped cloud-sql-proxy"
  fi
else
  echo "WARN: no cloud-sql-proxy running for ${me}"
fi

gcloud auth application-default revoke --quiet 2>/dev/null && echo "revoked ADC" \
  || echo "WARN: no ADC to revoke (or revoke failed)"

gcloud auth revoke --all --quiet 2>/dev/null && echo "revoked gcloud account creds" \
  || echo "WARN: no gcloud account creds to revoke (or revoke failed)"

rm -rf "$HOME/csql" "$HOME/db.sock" 2>/dev/null && echo "removed socket dir + symlink" || true

echo "REVOKE_DONE"
