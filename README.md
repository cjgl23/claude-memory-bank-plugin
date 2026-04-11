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

## Installation

### Step 1 — Clone the plugin into your Claude cache

```bash
git clone https://github.com/cjgl23/claude-memory-bank-plugin.git \
  ~/.claude/plugins/cache/cjgl23/claude-memory-bank-plugin/latest
```

> On Windows (Git Bash):
> ```bash
> git clone https://github.com/cjgl23/claude-memory-bank-plugin.git \
>   "C:/Users/<your-username>/.claude/plugins/cache/cjgl23/claude-memory-bank-plugin/latest"
> ```

### Step 2 — Register the plugin

Add this entry to `~/.claude/plugins/installed_plugins.json` inside the `"plugins"` object:

```json
"claude-memory-bank-plugin@cjgl23": [
  {
    "scope": "user",
    "installPath": "/home/<your-username>/.claude/plugins/cache/cjgl23/claude-memory-bank-plugin/latest",
    "version": "latest",
    "installedAt": "2026-01-01T00:00:00.000Z",
    "lastUpdated": "2026-01-01T00:00:00.000Z",
    "gitCommitSha": "05092a1c81a5ad901b927327f4517ec432ca941a"
  }
]
```

> On Windows use `C:\\Users\\<your-username>\\...` with double backslashes.

### Step 3 — Enable the plugin

Add to `~/.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "claude-memory-bank-plugin@cjgl23": true
  }
}
```

### Step 4 — Add the Stop hook

Add this to the `"hooks"` section of `~/.claude/settings.json` to get automatic reminders to update the memory bank after meaningful work:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"/home/<your-username>/.claude/plugins/cache/cjgl23/claude-memory-bank-plugin/latest/scripts/memory-bank-hook.sh\""
          }
        ]
      }
    ]
  }
}
```

> On Windows replace the path with `C:/Users/<your-username>/...` (forward slashes are fine in bash commands).

### Step 5 — Restart Claude Code

Restart Claude Code for the plugin and hook to take effect.

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

After Claude finishes a task, the hook checks whether any project files were modified since the last memory bank update. If they were, Claude is asked to update `activeContext.md` and `progress.md` before stopping. Once updated, the hook exits silently and Claude stops normally — no infinite loop.

## Updating the plugin

To pull the latest version:

```bash
cd ~/.claude/plugins/cache/cjgl23/claude-memory-bank-plugin/latest
git pull
```

Then restart Claude Code.
