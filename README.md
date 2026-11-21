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

- **Skills:**
  - `memory-bank`: reads the memory bank and handles natural-language requests ("update memory bank", "capture this rule", …).
  - Slash commands: `/memory-bank:init`, `/memory-bank:update`, `/memory-bank:consolidate`, `/memory-bank:migrate`.
- **Hooks** (`scripts/memory-bank-hook.sh`):
  - **SessionStart:** loads the full brief and active files, plus a list of other memory bank files.
  - **Stop / UserPromptSubmit:** detect when the memory bank is out of date, including renamed and deleted files, and remind you or Claude depending on the reminder mode.

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

| Command | What it does |
|---|---|
| `/memory-bank:init` | Create `memory-bank/brief.md` and `memory-bank/active.md` for this project |
| `/memory-bank:update` | Update the memory bank after work (incremental) |
| `/memory-bank:consolidate` | Trim and de-duplicate when files grow long or stale |
| `/memory-bank:migrate` | Convert a classic six-file bank to the standard layout, with a preview first |

Natural language works too: `initialize memory bank`, `update memory bank`, `read memory bank`, `consolidate memory bank`, `migrate memory bank`, and `capture this rule` (proposes adding a rule to `CLAUDE.md` or `.claude/rules/`).

## Memory Bank Layout

| File | Contents |
|---|---|
| `memory-bank/brief.md` | Project, goal and scope, architecture and tech that aren't obvious from the code, optional end-state vision and glossary. Changes rarely. |
| `memory-bank/active.md` | Current focus (first), next steps, status, known issues, recent changes. A snapshot, not a log. |
| `memory-bank/decisions.md` | Optional. Dated, hard-to-reverse decisions with reasons. |

Other Markdown files in `memory-bank/` are topic notes that Claude reads on demand. `memory-bank/archive/` is ignored.

**Classic layout:** banks created before 1.0 use six files (`projectbrief.md`, `productContext.md`, `systemPatterns.md`, `techContext.md`, `activeContext.md`, `progress.md`). They keep working without changes.

Never put credentials, tokens, or personal data in these files. They are usually committed and are sent to the model as context.

## Expected Behavior

- **Session start:** if `memory-bank/` exists, a summary is added to Claude's context. Claude reads full files only when the task needs them.
- **Out-of-date detection:** the memory bank counts as out of date when project files changed after the active file (`active.md`, or `activeContext.md` / `progress.md` in a classic bank) was last updated. In git repositories, renamed and deleted files count too. Git-ignored files and generated folders (`node_modules`, `.venv`, `__pycache__`, …) don't count.
- **Parallel sessions:** sessions on the same branch share one active file. Keep updates small, and prefer one writer per branch.
- **Reminders** depend on the reminder mode (below). They stay quiet in plan mode, and the hooks find the project root even when Claude starts in a subdirectory.

## Settings

Claude Code asks for these when you enable the plugin. Empty or unknown values use the default.

| Setting | Options | Default | What it does |
|---|---|---|---|
| `reminder_mode` | `nudge`, `strict`, `off` | `nudge` | **nudge:** shows you a one-line notice at the end of a turn and adds a note for Claude on your next prompt, once per session until the bank is updated. Never blocks. **strict:** blocks Claude once at the end of a turn so it updates the bank (the behavior before 0.3.0). **off:** no reminders. |
| `min_changed_files` | number ≥ 1 | `1` | How many changed files make the bank count as out of date. |
| `load_mode` | `summary`, `pointer`, `off` | `summary` | What to load at session start: the full brief and active files, a one-line pointer, or nothing. |
| `secret_scan` | `true`, `false` | `true` | Warn when memory bank files look like they contain a credential. See below. |

To turn the plugin off for one project only, disable it in that project's Claude Code settings (`/plugin`, or `enabledPlugins` in `.claude/settings.json`).

Prefer native features only? Instead of the session-start hook, you can add `@memory-bank/active.md` (or `@memory-bank/activeContext.md` in a classic bank) to your `CLAUDE.md`, which loads the whole file every session.

## Secret Warnings

Memory bank files are usually committed and are sent to the model, so they should never hold credentials. The plugin checks `memory-bank/` (including `archive/`) for common, high-confidence formats: private keys, AWS access keys, GitHub, Anthropic, OpenAI, Slack, Google and Stripe keys, and passwords inside URLs such as `postgres://user:pass@host`. Placeholders like `user:<password>@` or `user:${DB_PASS}@` are ignored.

- **At the end of a turn,** after memory bank files change, you see a one-line warning with the file, line, and kind of secret.
- **At session start,** matching values are replaced with `[REDACTED]` in the summary, and Claude is told to point the problem out.
- It only warns, never blocks, and **never shows the secret value**. It is not a full secret scanner; keep using your usual tools (for example, GitHub secret scanning or pre-commit hooks).

Set `secret_scan` to `false` to turn it off.

## Upgrading to 1.0

Nothing changes for existing banks: classic six-file banks are read and updated as before. To switch to the two-file layout, run `/memory-bank:migrate`. It shows the new files before writing anything, then moves the classic files to `memory-bank/archive/`. Nothing is deleted, and you can review everything with `git diff` before committing.

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
