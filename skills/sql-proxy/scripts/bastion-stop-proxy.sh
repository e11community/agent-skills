#!/usr/bin/env bash
#
# Runs ON the bastion (piped via `gcloud compute ssh … -- bash -s < bastion-stop-proxy.sh`). Stops
# THIS user's cloud-sql-proxy process and waits up to TIMEOUT seconds (default 30) for it to actually
# exit, escalating to SIGKILL if it's still alive at the deadline. Reports the outcome via a status
# line rather than exit code, so the caller can warn-and-continue instead of aborting teardown.
#
# Multi-user-safe: only ever touches the current OS Login user's own process.
set -uo pipefail
me="$(id -un)"
TIMEOUT="${TIMEOUT:-30}"

if ! pgrep -u "$me" -f cloud-sql-proxy >/dev/null 2>&1; then
  echo "PROXY_NOT_RUNNING"
  exit 0
fi

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
  echo "PROXY_STOP_TIMEOUT"
else
  echo "PROXY_STOPPED"
fi
