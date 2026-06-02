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

Install from the Claude community marketplace. Run these commands inside Claude Code:

```text
/plugin marketplace add anthropics/claude-plugins-community
/plugin marketplace update claude-community
/plugin install memory-bank@claude-community
/reload-plugins
```

## Usage

After installation, initialize the memory bank with the slash command:

```text
/memory-bank initialize memory bank for this project
```

Or use natural language:

```text
initialize memory bank
```

Other useful prompts:
- `update memory bank`
- `read memory bank`

## Created Project Files

Initializing the memory bank creates a `memory-bank/` directory at your project
root with the following files:

```text
memory-bank/projectbrief.md
memory-bank/productContext.md
memory-bank/activeContext.md
memory-bank/systemPatterns.md
memory-bank/techContext.md
memory-bank/progress.md
```

## Expected Behavior

- If `memory-bank/` exists, the skill reads it at task start.
- On stop, if project files changed after the latest memory bank update, the hook asks you to update:
  - `memory-bank/activeContext.md`
  - `memory-bank/progress.md`

## Privacy

View our [privacy policy](PRIVACY.md) to learn how we handle your data.

## Disable or Remove

```text
/plugin disable memory-bank@claude-community
/plugin uninstall memory-bank@claude-community
```
