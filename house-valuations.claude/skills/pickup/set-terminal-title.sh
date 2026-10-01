#!/usr/bin/env bash
# Set the terminal tab/window title for the Claude Code session that invokes this.
#
# Claude Code owns the title via OSC escape sequences written to its controlling
# terminal, and tool subprocesses have no controlling terminal ("device not
# configured: /dev/tty"), so the title cannot be set by echoing an escape code.
# Instead drive the terminal emulator itself. On Apple Terminal a "custom title"
# is sticky and takes precedence over the OSC sequences Claude Code emits.
#
# Usage: set-terminal-title.sh <title>
#
# Best-effort by design: exits 0 with an explanatory message on any surface it
# cannot drive, so a caller can ignore the outcome.

set -uo pipefail

title=${1:-}
if [ -z "$title" ]; then
  echo "usage: ${0##*/} <title>" >&2
  exit 2
fi

# Under tmux the window name owns the tab label, and renaming needs no
# emulator-specific handling.
if [ -n "${TMUX:-}" ]; then
  if tmux rename-window "$title" 2>/dev/null; then
    echo "tmux window renamed to: $title"
    exit 0
  fi
fi

# CLAUDE_PID is the Claude Code process, which is the one attached to the tty.
# $PPID is a reasonable fallback but will usually be that same process.
pid=${CLAUDE_PID:-$PPID}
tty_name=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d '[:space:]')

if [ -z "$tty_name" ] || [ "$tty_name" = "??" ]; then
  echo "no controlling tty for pid $pid; title not set"
  exit 0
fi

case "${TERM_PROGRAM:-}" in
  Apple_Terminal)
    result=$(osascript - "/dev/$tty_name" "$title" <<'APPLESCRIPT' 2>&1
on run argv
  set targetTty to item 1 of argv
  set newTitle to item 2 of argv
  tell application "Terminal"
    repeat with w in windows
      repeat with t in tabs of w
        if tty of t is targetTty then
          set custom title of t to newTitle
          return "ok"
        end if
      end repeat
    end repeat
  end tell
  return "no tab is attached to " & targetTty
end run
APPLESCRIPT
    )
    if [ "$result" = "ok" ]; then
      echo "terminal title set to: $title"
    else
      echo "title not set: $result"
    fi
    ;;
  *)
    echo "title not set: unsupported terminal '${TERM_PROGRAM:-unknown}'"
    ;;
esac

exit 0
