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
#   session-start  SessionStart hook. Prints the full brief and active files of
#                  the memory bank (load_mode=summary), a one-line pointer
#                  (load_mode=pointer), or nothing (load_mode=off).
#
# All events also run a warn-only secret check on memory-bank/ (secret_scan):
# the stop event tells the user once per change, and session-start redacts
# values from the summary and tells Claude. Secret values are never printed.
#
# Settings come from the plugin's userConfig, exported by Claude Code as
# CLAUDE_PLUGIN_OPTION_REMINDER_MODE, _MIN_CHANGED_FILES, _LOAD_MODE and
# _SECRET_SCAN.
# Empty or unknown values fall back to the defaults.
#
# Design rules:
#   - Fail open: any error or missing tool means no output and exit 0.
#   - Never block twice in a row (honors "stop_hook_active").
#   - Ignore generated and git-ignored files so reminders reflect real work.
#   - No dependencies beyond bash, POSIX find/sed/tr, and (optionally) git.

EVENT="${1:-stop}"
INPUT=$(cat 2>/dev/null)

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

SECRET_SCAN=$(lower "$CLAUDE_PLUGIN_OPTION_SECRET_SCAN")
case "$SECRET_SCAN" in
  false|off|no|0) SECRET_SCAN=off ;;
  *) SECRET_SCAN=on ;;
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

# --- Secret check (warn only) ------------------------------------------------------
# "kind|extended regex" per line. Only high-confidence formats, to keep false
# alarms rare. Order matters: a line is reported once, with the first match.
# Placeholders such as user:<password>@ or user:${PASS}@ are not flagged.
SECRET_PATTERNS='private key|-----BEGIN ([A-Z]+ )?PRIVATE KEY-----
AWS access key|(AKIA|ASIA)[0-9A-Z]{16}
GitHub token|gh[pousr]_[A-Za-z0-9]{36,}
GitHub token|github_pat_[A-Za-z0-9_]{40,}
Anthropic API key|sk-ant-[A-Za-z0-9_-]{20,}
OpenAI API key|sk-(proj-)?[A-Za-z0-9_-]{32,}
Slack token|xox[abposr]-[A-Za-z0-9-]{10,}
Google API key|AIza[0-9A-Za-z_-]{35}
Stripe live key|(sk|rk)_live_[0-9A-Za-z]{20,}
password in a URL|[a-z][a-z0-9+.-]*://[^/[:space:]:@]+:[^/[:space:]@<$*{][^/[:space:]@]*@'

# Sets SECRET_HITS: one "path:line (kind)" per line. Never includes the value.
scan_secrets() {
  SECRET_HITS=""
  [ "$SECRET_SCAN" = on ] || return 1
  local kind re hits
  while IFS='|' read -r kind re; do
    [ -n "$re" ] || continue
    hits=$(find ./memory-bank -name "*.md" -type f -exec grep -nE -e "$re" /dev/null {} + \
      2>/dev/null | cut -d: -f1,2 | sed "s|^\./||; s|\$| ($kind)|")
    if [ -n "$hits" ]; then
      SECRET_HITS="$SECRET_HITS$hits
"
    fi
  done <<EOF
$SECRET_PATTERNS
EOF
  SECRET_HITS=$(printf '%s' "$SECRET_HITS" | grep . | awk -F' [(]' '!seen[$1]++')
  [ -n "$SECRET_HITS" ]
}

# Up to three hits, comma separated, safe for plain text and JSON.
secrets_summary() {
  local total list
  total=$(printf '%s\n' "$SECRET_HITS" | grep -c .)
  list=$(printf '%s\n' "$SECRET_HITS" | head -3 | tr '\n' ',' | sed 's/,$//; s/,/, /g')
  if [ "$total" -gt 3 ]; then
    list="$list (and $((total - 3)) more)"
  fi
  printf '%s' "$list" | LC_ALL=C tr -d '\000-\037\177-\377'
}

# Replace secret values with [REDACTED] in text passed on stdin.
redact() {
  if [ "$SECRET_SCAN" != on ]; then
    cat
    return
  fi
  local kind re script=""
  while IFS='|' read -r kind re; do
    [ -n "$re" ] && script="${script}s#${re}#[REDACTED]#g;"
  done <<EOF
$SECRET_PATTERNS
EOF
  sed -E "$script"
}

