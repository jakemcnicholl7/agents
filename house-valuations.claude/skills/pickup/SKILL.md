---
name: pickup
description: Pick up a new item of work — creates a named git worktree and forks an agent to begin immediately
---

# Pickup

Creates a persistent git worktree for a new thread of work and forks an agent to begin on it immediately. Multiple `/pickup` calls can run in parallel — each gets its own branch and worktree.

## When invoked

The user passes a work description as args, e.g. `/pickup add payment flow for subscriptions`.

## Steps to follow

### 1. Derive a slug

From the work description: lowercase, spaces to hyphens, strip non-alphanumeric characters except hyphens, max 40 chars.

Example: "add payment flow for subscriptions" → `add-payment-flow-for-subscriptions`

### 2. Create the worktree

This is a bare-repo + worktrees setup. The repo root is `/Users/jacob/personal-workplace/worktree/house-valuations/`, with `main/` as the primary worktree. New pickup worktrees go as siblings to `main/`, i.e. at `/Users/jacob/personal-workplace/worktree/house-valuations/pickup-<slug>/`.

Run from the main worktree:

```bash
git -C /Users/jacob/personal-workplace/worktree/house-valuations/main worktree add ../pickup-<slug> -b pickup/<slug>
```

If that branch already exists, omit `-b`:

```bash
git -C /Users/jacob/personal-workplace/worktree/house-valuations/main worktree add ../pickup-<slug> pickup/<slug>
```

### 3. Name this session after the worktree

Set the current session's display name to `pickup-<slug>` so it is identifiable in the `/resume` picker. Run:

```bash
/Users/jacob/personal-workplace/worktree/house-valuations/.claude/skills/pickup/set-session-name.sh "pickup-<slug>"
```

There is no tool or hook that can rename a session, so the script writes the two files the CLI persists a name into. It relies on undocumented CLI internals (verified against v2.1.241) and so may stop working after an upgrade.

The live prompt box reads the name from in-memory state, so it will not refresh mid-session — the name shows up in `/resume` and on restart. The terminal title is handled separately, in the next step.

Use the absolute path above verbatim: it is allowlisted in `.claude/settings.json`, so it runs without a permission prompt.

### 4. Set the terminal title

This is the surface that actually gives visibility across tabs. Run:

```bash
/Users/jacob/personal-workplace/worktree/house-valuations/.claude/skills/pickup/set-terminal-title.sh "pickup-<slug>"
```

The script drives the terminal emulator directly (Apple Terminal via AppleScript, or `tmux rename-window` under tmux) because a tool subprocess has no controlling terminal and so cannot emit the usual OSC title escape.

This only holds because `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` is set in `.claude/settings.json` — otherwise Claude Code repaints the title and overwrites it within a second. If the title reverts, check that env var is still set and that the session was restarted after it was added.

Use the absolute path above verbatim: it is allowlisted in `.claude/settings.json`, so it runs without a permission prompt.

Both scripts always exit 0 and report what they did. Do not retry or debug either one if it reports it could not do the job — carry on and pass that along in the final report.

### 5. Fork an agent

Use `Agent` with `subagent_type: "fork"`. The fork inherits the full conversation context, so brief it concisely:

- The work description and intent
- That it is working in `/Users/jacob/personal-workplace/worktree/house-valuations/pickup-<slug>` on branch `pickup/<slug>`
- To read `CLAUDE.md` for project context if needed (it's at the root of the worktree)
  - To run backend tests without `poetry install` on the current branch, use either:
      - `VIRTUAL_ENV=$(./package_scripts/get_env.sh) poetry run pytest` (canonical — supports all `poetry run` flags naturally)
      - `bash ./package_scripts/poetry_run.sh pytest` (shorthand wrapper for the above)
- **Scope guidance:**
  - Vague/exploratory description → brainstorm, produce a written plan, surface questions
  - Specific feature or bug → begin implementation immediately, create a PR when done

The fork runs in the background. Tell it to finish by either producing a plan document or a PR.

### 6. Report to the user

One or two sentences: the branch name, the worktree path, and that the agent is running. Mention the terminal title only if setting it failed. Nothing else.

## Rules

- Always create the worktree before forking the agent.
- Name the session and set the terminal title before forking, and only from the slug of the worktree just created — never use any other name.
- Worktrees always go inside `/Users/jacob/personal-workplace/worktree/house-valuations/` as siblings to `main/`.
- If the slug would collide with an existing directory, append a short suffix (`-2`, `-3`, etc.).
- The forked agent works entirely inside its own worktree — it must not modify files under `main/`.
