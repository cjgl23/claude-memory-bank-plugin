# Claude Memory Bank Plugin

A Claude Code plugin that implements the [Memory Bank](https://docs.cline.bot/features/memory-bank) pattern — a set of structured markdown files that preserve project context across sessions, so Claude always knows where things stand without you having to re-explain.

## What it does

- **Initializes** a `memory-bank/` directory in your project with six structured files
- **Reads** all memory bank files at the start of every task (so Claude has full context)
- **Automatically reminds** Claude to update the memory bank after meaningful work via a Stop hook
- Works across any project or repository

## Memory bank files

| File | Purpose |
|------|---------|
| `projectbrief.md` | Core requirements, goals, and project scope |
| `productContext.md` | Why the project exists, problems it solves, UX goals |
| `activeContext.md` | Current focus, recent changes, next steps *(updated most often)* |
| `systemPatterns.md` | Architecture, design patterns, component relationships |
| `techContext.md` | Tech stack, setup instructions, dependencies |
| `progress.md` | What works, what remains, known issues |

## Installation (2 steps)

### Step 1 — Clone this repo as a Claude Code marketplace

```bash
# macOS / Linux
git clone https://github.com/cjgl23/claude-memory-bank-plugin.git \
  ~/.claude/plugins/marketplaces/cjgl23-claude-memory-bank-plugin
```

```bash
# Windows (Git Bash)
git clone https://github.com/cjgl23/claude-memory-bank-plugin.git \
  "C:/Users/<your-username>/.claude/plugins/marketplaces/cjgl23-claude-memory-bank-plugin"
```

### Step 2 — Enable the plugin

Add to `~/.claude/settings.json` (merge into your existing config):

```json
{
  "enabledPlugins": {
    "memory-bank@cjgl23-claude-memory-bank-plugin": true
  }
}
```

> **Note**: The plugin ID is `memory-bank@cjgl23-claude-memory-bank-plugin` — it matches the marketplace directory name.

### Step 3 — Restart Claude Code

Restart Claude Code for the plugin to be picked up.

## Usage

### Initialize a memory bank in a new project

```
initialize memory bank
```

Claude will explore the project, then create `memory-bank/` with all six files populated with real context.

### Start working in a project that already has a memory bank

Just start your task normally. Claude reads all memory bank files at the beginning of every task automatically.

### Update the memory bank manually

```
update memory bank
```

Claude reviews and refreshes all files. `activeContext.md` gets a full current-state snapshot; `progress.md` is updated with completed and remaining work.

### How the Stop hook works

After Claude finishes a task, the hook checks whether any project files were modified since the last memory bank update. If they were, Claude is asked to update `activeContext.md` and `progress.md` before stopping. Once updated, the hook exits silently and Claude stops normally.

## Updating the plugin

```bash
git -C ~/.claude/plugins/marketplaces/cjgl23-claude-memory-bank-plugin pull
```

Then restart Claude Code.