# Warn once per change: scan when there is no marker yet or a memory bank file
# changed after the last scan. Prints the user-facing warning, if any.
secret_warning() {
  local marker
  [ "$SECRET_SCAN" = on ] || return 0
  if marker=$(marker_path secrets) && [ -e "$marker" ] \
     && ! find ./memory-bank -name "*.md" -type f -newer "$marker" 2>/dev/null | grep -q .; then
    return 0
  fi
  if scan_secrets; then
    printf 'Possible secret in the memory bank: %s. Remove it before committing: memory bank files are usually shared in git and sent to the model.' \
      "$(secrets_summary)"
  fi
  mark_notified secrets
}

# --- Events ----------------------------------------------------------------------
run_stop() {
  # Re-entrant stop: Claude is already continuing because of a block.
  payload_true stop_hook_active && return 0
  resolve_root || return 0

  local secrets reminder="" block=""
  secrets=$(json_escape "$(secret_warning)")

  # Plan mode is read-only; asking Claude to write files there is pointless.
  if [ "$REMINDER_MODE" != off ] && ! payload_is permission_mode plan && is_stale; then
    if [ "$REMINDER_MODE" = strict ]; then
      block=$(printf 'Before finishing, update the memory bank to capture recent work.\\n\\n%s file(s) changed since the last memory bank update: %s\\n\\nPlease update:\\n%s\\n\\nOnce updated, you can stop.' \
        "$COUNT" "$(json_escape "$(files_summary)")" "$(update_targets '- ' '\n')")
    elif should_notify stop; then
      reminder=$(printf 'Memory bank may be out of date: %s file(s) changed since the last update. Say \\"update memory bank\\" to refresh it.' "$COUNT")
      mark_notified stop
    fi
  fi

  local message="$secrets"
  if [ -n "$reminder" ]; then
    message="${message:+$message\\n}$reminder"
  fi

  if [ -n "$block" ] && [ -n "$message" ]; then
    printf '{"decision":"block","reason":"%s","systemMessage":"%s"}\n' "$block" "$message"
  elif [ -n "$block" ]; then
    printf '{"decision":"block","reason":"%s"}\n' "$block"
  elif [ -n "$message" ]; then
    printf '{"systemMessage":"%s"}\n' "$message"
  fi
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

# Whole file as plain text, without control characters.
full_text() {
  tr -d '\000-\010\013-\037' < "$1" 2>/dev/null \
    | redact
}

secret_context_line() {
  scan_secrets || return 0
  printf 'Warning: possible secret in the memory bank: %s. Values are redacted here. Tell the user and offer to remove it; memory bank files are usually committed and shared.' \
    "$(secrets_summary)"
}

run_session_start() {
  [ "$LOAD_MODE" = off ] && return 0
  resolve_root || return 0
  pick_files

  if [ "$LOAD_MODE" = pointer ]; then
    local targets="" secret_line
    [ -n "$ACTIVE" ] && targets="$ACTIVE"
    [ -n "$BRIEF" ] && targets="${targets:+$targets and }$BRIEF"
    if [ -n "$targets" ]; then
      printf 'Memory bank: shared project state lives in memory-bank/. Read %s before substantial work.\n' "$targets"
    else
      printf 'Memory bank: memory-bank/ exists but has no core files yet. Say "initialize memory bank" to create them.\n'
    fi
    secret_line=$(secret_context_line)
    [ -n "$secret_line" ] && printf '%s\n' "$secret_line"
    return 0
  fi

  local out others lines secret_line
  out="# Memory bank (shared, git-tracked project state)
Loaded at session start. Other files in memory-bank/ are listed below."

  secret_line=$(secret_context_line)
  if [ -n "$secret_line" ]; then
    out="$out

$secret_line"
  fi

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
$(full_text "$BRIEF")"
  else
    out="$out

Missing: memory-bank/$( [ "$ACTIVE" = memory-bank/active.md ] && echo brief.md || echo projectbrief.md )."
  fi

  if [ -n "$ACTIVE" ]; then
    out="$out

## Current focus ($ACTIVE)
$(full_text "$ACTIVE")"
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

  printf '%s\n' "$out"
}

case "$EVENT" in
  stop) run_stop ;;
  prompt) run_prompt ;;
  session-start) run_session_start ;;
esac
exit 0
