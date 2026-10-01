#!/usr/bin/env bash
# Set the terminal tab/window title for the Claude Code session that invokes this.
#
# Usage: set-terminal-title.sh <title>
#
# Why not just `printf '\033]0;title\007'`? A Claude Code tool subprocess has no
# controlling terminal — its stdout is a captured pipe, and /dev/tty fails with
# "device not configured". So instead resolve the tty that the Claude Code
# process itself is attached to and write the escape sequence to that device
# node directly. The node is owned by the invoking user (crw--w---- user tty),
# so this needs no special privileges and works on any emulator that honours
# OSC titles — and on Linux too, where `ps -o tty=` yields e.g. "pts/3".
#
# REQUIRES: CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 in a settings.json "env" block.
# Claude Code otherwise repaints the title from its own state on every render
# and overwrites this within about a second.
#
# Best-effort by design: exits 0 with an explanatory message on any surface it
# cannot drive, so a caller can ignore the outcome.

set -uo pipefail

title=${1:-}
if [ -z "$title" ]; then
  echo "usage: ${0##*/} <title>" >&2
  exit 2
fi

# The title is interpolated into an escape sequence, so strip control characters
# to prevent a crafted name from injecting further sequences into the terminal.
title=$(printf '%s' "$title" | tr -d '\000-\037\177')
if [ -z "$title" ]; then
  echo "title not set: name is empty after removing control characters"
  exit 0
fi

# Under tmux the window name owns the tab label and OSC titles only reach the
# pane title, so rename the window instead. An explicit rename also turns off
# automatic-rename for that window, making it stick.
if [ -n "${TMUX:-}" ]; then
  if tmux rename-window "$title" 2>/dev/null; then
    echo "tmux window renamed to: $title"
    exit 0
  fi
  echo "title not set: tmux rename-window failed"
  exit 0
fi

# CLAUDE_PID is the Claude Code process, which is the one holding the tty.
# $PPID is a fallback for use outside Claude Code.
pid=${CLAUDE_PID:-$PPID}
tty_name=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d '[:space:]')

if [ -z "$tty_name" ] || [ "$tty_name" = "??" ] || [ "$tty_name" = "-" ]; then
  echo "title not set: no controlling tty for pid $pid"
  exit 0
fi

tty_dev="/dev/$tty_name"
if [ ! -w "$tty_dev" ]; then
  echo "title not set: $tty_dev is not writable"
  exit 0
fi

# OSC 1 sets the icon/tab name, OSC 2 the window title. Emitting both covers
# emulators that read only one of them.
if printf '\033]1;%s\007\033]2;%s\007' "$title" "$title" > "$tty_dev" 2>/dev/null; then
  echo "terminal title set to: $title (via $tty_dev)"
else
  echo "title not set: write to $tty_dev failed"
fi

exit 0
