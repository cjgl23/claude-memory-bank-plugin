---
name: memory-bank
description: Initialize, read, and maintain a structured Memory Bank — a set of markdown files in a memory-bank/ directory that preserve project context across sessions. Use this skill whenever the user says "initialize memory bank", "update memory bank", or starts working in a project that already has a memory-bank/ directory. Also use it proactively at the start of any task if a memory-bank/ directory exists in the current project root, since reading those files is required to understand project context. Trigger on any phrasing like "set up memory bank", "create memory bank", "read memory bank", "check memory bank", or "follow your custom instructions" when a memory-bank/ exists.
---

# Memory Bank

My memory resets completely between sessions. The Memory Bank is the only link to previous work. It must be read at the start of every task and maintained with precision and clarity — my effectiveness depends entirely on its accuracy.

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

### At the Start of Every Task

If `memory-bank/` exists in the project root, read ALL core files before doing anything else. This is not optional. Build a complete picture of the project before proceeding.

1. Read `memory-bank/projectbrief.md`
2. Read `memory-bank/productContext.md`
3. Read `memory-bank/systemPatterns.md`
4. Read `memory-bank/techContext.md`
5. Read `memory-bank/progress.md`
6. Read `memory-bank/activeContext.md` (last, as it reflects the most current state)

If any file is missing, note it — don't fail silently. Read any additional files present in the directory.

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
[How the project direction has evolved]
```

5. After creating all files, confirm to the user what was created and give a brief summary of what was captured.

---

### Update Memory Bank

Triggered by: "update memory bank" (MUST review ALL files), or proactively when:
- Discovering new project patterns
- After implementing significant changes
- When context needs clarification
- At natural session checkpoints

**Update process:**

1. Read ALL current memory bank files first to understand what's already there.
2. Review what has changed or been learned in this session.
3. Update each file that needs changes:
   - `activeContext.md` — Almost always needs updating. Reflect the current focus, recent changes, and next steps.
   - `progress.md` — Update completed work, remaining tasks, and known issues.
   - `systemPatterns.md` — Update if new patterns were established or architecture changed.
   - `techContext.md` — Update if dependencies changed or new tools were adopted.
   - `productContext.md` / `projectbrief.md` — Update only if scope or goals shifted.
4. Keep files concise — aim for one page each. If a file is growing too long, split it into a focused sub-file in `memory-bank/` and link to it.
5. Confirm what was updated.

**Key principle for `activeContext.md`:** This file reflects *current state only* — not a running log. Overwrite old entries rather than appending. It should read like a snapshot of where things are right now.

---

## File Maintenance Guidelines

- Keep each core file to roughly one page where possible.
- Prefer overwriting stale information over appending to it.
- When a file grows too large, create a sub-file in `memory-bank/` (e.g., `memory-bank/api-specs.md`) and add a reference in the relevant core file.
- Write for a reader who has never seen the project before — full sentences, not cryptic abbreviations.
- After every significant session, update `activeContext.md` at minimum.
