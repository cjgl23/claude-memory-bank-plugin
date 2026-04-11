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

### Step 1 — Clone this repo as a marketplace

```bash
# macOS / Linux
git clone https://github.com/cjgl23/claude-memory-bank-plugin.git \
  ~/.claude/plugins/marketplaces/cjgl23
```

```bash
# Windows (Git Bash)
git clone https://github.com/cjgl23/claude-memory-bank-plugin.git \
  "C:/Users/<your-username>/.claude/plugins/marketplaces/cjgl23"
```

### Step 2 — Cache the plugin

Copy the plugin subdirectory into the versioned cache. Replace `<sha>` with the current commit SHA (run `git rev-parse HEAD` inside the cloned folder):

```bash
# macOS / Linux
SHA=$(git -C ~/.claude/plugins/marketplaces/cjgl23 rev-parse HEAD)
mkdir -p ~/.claude/plugins/cache/cjgl23/memory-bank/$SHA
cp -r ~/.claude/plugins/marketplaces/cjgl23/plugins/memory-bank/. \
  ~/.claude/plugins/cache/cjgl23/memory-bank/$SHA/
```

```bash
# Windows (Git Bash)
SHA=$(git -C "C:/Users/<your-username>/.claude/plugins/marketplaces/cjgl23" rev-parse HEAD)
mkdir -p "C:/Users/<your-username>/.claude/plugins/cache/cjgl23/memory-bank/$SHA"
cp -r "C:/Users/<your-username>/.claude/plugins/marketplaces/cjgl23/plugins/memory-bank/." \
  "C:/Users/<your-username>/.claude/plugins/cache/cjgl23/memory-bank/$SHA/"
```

### Step 3 — Register the marketplace

Add to `~/.claude/plugins/known_marketplaces.json` (merge into the existing JSON object):

```json
{
  "cjgl23": {
    "source": {
      "source": "github",
      "repo": "cjgl23/claude-memory-bank-plugin"
    },
    "installLocation": "/home/<your-username>/.claude/plugins/marketplaces/cjgl23",
    "lastUpdated": "2026-01-01T00:00:00.000Z"
  }
}
```

> On Windows use `C:\\Users\\<your-username>\\...` with double backslashes for `installLocation`.

### Step 4 — Register the plugin

Add to `~/.claude/plugins/installed_plugins.json` inside the `"plugins"` object, replacing `<sha>` with your commit SHA from Step 2:

```json
"memory-bank@cjgl23": [
  {
    "scope": "user",
    "installPath": "/home/<your-username>/.claude/plugins/cache/cjgl23/memory-bank/<sha>",
    "version": "<sha>",
    "installedAt": "2026-01-01T00:00:00.000Z",
    "lastUpdated": "2026-01-01T00:00:00.000Z",
    "gitCommitSha": "<sha>"
  }
]
```

> On Windows use `C:\\Users\\<your-username>\\...` with double backslashes.

### Step 5 — Enable the plugin and add the Stop hook

Add to `~/.claude/settings.json` (merge into your existing config):

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"/home/<your-username>/.claude/plugins/cache/cjgl23/memory-bank/<sha>/scripts/memory-bank-hook.sh\""
          }
        ]
      }
    ]
  },
  "enabledPlugins": {
    "memory-bank@cjgl23": true
  }
}
```

> On Windows use forward slashes in the bash command path: `C:/Users/<your-username>/...`

### Step 6 — Restart Claude Code

Restart Claude Code, then run `/reload-plugins` to verify it loads without errors.

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
# Pull latest
git -C ~/.claude/plugins/marketplaces/cjgl23 pull

# Re-cache with new SHA
SHA=$(git -C ~/.claude/plugins/marketplaces/cjgl23 rev-parse HEAD)
mkdir -p ~/.claude/plugins/cache/cjgl23/memory-bank/$SHA
cp -r ~/.claude/plugins/marketplaces/cjgl23/plugins/memory-bank/. \
  ~/.claude/plugins/cache/cjgl23/memory-bank/$SHA/
```

Then update `installPath`, `version`, `gitCommitSha` in `installed_plugins.json` and the hook path in `settings.json` to the new SHA, and restart Claude Code.
