#!/usr/bin/env bash
#
# Runs ON the laptop (start with run_in_background). Drives the one-time / repair ADC login on the
# headless bastion using the `--no-browser` remote-bootstrap handshake (the OOB copy/paste-code flow is
# deprecated, so we coordinate a local gcloud that can open a browser).
#
# The agent orchestrates:
#   1. Run this. It prints  BOOTSTRAP_CMD=<gcloud … --remote-bootstrap="…">  and  RESP_FILE=<path>.
#   2. Run BOOTSTRAP_CMD locally — the local gcloud opens the browser; the user authenticates; the
#      command prints a verification code.
#   3. Write that code into RESP_FILE. This script relays it to the bastion and prints ADC_LOGIN_DONE.
set -uo pipefail

BASTION="${BASTION:?set BASTION}"
ZONE="${ZONE:?set ZONE}"
PROJECT_ID="${PROJECT_ID:?set PROJECT_ID}"

WORK="$(mktemp -d)"
FIFO="$WORK/in"; OUT="$WORK/out"; RESP_FILE="$WORK/response"
mkfifo "$FIFO"

# Hold the FIFO open for writing so the remote login's stdin doesn't hit EOF before we send the code.
exec 3>"$FIFO"

gcloud compute ssh "$BASTION" --zone "$ZONE" --project "$PROJECT_ID" --tunnel-through-iap \
  -- gcloud auth application-default login --no-browser <"$FIFO" >"$OUT" 2>&1 &
SSH_PID=$!

# Wait for the bootstrap command the bastion prints for us to run locally.
for _ in $(seq 1 60); do grep -q -- '--remote-bootstrap=' "$OUT" 2>/dev/null && break; sleep 1; done
BOOTSTRAP_CMD="$(grep -o 'gcloud auth application-default login --remote-bootstrap="[^"]*"' "$OUT" | head -1)"
if [ -z "$BOOTSTRAP_CMD" ]; then
  echo "ERROR: no --remote-bootstrap command appeared; check gcloud version / bastion output:" >&2
  cat "$OUT" >&2
  kill "$SSH_PID" 2>/dev/null || true
  exit 1
fi
echo "BOOTSTRAP_CMD=${BOOTSTRAP_CMD}"
echo "RESP_FILE=${RESP_FILE}"

# Wait (up to 5 min) for the agent to run BOOTSTRAP_CMD locally and drop the verification code here.
for _ in $(seq 1 300); do [ -s "$RESP_FILE" ] && break; sleep 1; done
if [ ! -s "$RESP_FILE" ]; then
  echo "ERROR: no verification code written to RESP_FILE in time" >&2
  kill "$SSH_PID" 2>/dev/null || true
  exit 1
fi

# Relay the code to the bastion's waiting login prompt, then let it finish writing ADC.
printf '%s\n' "$(cat "$RESP_FILE")" >&3
exec 3>&-
wait "$SSH_PID" || true
echo "ADC_LOGIN_DONE"
