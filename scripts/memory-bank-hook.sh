#!/bin/bash
# Memory Bank Update Reminder
#
# Runs as a Stop hook. Checks whether any project files have been modified
# since the last memory bank update. If so, blocks Claude from finishing
# and asks it to update activeContext.md and progress.md first.
#
# Logic:
#   1. If no memory-bank/ directory exists, exit silently (not a memory-bank project).
#   2. Find the most recently modified file in memory-bank/.
#   3. Find any project source files newer than that file.
#   4. If newer files exist, output a block decision with a targeted reminder.
#   5. After Claude updates the memory bank, the memory bank files will be the
#      newest, so the hook won't fire again on the next stop.

if [ ! -d "./memory-bank" ]; then
  exit 0
fi

# Find the most recently touched memory bank file
LATEST_MB=$(find ./memory-bank -name "*.md" -type f -print0 2>/dev/null \
  | xargs -0 ls -t 2>/dev/null \
  | head -1)

if [ -z "$LATEST_MB" ]; then
  exit 0
fi

# Find project files newer than the latest memory bank update,
# excluding noise directories
NEWER_FILES=$(find . \
  -not -path "./.git/*" \
  -not -path "./memory-bank/*" \
  -not -path "./node_modules/*" \
  -not -path "./.next/*" \
  -not -path "./dist/*" \
  -not -path "./build/*" \
  -not -path "./.cache/*" \
  -not -path "./.claude/*" \
  -newer "$LATEST_MB" \
  -type f \
  2>/dev/null | head -5)

if [ -n "$NEWER_FILES" ]; then
  FILES_LIST=$(echo "$NEWER_FILES" | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
  # Escape characters that would otherwise produce invalid JSON (backslash first, then double-quote)
  FILES_LIST=$(printf '%s' "$FILES_LIST" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf '{"decision":"block","reason":"Before finishing, update the memory bank to capture recent work.\\n\\nFiles changed since last memory bank update: %s\\n\\nPlease update:\\n- memory-bank/activeContext.md: current focus, recent changes, next steps\\n- memory-bank/progress.md: what was completed, what remains, known issues\\n\\nOnce updated, you can stop."}\n' "$FILES_LIST"
fi
