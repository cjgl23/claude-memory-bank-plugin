---
name: memory-bank
description: Read and maintain the shared memory-bank/ folder (project brief, current focus, decisions). Use when the user says "initialize memory bank", "update memory bank", "read memory bank", "consolidate memory bank", "migrate memory bank", or "capture this rule", when a memory bank reminder appears, or when project context from memory-bank/ is needed.
---

# Memory Bank

Each session starts with a fresh context window. Claude Code's native memory (CLAUDE.md and auto memory) carries instructions and personal notes across sessions, but auto memory stays on one machine. The Memory Bank holds **shared, git-tracked project state** (scope, architecture, current focus, progress, decisions) that every teammate, machine, and session can read and review. A hook loads a short summary of it at session start; keep it accurate so that summary stays useful.

## What Goes Where

| Information | Where it belongs |
|---|---|
| Rules, commands, and "do not do" instructions for Claude | `CLAUDE.md` or `.claude/rules/` (always loaded). Ask the user before adding to them. |
| Personal preferences and machine-specific notes | Claude Code auto memory |
| Shared project state: scope, architecture, decisions, current focus, progress | `memory-bank/` |

Don't copy content that already lives in `CLAUDE.md` or is obvious from the code. If a request conflicts with a decision recorded in the Memory Bank, point out the conflict before acting.

## Never Store

Memory Bank files are usually committed to git and are sent to the model as context. Never write credentials, API keys, tokens, passwords, connection strings, private keys, personal data, or customer data into them. Refer to where a secret is kept (for example, "the API key is in the team vault") instead of the value.

## Layouts

**Standard layout (1.0+):**
- `memory-bank/brief.md`: project, goal, scope, architecture and tech that aren't obvious from the code, optional end-state vision and glossary. Changes rarely.
- `memory-bank/active.md`: current focus (first), next steps, status, known issues, recent changes. Changes often; a snapshot, not a log.
- `memory-bank/decisions.md` (optional): dated decisions with reasons.

**Classic layout (six files):** `projectbrief.md`, `productContext.md`, `systemPatterns.md`, `techContext.md`, `activeContext.md`, `progress.md`. Still fully supported. In a classic bank, "active" means `activeContext.md` plus `progress.md`, and "brief" means `projectbrief.md` plus the other three. Never convert a classic bank unless the user asks (see Migrate).

Other files in `memory-bank/` are topic notes to read on demand. Ignore `memory-bank/archive/`.

## At the Start of a Task

The plugin's SessionStart hook puts a summary of the memory bank in context (headed "Memory bank (shared, git-tracked project state)"), including after compaction.

- **If that summary is in context:** use it. Read full files only when the task needs them, for example planning, architecture changes, or work in an unfamiliar area.
- **If no summary is in context** (loading turned off, or the user asked to "read memory bank"): read the active file first, then the brief, then other files only as needed.
- If a core file is missing, say so rather than failing silently.

## Workflows

Read the matching workflow file in this skill's folder (`${CLAUDE_SKILL_DIR}/workflows/`) and follow it:

| When the user says… | Workflow file |
|---|---|
| "initialize memory bank", "set up memory bank", "create memory bank" | `workflows/init.md` |
| "update memory bank", or a memory bank reminder appears | `workflows/update.md` |
| "consolidate memory bank", "clean up memory bank", or the summary says the active file is too long | `workflows/consolidate.md` |
| "migrate memory bank", "convert memory bank to the new layout" | `workflows/migrate.md` |
| "capture this rule", "remember to always…", "don't ever…", or the user corrects a pattern they don't want repeated | `workflows/capture-rule.md` |

File templates are in `templates/`. The same workflows are available as slash commands: `/memory-bank:init`, `/memory-bank:update`, `/memory-bank:consolidate`, `/memory-bank:migrate`.
