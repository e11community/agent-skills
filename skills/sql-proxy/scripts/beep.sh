#!/usr/bin/env bash
#
# Runs ON the laptop. Best-effort ANSI bell (BEL, \a) to get the developer's attention right before the
# browser opens for Google login — the login usually comes mid-session, after the user has looked away.
#
# Never fails: every error is swallowed and the script always exits 0, so the login flow continues
# whether or not a bell sounds (no terminal, bell muted, unsupported OS, etc.).
#
# An agent's shell usually has no controlling terminal, so /dev/tty can't be opened. Fall back to the
# terminal of the nearest ancestor process that has one (the terminal the agent itself runs in), which
# the user owns and can write to.

beep_to() { { printf '\a' >"$1"; } 2>/dev/null; }

main() {
  beep_to /dev/tty && return 0

  local pid="$$" tty
  local i
  for ((i = 0; i < 20; i++)); do
    pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
    [ -n "$pid" ] && [ "$pid" -gt 1 ] 2>/dev/null || return 0
    tty="$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')"
    case "$tty" in
      '' | '?' | '??') continue ;;
    esac
    case "$tty" in /dev/*) ;; *) tty="/dev/$tty" ;; esac
    [ -w "$tty" ] && beep_to "$tty" && return 0
  done
  return 0
}

main 2>/dev/null || true
exit 0
