#!/bin/bash
# Memory Bank hooks for Claude Code.
#
# Usage: memory-bank-hook.sh [stop|prompt|session-start]   (default: stop)
#
#   stop           Stop hook. Reminds about a stale memory bank.
#                    nudge  (default): tell the user once, never block
#                    strict: block once so Claude updates the bank
#                    off:    do nothing
#   prompt         UserPromptSubmit hook (nudge mode only). Adds one line of
#                  context so Claude updates the bank at a natural checkpoint.
#   session-start  SessionStart hook. Prints a short, size-capped summary of the
#                  memory bank (load_mode=summary), a one-line pointer
#                  (load_mode=pointer), or nothing (load_mode=off).
#
# Settings come from the plugin's userConfig, exported by Claude Code as
# CLAUDE_PLUGIN_OPTION_REMINDER_MODE, _MIN_CHANGED_FILES and _LOAD_MODE.
# Empty or unknown values fall back to the defaults.
#
# Design rules:
#   - Fail open: any error or missing tool means no output and exit 0.
#   - Never block twice in a row (honors "stop_hook_active").
#   - Ignore generated and git-ignored files so reminders reflect real work.
#   - No dependencies beyond bash, POSIX find/sed/tr, and (optionally) git.

EVENT="${1:-stop}"
INPUT=$(cat 2>/dev/null)

SUMMARY_MAX_CHARS=2000
ROOT=""
ACTIVE_WARN_LINES=150

# --- Settings ----------------------------------------------------------------
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

REMINDER_MODE=$(lower "$CLAUDE_PLUGIN_OPTION_REMINDER_MODE")
case "$REMINDER_MODE" in
  nudge|strict|off) ;;
  *) REMINDER_MODE=nudge ;;
esac

LOAD_MODE=$(lower "$CLAUDE_PLUGIN_OPTION_LOAD_MODE")
case "$LOAD_MODE" in
  summary|pointer|off) ;;
  *) LOAD_MODE=summary ;;
esac

MIN_CHANGED="${CLAUDE_PLUGIN_OPTION_MIN_CHANGED_FILES%%.*}"
case "$MIN_CHANGED" in
  ''|*[!0-9]*) MIN_CHANGED=1 ;;
esac
if [ "$MIN_CHANGED" -lt 1 ] 2>/dev/null; then
  MIN_CHANGED=1
fi

# --- Payload helpers (no jq dependency) ----------------------------------------
payload_true() {
  printf '%s' "$INPUT" | grep -q "\"$1\"[[:space:]]*:[[:space:]]*true"
}

payload_is() {
  printf '%s' "$INPUT" | grep -q "\"$1\"[[:space:]]*:[[:space:]]*\"$2\""
}

