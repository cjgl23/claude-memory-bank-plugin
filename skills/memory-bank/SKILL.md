---
name: memory-bank
description: Initialize, read, and update the shared memory-bank/ folder of Markdown files that records project scope, architecture, current focus, and progress. Use when the user says "initialize memory bank", "update memory bank", "read memory bank", "consolidate memory bank", or "capture this rule", or when a memory-bank/ directory exists at the project root and project context is needed.
---

# Memory Bank

Each session starts with a fresh context window. Claude Code's native memory (CLAUDE.md and auto memory) carries instructions and personal notes across sessions, but auto memory stays on one machine. The Memory Bank holds **shared, git-tracked project state** — scope, architecture, current focus, and progress — that every teammate, machine, and session can read and review. A hook loads a short summary of it at session start; keep it accurate so that summary stays useful.

## What Goes Where

| Information | Where it belongs |
|---|---|
| Rules, commands, and "do not do" instructions for Claude | `CLAUDE.md` or `.claude/rules/` (always loaded). Ask the user before adding to them. |
| Personal preferences and machine-specific notes | Claude Code auto memory |
| Shared project state: scope, architecture, decisions, current focus, progress | `memory-bank/` |

Don't copy content that already lives in `CLAUDE.md` or is obvious from the code. If a request conflicts with a decision recorded in the Memory Bank, point out the conflict before acting.

## Never Store

Memory Bank files are usually committed to git and are sent to the model as context. Never write credentials, API keys, tokens, passwords, connection strings, private keys, personal data, or customer data into them. Refer to where a secret is kept (for example, "the API key is in the team vault") instead of the value.

## Memory Bank Structure

All files live in `memory-bank/` at the project root, in Markdown format:

### Core Files (Required)
1. **`projectbrief.md`** — Foundation document. Core requirements and goals. Source of truth for project scope. Created at project start.
2. **`productContext.md`** — Why this project exists. Problems it solves. How it should work. User experience goals.
3. **`activeContext.md`** — Current work focus. Recent changes. Next steps. Active decisions. Important patterns and preferences. Learnings and insights. *(Most frequently updated)*
4. **`systemPatterns.md`** — System architecture. Key technical decisions. Design patterns in use. Component relationships. Critical implementation paths.
5. **`techContext.md`** — Technologies used. Development setup. Technical constraints. Dependencies. Tool usage patterns.
6. **`progress.md`** — What works. What's left to build. Current status. Known issues. Evolution of project decisions.

### Additional Context
Create additional files/folders within `memory-bank/` as needed to organize: complex feature docs, integration specs, API documentation, testing strategies, deployment procedures.

---

## Workflows

### At the Start of a Task

The plugin's SessionStart hook puts a summary of the memory bank in context (headed "Memory bank (shared, git-tracked project state)"), including after compaction.

- **If that summary is in context:** use it. Read full files only when the task needs them — for example planning, architecture changes, or work in an unfamiliar area. Pick the file that matches the need (`systemPatterns.md` for architecture, `techContext.md` for setup and dependencies, `progress.md` for status and known issues).
- **If no summary is in context** (loading turned off, or the user asked to "read memory bank"): read `memory-bank/activeContext.md` and `memory-bank/projectbrief.md` first, then other files only as needed.
- If a core file is missing, say so rather than failing silently.
- If a request conflicts with a decision recorded in the memory bank, point out the conflict before acting.

---

### Initialize Memory Bank

Triggered by: "initialize memory bank", "set up memory bank", "create memory bank"

1. Check if `memory-bank/` already exists. If it does and files are present, confirm with the user before overwriting.
2. Create the `memory-bank/` directory.
3. Explore the current project — read existing code, config files, README, package.json, etc. — to gather context for populating the files meaningfully. Don't create empty stubs if you can derive real content.
4. Create all six core files with content appropriate to the project. For a brand-new project with no existing code, create sensible placeholders based on what the user has described.

**Template for each file:**

`projectbrief.md`:
```markdown
# Project Brief

## Project Name
[Name]

## End-State Vision (optional)
[Where the project is heading long-term, so today's design does not block it]

## Glossary (optional)
| Term | Meaning | Code identifier | Avoid saying |
|---|---|---|---|
| [Term] | [Definition] | [`identifier`] | [synonyms not to use] |

## Core Goal
[What this project is trying to accomplish]

## Key Requirements
- [Requirement 1]
- [Requirement 2]

## Scope
[What's in scope / out of scope]
```

