# Claude Memory Bank Plugin

`memory-bank` is a Claude Code plugin that keeps shared project context in a `memory-bank/` directory of Markdown files committed alongside your code.

It is designed to:
- Initialize a standard set of memory bank docs for a project.
- Keep context current as work evolves.
- Remind Claude to update the memory bank when project files changed but the memory bank has not.

## How It Relates to Claude Code's Native Memory

Claude Code already has `CLAUDE.md` (instructions that load every session) and auto memory (notes Claude keeps for you on one machine). The Memory Bank adds **shared, git-tracked project state**: scope, architecture, current focus, and progress that teammates, other machines, and pull request reviewers can all see.

| Information | Best place |
|---|---|
| Rules and commands for Claude | `CLAUDE.md` / `.claude/rules/` |
| Your personal preferences | Auto memory |
| Shared project state and progress | `memory-bank/` |

## What This Plugin Includes

- A `memory-bank` skill that can initialize, read, and update memory bank files.
- A Stop hook (`scripts/memory-bank-hook.sh`) that checks whether the memory bank is stale relative to recent project changes.

## Install with Claude Code `/plugin`

Install from the Claude community marketplace. Run these commands inside Claude Code:

```text
/plugin marketplace add anthropics/claude-plugins-community
/plugin marketplace update claude-community
/plugin install memory-bank@claude-community
/reload-plugins
```

On Windows, the hook needs [Git for Windows](https://git-scm.com/download/win) (Git Bash).

## Usage

Initialize the memory bank with the slash command:

```text
/memory-bank:memory-bank initialize memory bank for this project
```

Or use natural language:

```text
initialize memory bank
```

Other useful prompts:
- `update memory bank`
- `read memory bank`

## Created Project Files

Initializing the memory bank creates a `memory-bank/` directory at your project root with the following files:

```text
memory-bank/projectbrief.md
memory-bank/productContext.md
memory-bank/activeContext.md
memory-bank/systemPatterns.md
memory-bank/techContext.md
memory-bank/progress.md
```

Never put credentials, tokens, or personal data in these files. They are usually committed and are sent to the model as context.

## Expected Behavior

- If `memory-bank/` exists, the skill reads it at task start.
- At the end of each Claude turn, the hook checks whether project files changed after `activeContext.md` or `progress.md` was last updated. If so, it asks Claude to update:
  - `memory-bank/activeContext.md`
  - `memory-bank/progress.md`
- The hook ignores git-ignored files and generated folders such as `node_modules`, `.venv` and `__pycache__`. It finds the project root even when Claude starts in a subdirectory, stays quiet in plan mode, and never asks twice in a row.

## Privacy

The plugin runs no network code. Memory bank content enters Claude's context like any other file Claude reads. See the [privacy policy](PRIVACY.md) for details.

## Disable or Remove

```text
/plugin disable memory-bank@claude-community
/plugin uninstall memory-bank@claude-community
```

Uninstalling does not delete `memory-bank/` folders in your projects. Delete them yourself if you no longer want them.

## Development

```bash
python3 -m unittest discover -s tests -v
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and [CHANGELOG.md](CHANGELOG.md).
