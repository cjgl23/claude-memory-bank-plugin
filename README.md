# Claude Memory Bank Plugin

`memory-bank` is a Claude Code plugin that helps maintain project context across sessions by keeping a structured `memory-bank/` directory of Markdown files.

It is designed to:
- Initialize a standard set of memory bank docs for a project.
- Keep context current as work evolves.
- Remind/block stopping when project files changed but the memory bank has not been updated.

## What This Plugin Includes

- A `memory-bank` skill that can initialize, read, and update memory bank files.
- A stop hook (`scripts/memory-bank-hook.sh`) that checks whether `memory-bank/*.md` is stale relative to recent project changes.

## Install with Claude Code `/plugin`

Run these commands inside Claude Code:

```text
/plugin marketplace add cjgl23/claude-memory-bank-plugin
/plugin install memory-bank@cjgl23
```

Optional: install to project scope (shared in repo settings) instead of default user scope:

```text
/plugin install memory-bank@cjgl23 --scope project
```

## Basic Usage

After installation, use prompts like:
- `initialize memory bank`
- `update memory bank`
- `read memory bank`

Expected behavior:
- If `memory-bank/` exists, the skill reads it at task start.
- On stop, if project files changed after the latest memory bank update, the hook asks you to update:
  - `memory-bank/activeContext.md`
  - `memory-bank/progress.md`

## Disable or Remove

```text
/plugin disable memory-bank@cjgl23
/plugin uninstall memory-bank@cjgl23
```
