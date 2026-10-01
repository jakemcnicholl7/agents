#!/usr/bin/env bash
# Set the Claude Code session display name for the session that invokes this.
#
# There is no tool or hook that can rename a session (/rename is user-typed
# only), so write the two files the CLI persists a name into:
#   <project>/<sessionId>/custom-title.json   {"customTitle": "..."}
#   <project>/<sessionId>.jsonl               a {"type":"custom-title",...} record
#
# The live prompt box reads the name from in-memory state, so it will NOT
# refresh mid-session — the name surfaces in the /resume picker and on restart.
# For the terminal title, use set-terminal-title.sh instead.
#
# Usage: set-session-name.sh <name>
#
# Relies on undocumented CLI internals (verified against v2.1.241). Best-effort
# by design: exits 0 with an explanatory message when it cannot do the job.

set -uo pipefail

name=${1:-}
if [ -z "$name" ]; then
  echo "usage: ${0##*/} <name>" >&2
  exit 2
fi

session=${CLAUDE_CODE_SESSION_ID:-}
if [ -z "$session" ]; then
  echo "session name not set: CLAUDE_CODE_SESSION_ID is unset"
  exit 0
fi

# The project directory is slugified from the session's launch cwd, so locate it
# by finding the transcript for this session rather than recomputing the slug.
transcript=$(ls "$HOME"/.claude/projects/*/"$session".jsonl 2>/dev/null | head -1)
if [ -z "$transcript" ]; then
  echo "session name not set: no transcript found for $session"
  exit 0
fi

project_dir=$(dirname "$transcript")

if ! mkdir -p "$project_dir/$session" 2>/dev/null; then
  echo "session name not set: could not create $project_dir/$session"
  exit 0
fi

printf '{"customTitle":"%s"}' "$name" > "$project_dir/$session/custom-title.json"
printf '{"type":"custom-title","customTitle":"%s","sessionId":"%s"}\n' \
  "$name" "$session" >> "$transcript"

echo "session name set to: $name (visible in /resume)"
exit 0
