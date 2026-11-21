# Claude Memory Bank Plugin

`memory-bank` is a Claude Code plugin that keeps shared project context in a `memory-bank/` directory of Markdown files committed alongside your code.

It is designed to:
- Initialize a standard set of memory bank docs for a project.
- Load a short summary of the memory bank at the start of every session (and after compaction).
- Remind you, without interrupting, when project files changed but the memory bank has not.

## How It Relates to Claude Code's Native Memory

Claude Code already has `CLAUDE.md` (instructions that load every session) and auto memory (notes Claude keeps for you on one machine). The Memory Bank adds **shared, git-tracked project state**: scope, architecture, current focus, and progress that teammates, other machines, and pull request reviewers can all see.

| Information | Best place |
|---|---|
| Rules and commands for Claude | `CLAUDE.md` / `.claude/rules/` |
| Your personal preferences | Auto memory |
| Shared project state and progress | `memory-bank/` |

## What This Plugin Includes

- A `memory-bank` skill that can initialize, read, update, and consolidate memory bank files, and route "capture this rule" requests to `CLAUDE.md`.
- Hooks (`scripts/memory-bank-hook.sh`):
  - **SessionStart:** loads a summary of up to 2,000 characters (the brief, the current focus, and a list of other files).
  - **Stop / UserPromptSubmit:** detect when the memory bank is out of date and remind you or Claude, depending on the reminder mode.

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
- `update memory bank`: incremental update of `activeContext.md` and `progress.md`
- `read memory bank`
- `consolidate memory bank`: trim and de-duplicate when files grow
- `capture this rule`: propose adding a rule to `CLAUDE.md` or `.claude/rules/`

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

- **Session start:** if `memory-bank/` exists, a summary is added to Claude's context. Claude reads full files only when the task needs them.
- **Out-of-date detection:** the memory bank counts as out of date when project files changed after `activeContext.md` or `progress.md` was last updated. Git-ignored files and generated folders (`node_modules`, `.venv`, `__pycache__`, …) don't count.
- **Reminders** depend on the reminder mode (below). They stay quiet in plan mode, and the hooks find the project root even when Claude starts in a subdirectory.

## Settings

Claude Code asks for these when you enable the plugin. Empty or unknown values use the default.

| Setting | Options | Default | What it does |
|---|---|---|---|
| `reminder_mode` | `nudge`, `strict`, `off` | `nudge` | **nudge:** shows you a one-line notice at the end of a turn and adds a note for Claude on your next prompt, once per session until the bank is updated. Never blocks. **strict:** blocks Claude once at the end of a turn so it updates the bank (the behavior before 0.3.0). **off:** no reminders. |
| `min_changed_files` | number ≥ 1 | `1` | How many changed files make the bank count as out of date. |
| `load_mode` | `summary`, `pointer`, `off` | `summary` | What to load at session start: a summary of up to 2,000 characters, a one-line pointer, or nothing. |

To turn the plugin off for one project only, disable it in that project's Claude Code settings (`/plugin`, or `enabledPlugins` in `.claude/settings.json`).

Prefer native features only? Instead of the session-start hook, you can add `@memory-bank/activeContext.md` to your `CLAUDE.md`, which loads the whole file every session.

## Privacy

The plugin runs no network code. Memory bank content enters Claude's context like any other file Claude reads. See the [privacy policy](PRIVACY.md) for details.

## Disable or Remove

```text
/plugin disable memory-bank@claude-community
/plugin uninstall memory-bank@claude-community
```

Uninstalling does not delete `memory-bank/` folders in your projects. Delete them yourself if you no longer want them. The plugin's reminder markers in Claude Code's plugin data folder are removed with the plugin.

## Development

```bash
python3 -m unittest discover -s tests -v
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and [CHANGELOG.md](CHANGELOG.md).
