#!/usr/bin/env bash
#
# Runs ON the laptop. Stops and cleans up the local -> bastion tunnel(s) this skill started — and
# nothing else (leaves the bastion proxy and your creds alone). Best-effort; never hard-fails.
set -uo pipefail

STATE_DIR="${STATE_DIR:-$HOME/.config/sql-proxy}"
PIDFILE="$STATE_DIR/tunnel.pid"

if [ -f "$PIDFILE" ]; then
  while read -r pid; do
    [ -n "${pid:-}" ] || continue
    kill "$pid" 2>/dev/null && echo "killed tunnel pid ${pid}" || echo "tunnel pid ${pid} not running"
  done < "$PIDFILE"
  rm -f "$PIDFILE"
fi

# Fallback: catch orphaned tunnels (and their ssh children) by command signature — e.g. leftovers
# from an older session with no PID file.
pkill -f 'gcloud compute ssh .* -L .*db\.sock' 2>/dev/null && echo "killed stray tunnel(s)" || true

echo "STOP_DONE"