# Extract a simple top-level string field. Escaped characters inside the value
# are kept as-is, which is enough for the checks this script makes.
payload_string() {
  printf '%s' "$INPUT" \
    | sed -n -E "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"(([^\"\\\\]|\\\\.)*)\".*/\\1/p" \
    | head -1
}

# --- Project root ----------------------------------------------------------------
HAVE_GIT=0
if command -v git >/dev/null 2>&1; then
  HAVE_GIT=1
fi

resolve_root() {
  local start="" cwd top
  if [ -n "$CLAUDE_PROJECT_DIR" ] && [ -d "$CLAUDE_PROJECT_DIR" ]; then
    start="$CLAUDE_PROJECT_DIR"
  else
    # Unescape doubled backslashes (Windows paths).
    cwd=$(payload_string cwd | sed 's/\\\\/\\/g')
    if [ -n "$cwd" ] && [ -d "$cwd" ]; then
      start="$cwd"
    else
      start="$PWD"
    fi
  fi

  if [ -d "$start/memory-bank" ]; then
    ROOT="$start"
  elif [ "$HAVE_GIT" = 1 ]; then
    top=$(git -C "$start" rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$top" ] && [ -d "$top/memory-bank" ]; then
      ROOT="$top"
    fi
  fi

  [ -n "$ROOT" ] || return 1
  cd "$ROOT" 2>/dev/null || return 1
}

# --- Memory bank files -------------------------------------------------------------
# Prefer the newer two-file names when present, else the classic six-file names.
pick_files() {
  BRIEF=""
  ACTIVE=""
  if [ -f memory-bank/brief.md ]; then
    BRIEF=memory-bank/brief.md
  elif [ -f memory-bank/projectbrief.md ]; then
    BRIEF=memory-bank/projectbrief.md
  fi
  if [ -f memory-bank/active.md ]; then
    ACTIVE=memory-bank/active.md
  elif [ -f memory-bank/activeContext.md ]; then
    ACTIVE=memory-bank/activeContext.md
  fi
}

# Baseline = newest of the files the reminder asks Claude to update, so touching
# an unrelated sub-file does not silence it. Falls back to the newest *.md.
# find -exec runs ls only when something matches, so an empty bank stays empty.
find_baseline() {
  BASELINE=$(find ./memory-bank -maxdepth 1 -type f \
    \( -name activeContext.md -o -name progress.md -o -name active.md \) \
    -exec ls -t {} + 2>/dev/null | head -1)
  if [ -z "$BASELINE" ]; then
    BASELINE=$(find ./memory-bank -path ./memory-bank/archive -prune -o \
      -name "*.md" -type f -exec ls -t {} + 2>/dev/null | head -1)
  fi
  [ -n "$BASELINE" ]
}

# Sets NEWER_FILES (one per line, "./" prefix) and COUNT.
# -prune stops find from walking heavy generated folders at any depth; git
# check-ignore then drops ignored files (tracked files are never reported).
find_changed() {
  NEWER_FILES=$(find . \
    \( -name .git -o -name node_modules -o -name .venv -o -name venv \
       -o -name __pycache__ -o -name .next -o -name .cache -o -name .tox \
       -o -name .pytest_cache -o -name .mypy_cache -o -name .DS_Store \
       -o -path ./memory-bank -o -path ./.claude -o -path ./dist -o -path ./build \) \
    -prune -o -type f -newer "$BASELINE" -print 2>/dev/null)

  local in_git=0
  if [ "$HAVE_GIT" = 1 ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    in_git=1
  fi

  if [ -n "$NEWER_FILES" ] && [ "$in_git" = 1 ]; then
    local ignored
    ignored=$(printf '%s\n' "$NEWER_FILES" | git check-ignore --stdin 2>/dev/null)
    if [ -n "$ignored" ]; then
      NEWER_FILES=$(printf '%s\n' "$NEWER_FILES" \
        | grep -vxF -f <(printf '%s\n' "$ignored"))
    fi
  fi

  if [ "$in_git" = 1 ]; then
    local moved
    moved=$(find_moved_or_deleted)
    if [ -n "$moved" ]; then
      NEWER_FILES=$(printf '%s\n%s\n' "$NEWER_FILES" "$moved" | grep . | sort -u)
    fi
  fi

  if [ -z "$NEWER_FILES" ]; then
    COUNT=0
  else
    COUNT=$(printf '%s\n' "$NEWER_FILES" | grep -c .)
  fi
}

# Renames and deletions keep or remove the file, so its own mtime says nothing.
# git still lists the old path as deleted (a rename is a delete plus a new name),
# and removing an entry updates the parent folder's mtime. So a deleted tracked
# path counts only when its nearest existing parent folder is newer than the
# baseline, which skips deletions made before the last memory bank update
# without stored state. Covers plain rm/mv (unstaged) and git rm/git mv
# (staged). Paths are relative to the memory bank root, printed as
# "./path (deleted)".
parent_newer() {
  local dir
  dir=$(dirname "$1")
  while [ ! -d "$dir" ]; do
    dir=$(dirname "$dir")
  done
  [ "$dir" -nt "$BASELINE" ]
}

find_moved_or_deleted() {
  {
    git ls-files --deleted -z 2>/dev/null
    git diff --cached --name-only --relative --no-renames --diff-filter=D -z 2>/dev/null
  } | tr '\000' '\n' | grep -v -e '^memory-bank/' -e '^\.claude/' | sort -u | head -500 \
    | while IFS= read -r path; do
        [ -n "$path" ] && [ ! -e "$path" ] || continue
        parent_newer "$path" || continue
        printf './%s (deleted)\n' "$path"
      done
}

# True when the bank has a baseline and enough files changed since it.
is_stale() {
  find_baseline || return 1
  find_changed
  [ "$COUNT" -ge "$MIN_CHANGED" ]
}

# Up to five changed paths, comma separated, safe for plain text: in the C
# locale, drop control bytes and non-ASCII bytes (invalid UTF-8 would break JSON).
files_summary() {
  local shown list
  shown=$(printf '%s\n' "$NEWER_FILES" | head -5 | sed 's|^\./||')
  list=$(printf '%s' "$shown" | tr '\n' ',' | sed 's/,$//; s/,/, /g')
  if [ "$COUNT" -gt 5 ]; then
    list="$list (and $((COUNT - 5)) more)"
  fi
  printf '%s' "$list" | LC_ALL=C tr -d '\000-\037\177-\377'
}

# What the reminders ask Claude to update, depending on the bank's layout.
update_targets() {
  if [ -f memory-bank/active.md ]; then
    printf '%s' "$1memory-bank/active.md: current focus, next steps, status, known issues"
  else
    printf '%s' "$1memory-bank/activeContext.md: current focus, recent changes, next steps$2$1memory-bank/progress.md: what was completed, what remains, known issues"
  fi
}

update_files() {
  if [ -f memory-bank/active.md ]; then
    printf 'memory-bank/active.md'
  else
    printf 'memory-bank/activeContext.md and memory-bank/progress.md'
  fi
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# --- Once-per-session throttling for nudges -------------------------------------
# A marker file per session and kind. Notify when there is no marker, or when
# the memory bank was updated after the last notice (a new stale period).
# Without CLAUDE_PLUGIN_DATA or a session id there is no throttling; that only
# happens in nudge mode, which never blocks.
marker_path() {
  local sid
  sid=$(payload_string session_id | LC_ALL=C tr -cd 'A-Za-z0-9_-')
  if [ -z "$CLAUDE_PLUGIN_DATA" ] || [ -z "$sid" ]; then
    return 1
  fi
  printf '%s/state/%s.%s' "$CLAUDE_PLUGIN_DATA" "$sid" "$1"
}

should_notify() {
  local marker
  marker=$(marker_path "$1") || return 0
  [ ! -e "$marker" ] || [ "$BASELINE" -nt "$marker" ]
}

mark_notified() {
  local marker dir
  marker=$(marker_path "$1") || return 0
  dir=$(dirname "$marker")
  mkdir -p "$dir" 2>/dev/null || return 0
  : > "$marker" 2>/dev/null
  # Forget markers from sessions older than a week.
  find "$dir" -type f -mtime +7 -exec rm -f {} + 2>/dev/null
}

# --- Events ----------------------------------------------------------------------
run_stop() {
  # Re-entrant stop: Claude is already continuing because of a block.
  payload_true stop_hook_active && return 0
  # Plan mode is read-only; asking Claude to write files there is pointless.
  payload_is permission_mode plan && return 0
  [ "$REMINDER_MODE" = off ] && return 0

  resolve_root || return 0
  is_stale || return 0

  if [ "$REMINDER_MODE" = strict ]; then
    local files
    files=$(json_escape "$(files_summary)")
    printf '{"decision":"block","reason":"Before finishing, update the memory bank to capture recent work.\\n\\n%s file(s) changed since the last memory bank update: %s\\n\\nPlease update:\\n%s\\n\\nOnce updated, you can stop."}\n' \
      "$COUNT" "$files" "$(update_targets '- ' '\n')"
    return 0
  fi

  should_notify stop || return 0
  printf '{"systemMessage":"Memory bank may be out of date: %s file(s) changed since the last update. Say \\"update memory bank\\" to refresh it."}\n' "$COUNT"
  mark_notified stop
}

run_prompt() {
  [ "$REMINDER_MODE" = nudge ] || return 0
  payload_is permission_mode plan && return 0
  # The user is already asking about the memory bank.
  payload_string prompt | grep -qi 'memory[ _-]*bank' && return 0

  resolve_root || return 0
  is_stale || return 0
  should_notify prompt || return 0

  printf 'Memory bank note: memory-bank/ is out of date (%s file(s) changed since the last update: %s). At a natural checkpoint in this task, update %s.\n' \
    "$COUNT" "$(files_summary)" "$(update_files)"
  mark_notified prompt
}

# First non-blank lines of a file, as plain text without control characters.
excerpt() {
  grep -v '^[[:space:]]*$' "$1" 2>/dev/null | head -n "$2" | tr -d '\000-\010\013-\037'
}

run_session_start() {
  [ "$LOAD_MODE" = off ] && return 0
  resolve_root || return 0
  pick_files

  if [ "$LOAD_MODE" = pointer ]; then
    local targets=""
    [ -n "$ACTIVE" ] && targets="$ACTIVE"
    [ -n "$BRIEF" ] && targets="${targets:+$targets and }$BRIEF"
    if [ -n "$targets" ]; then
      printf 'Memory bank: shared project state lives in memory-bank/. Read %s before substantial work.\n' "$targets"
    else
      printf 'Memory bank: memory-bank/ exists but has no core files yet. Say "initialize memory bank" to create them.\n'
    fi
    return 0
  fi

  local out others lines
  out="# Memory bank (shared, git-tracked project state)
Summary loaded at session start. Read the full files in memory-bank/ only when the task needs them."

  if [ -z "$BRIEF" ] && [ -z "$ACTIVE" ]; then
    if ! find ./memory-bank -path ./memory-bank/archive -prune -o -name "*.md" -type f \
         -print 2>/dev/null | grep -q .; then
      printf '%s\n%s\n' "$out" 'memory-bank/ exists but has no files yet. Say "initialize memory bank" to create them.'
      return 0
    fi
  fi

  if [ -n "$BRIEF" ]; then
    out="$out

## Brief ($BRIEF)
$(excerpt "$BRIEF" 12)"
  else
    out="$out

Missing: memory-bank/$( [ "$ACTIVE" = memory-bank/active.md ] && echo brief.md || echo projectbrief.md )."
  fi

  if [ -n "$ACTIVE" ]; then
    out="$out

## Current focus ($ACTIVE)
$(excerpt "$ACTIVE" 25)"
    lines=$(wc -l < "$ACTIVE" | tr -d ' ')
    if [ "${lines:-0}" -gt "$ACTIVE_WARN_LINES" ]; then
      out="$out

Note: $ACTIVE is $lines lines long. Consider \"consolidate memory bank\" to keep it a short snapshot."
    fi
  else
    out="$out

Missing: memory-bank/$( [ "$BRIEF" = memory-bank/brief.md ] && echo active.md || echo activeContext.md ). Say \"update memory bank\" to create it."
  fi

  others=$(find ./memory-bank -path ./memory-bank/archive -prune -o -name "*.md" -type f \
      -print 2>/dev/null \
    | sed 's|^\./||' | grep -vxF -e "$BRIEF" -e "$ACTIVE" \
    | sort | head -20 | tr '\n' ',' | sed 's/,$//; s/,/, /g')
  if [ -n "$others" ]; then
    out="$out

Other memory bank files (read on demand): $others"
  fi

  if [ "$REMINDER_MODE" != off ] && is_stale; then
    out="$out

The memory bank may be out of date: $COUNT file(s) changed since its last update."
  fi

  if [ "${#out}" -gt "$SUMMARY_MAX_CHARS" ]; then
    out="${out:0:$((SUMMARY_MAX_CHARS - 20))}
...(truncated)"
  fi
  printf '%s\n' "$out"
}

case "$EVENT" in
  stop) run_stop ;;
  prompt) run_prompt ;;
  session-start) run_session_start ;;
esac
exit 0