`productContext.md`:
```markdown
# Product Context

## Why This Project Exists
[The problem being solved]

## How It Should Work
[High-level description of the intended behavior]

## User Experience Goals
[What the experience should feel like for users]
```

`activeContext.md`:
```markdown
# Active Context

## Current Focus
[What is being worked on right now]

## Recent Changes
[What has changed recently]

## Next Steps
[Immediate next actions]

## Active Decisions & Considerations
[Open questions, trade-offs being weighed]

## Important Patterns & Preferences
[Patterns established so far that should be followed]

## Learnings & Insights
[Things discovered during development]
```

`systemPatterns.md`:
```markdown
# System Patterns

## Architecture Overview
[High-level architecture description]

## Key Technical Decisions
[Important decisions and their rationale]

## Design Patterns in Use
[Patterns being applied and where]

## Component Relationships
[How major parts connect]

## Critical Implementation Paths
[Important flows through the system]
```

`techContext.md`:
```markdown
# Tech Context

## Technologies Used
[Languages, frameworks, libraries]

## Development Setup
[How to get the project running]

## Technical Constraints
[Limitations, requirements, boundaries]

## Dependencies
[Key external dependencies]

## Tool Usage Patterns
[How tools and scripts are used]
```

`progress.md`:
```markdown
# Progress

## What Works
[Completed and functioning features]

## What's Left to Build
[Remaining work]

## Current Status
[Overall project status]

## Known Issues
[Bugs, problems, tech debt]

## Decision History
- [YYYY-MM-DD] [Decision] | Why: [reason] | Trade-off: [what was given up]
```

5. After creating all files, confirm to the user what was created and give a brief summary of what was captured.

---

### Update Memory Bank

Triggered by: "update memory bank", a memory bank reminder from the plugin's hooks, or proactively when:
- Discovering new project patterns
- After implementing significant changes
- When context needs clarification
- At natural session checkpoints

**Update process (incremental):**

1. Read `activeContext.md` and `progress.md`. Read other files only if this session changed what they describe.
2. Review what has changed or been learned in this session.
3. Update only the files that need changes:
   - `activeContext.md` — Almost always needs updating. Reflect the current focus, recent changes, and next steps.
   - `progress.md` — Update completed work, remaining tasks, and known issues.
   - `systemPatterns.md` — Update if new patterns were established or architecture changed.
   - `techContext.md` — Update if dependencies changed or new tools were adopted.
   - `productContext.md` / `projectbrief.md` — Update only if scope or goals shifted.
4. Keep files concise — aim for one page each. If a file is growing too long, split it into a focused sub-file in `memory-bank/` and link to it.
5. Confirm what was updated.

**Key principle for `activeContext.md`:** This file reflects *current state only* — not a running log. Overwrite old entries rather than appending. It should read like a snapshot of where things are right now. Its opening lines are what the session-start summary shows, so put the current focus first.

---

### Consolidate Memory Bank

Triggered by: "consolidate memory bank", "clean up memory bank", or when the session-start summary says `activeContext.md` is too long.

1. Read all memory bank files.
2. Trim `activeContext.md` to the current state: move finished items to `progress.md`, and delete entries that are no longer true.
3. Remove content duplicated between files or already in `CLAUDE.md`. Keep each fact in one place.
4. Date any undated decisions in `progress.md` → Decision History.
5. Summarize what was removed or moved, so the user can review the diff.

---

### Capture a Rule

Triggered by: "capture this rule", "remember to always…", "don't ever…", or the user correcting a pattern they don't want repeated.

1. Rules for how Claude should work belong in `CLAUDE.md` or `.claude/rules/`, which load every session — not in the memory bank.
2. Propose the exact wording and the file. Ask before writing; these files are shared with the team.
3. If the rule is a project decision rather than an instruction (for example, "we chose Postgres over MySQL"), record it in `progress.md` → Decision History instead.

---

## File Maintenance Guidelines

- Keep each core file to roughly one page where possible.
- Prefer overwriting stale information over appending to it.
- When a file grows too large, create a sub-file in `memory-bank/` (e.g., `memory-bank/api-specs.md`) and add a reference in the relevant core file.
- Write for a reader who has never seen the project before — full sentences, not cryptic abbreviations.
- After every significant session, update `activeContext.md` at minimum.
