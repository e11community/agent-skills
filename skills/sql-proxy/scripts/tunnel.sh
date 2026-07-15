#!/usr/bin/env bash
#
# Runs ON the laptop (start with run_in_background). Forwards localhost:$LOCAL_PORT to the developer's
# own proxy socket on the bastion, over an IAP SSH tunnel, and auto-reconnects if the tunnel drops.
#
# Env: BASTION, ZONE, PROJECT_ID, REMOTE_SOCK (e.g. /home/<os-login-user>/db.sock); LOCAL_PORT=5432.
set -uo pipefail

BASTION="${BASTION:?set BASTION}"
ZONE="${ZONE:?set ZONE}"
PROJECT_ID="${PROJECT_ID:?set PROJECT_ID}"
REMOTE_SOCK="${REMOTE_SOCK:?set REMOTE_SOCK (e.g. /home/USER/db.sock)}"
LOCAL_PORT="${LOCAL_PORT:-5432}"
STATE_DIR="${STATE_DIR:-$HOME/.config/sql-proxy}"

# Record our PID so `--stop` (stop-local.sh) can find and kill this tunnel across sessions.
mkdir -p "$STATE_DIR"
echo "$$" >> "$STATE_DIR/tunnel.pid"

while true; do
  echo "tunnel: localhost:${LOCAL_PORT} -> ${BASTION}:${REMOTE_SOCK}"
  gcloud compute ssh "$BASTION" --zone "$ZONE" --project "$PROJECT_ID" --tunnel-through-iap \
    -- -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 \
       -L "${LOCAL_PORT}:${REMOTE_SOCK}" || true
  echo "tunnel dropped; reconnecting in 3s (Ctrl-C / stop the background task to quit)..." >&2
  sleep 3
done
