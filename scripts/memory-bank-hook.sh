#!/bin/bash
# Memory Bank Update Reminder (Stop hook)
#
# Checks whether project files changed after the memory bank was last updated.
# If so, asks Claude to update activeContext.md and progress.md before stopping.
#
# Design rules:
#   - Fail open: any error or missing tool means "allow the stop" (exit 0, no output).
#   - Never block twice in a row (honors "stop_hook_active").
#   - Ignore generated and git-ignored files so reminders reflect real work.
#   - No dependencies beyond bash, POSIX find/sed/tr, and (optionally) git.
#
# Logic:
#   1. Read the hook payload. Exit if re-entrant or in plan mode.
#   2. Find the project root: $CLAUDE_PROJECT_DIR, else the payload "cwd", else
#      $PWD. If that folder has no memory-bank/, try its git top level.
#   3. Baseline = newest of memory-bank/activeContext.md and progress.md (the
#      files the reminder asks for). If neither exists, newest *.md in the bank.
#   4. List files newer than the baseline, pruning heavy generated folders, and
#      drop anything git ignores.
#   5. If any remain, output a block decision listing up to five of them.

INPUT=$(cat 2>/dev/null)

# Re-entrant stop: Claude is already continuing because of a previous block.
# Blocking again could loop (e.g. a file with a future mtime), so let it stop.
if printf '%s' "$INPUT" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

# Plan mode is read-only; asking Claude to write files there is pointless.
if printf '%s' "$INPUT" | grep -q '"permission_mode"[[:space:]]*:[[:space:]]*"plan"'; then
  exit 0
fi

# --- Resolve the project root -------------------------------------------------
# Extract "cwd" from the payload without jq. Handles escaped backslashes
# (Windows paths); a path containing an escaped double quote is not supported
# and simply falls through to $PWD.
payload_cwd() {
  printf '%s' "$INPUT" \
    | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -1 \
    | sed 's/\\\\/\\/g'
}

START_DIR=""
if [ -n "$CLAUDE_PROJECT_DIR" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
  START_DIR="$CLAUDE_PROJECT_DIR"
else
  CWD_FROM_INPUT=$(payload_cwd)
  if [ -n "$CWD_FROM_INPUT" ] && [ -d "$CWD_FROM_INPUT" ]; then
    START_DIR="$CWD_FROM_INPUT"
  else
    START_DIR="$PWD"
  fi
fi

HAVE_GIT=0
if command -v git >/dev/null 2>&1; then
  HAVE_GIT=1
fi

ROOT=""
if [ -d "$START_DIR/memory-bank" ]; then
  ROOT="$START_DIR"
elif [ "$HAVE_GIT" = 1 ]; then
  TOP=$(git -C "$START_DIR" rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$TOP" ] && [ -d "$TOP/memory-bank" ]; then
    ROOT="$TOP"
  fi
fi

if [ -z "$ROOT" ]; then
  exit 0
fi

cd "$ROOT" 2>/dev/null || exit 0

# --- Baseline: when was the memory bank last updated? -------------------------
# Prefer the two files the reminder asks for, so touching an unrelated sub-file
# in memory-bank/ does not silence the reminder. find -exec runs ls only when
# something matches, so an empty bank leaves BASELINE empty.
BASELINE=$(find ./memory-bank -maxdepth 1 -type f \
  \( -name activeContext.md -o -name progress.md \) \
  -exec ls -t {} + 2>/dev/null | head -1)

if [ -z "$BASELINE" ]; then
  BASELINE=$(find ./memory-bank -name "*.md" -type f -exec ls -t {} + 2>/dev/null \
    | head -1)
fi

if [ -z "$BASELINE" ]; then
  exit 0
fi

# --- Files changed since the baseline -----------------------------------------
# -prune stops find from descending into heavy generated folders at any depth
# (plain -not -path would still walk them). Top-level dist/ and build/ are
# skipped as before; nested ones are left to .gitignore below.
NEWER_FILES=$(find . \
  \( -name .git -o -name node_modules -o -name .venv -o -name venv \
     -o -name __pycache__ -o -name .next -o -name .cache -o -name .tox \
     -o -name .pytest_cache -o -name .mypy_cache -o -name .DS_Store \
     -o -path ./memory-bank -o -path ./.claude -o -path ./dist -o -path ./build \) \
  -prune -o -type f -newer "$BASELINE" -print 2>/dev/null)

# Drop git-ignored files (build output, logs, coverage, local env files).
# Tracked files are never reported as ignored, so real edits are kept.
if [ -n "$NEWER_FILES" ] && [ "$HAVE_GIT" = 1 ] \
   && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  IGNORED=$(printf '%s\n' "$NEWER_FILES" | git check-ignore --stdin 2>/dev/null)
  if [ -n "$IGNORED" ]; then
    NEWER_FILES=$(printf '%s\n' "$NEWER_FILES" \
      | grep -vxF -f <(printf '%s\n' "$IGNORED"))
  fi
fi

if [ -z "$NEWER_FILES" ]; then
  exit 0
fi

COUNT=$(printf '%s\n' "$NEWER_FILES" | grep -c .)
SHOWN=$(printf '%s\n' "$NEWER_FILES" | head -5 | sed 's|^\./||')
FILES_LIST=$(printf '%s' "$SHOWN" | tr '\n' ',' | sed 's/,$//; s/,/, /g')
if [ "$COUNT" -gt 5 ]; then
  FILES_LIST="$FILES_LIST (and $((COUNT - 5)) more)"
fi

# Make the list safe inside a JSON string: in the C locale, drop control bytes
# and any non-ASCII bytes (invalid UTF-8 would make the JSON invalid), then
# escape backslashes (first) and double quotes.
FILES_LIST=$(printf '%s' "$FILES_LIST" | LC_ALL=C tr -d '\000-\037\177-\377' \
  | sed 's/\\/\\\\/g; s/"/\\"/g')

printf '{"decision":"block","reason":"Before finishing, update the memory bank to capture recent work.\\n\\n%s file(s) changed since the last memory bank update: %s\\n\\nPlease update:\\n- memory-bank/activeContext.md: current focus, recent changes, next steps\\n- memory-bank/progress.md: what was completed, what remains, known issues\\n\\nOnce updated, you can stop."}\n' "$COUNT" "$FILES_LIST"
exit 0
