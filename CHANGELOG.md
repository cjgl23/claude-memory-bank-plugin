# Changelog

All notable changes to this plugin are documented here. The project uses
[Semantic Versioning](https://semver.org/).

## [1.1.0] - 2026-11-21

### Added
- **Secret warnings.** The hooks check `memory-bank/` for common credential
  formats (private keys; AWS, GitHub, Anthropic, OpenAI, Slack, Google and Stripe
  keys; passwords in URLs). You get a one-line warning with the file, line, and
  kind after memory bank files change, and the session-start summary replaces
  matching values with `[REDACTED]`. Warn-only, and the value is never shown.
  New setting `secret_scan` (default `true`).
- Plugin icon (`.claude-plugin/icon.png`).

## [1.0.0] - 2026-11-21

### Upgrade notes
- **Existing six-file banks keep working with no changes.** The hooks and skills
  still read and update them.
- To switch to the new layout, run `/memory-bank:migrate`. It shows the new files
  first, writes them only after you confirm, and moves the classic files to
  `memory-bank/archive/`. Nothing is deleted.

### Added
- Standard two-file layout for new banks: `brief.md` (project, scope,
  architecture, tech, optional end-state vision and glossary) and `active.md`
  (current focus, next steps, status, known issues), plus optional
  `decisions.md`.
- Slash commands: `/memory-bank:init`, `/memory-bank:update`,
  `/memory-bank:consolidate`, `/memory-bank:migrate`. `init`, `consolidate` and
  `migrate` run only when you type them, so they add nothing to Claude's context
  otherwise.
- Renamed and deleted files now count as changes in git repositories, including
  `git mv` and `git rm`.

### Changed
- The `memory-bank` skill is now a short router; workflows and templates live in
  `skills/memory-bank/workflows/` and `skills/memory-bank/templates/`.
- Reminders name `active.md` in standard-layout banks and the classic files
  otherwise.
- `memory-bank/archive/` is ignored by the hooks.

## [0.3.0] - 2026-11-21

### ⚠️ Behavior change
- **Reminders no longer block Claude by default.** The new default `reminder_mode`
  is `nudge`: you see a one-line notice at the end of a turn, and Claude gets a
  note on your next prompt, once per session until the memory bank is updated.
  To keep the old blocking behavior, set `reminder_mode` to `strict`.

### Added
- SessionStart hook: loads a summary of up to 2,000 characters (brief, current
  focus, other files, staleness) at startup, resume, clear, and after compaction.
- UserPromptSubmit hook (nudge mode): adds a one-line "memory bank is out of date"
  note for Claude. Skipped when your prompt already mentions the memory bank.
- Settings (`userConfig`): `reminder_mode` (nudge/strict/off), `min_changed_files`,
  and `load_mode` (summary/pointer/off).
- Skill: `consolidate memory bank` and `capture this rule` workflows; optional
  End-State Vision and Glossary sections in the project brief template; dated
  Decision History format.

### Changed
- Skill: reads full memory bank files only when the task needs them, instead of
  all six at the start of every task; updates are incremental.
- Recognizes `brief.md` / `active.md` when present, ahead of the classic names.

## [0.2.0] - 2026-11-21

Bug fixes and accuracy updates. Memory bank files and the six-file layout are
unchanged, so no migration is needed.

### Fixed
- Stop hook no longer flags generated or git-ignored files: nested `node_modules`,
  `.venv`, `__pycache__`, caches, coverage output, logs, and anything in
  `.gitignore`.
- Stop hook now finds the project root when Claude starts in a subdirectory (uses
  `CLAUDE_PROJECT_DIR`, the hook's `cwd`, or the git top level).
- Editing an unrelated file in `memory-bank/` no longer silences the reminder; the
  baseline is `activeContext.md` / `progress.md`.
- Filenames with invalid UTF-8 no longer produce invalid hook JSON.
- Generated folders are pruned instead of walked, so the hook stays fast in large
  repositories. Added a 10-second hook timeout.

### Changed
- The reminder reports the total number of changed files.
- The hook stays quiet in plan mode.
- Skill: removed the outdated "memory resets completely" premise; added guidance on
  what belongs in `CLAUDE.md`, auto memory, or the memory bank, and a rule never to
  store secrets or personal data. Shorter skill description.
- PRIVACY.md rewritten to describe what enters model context, git, and remote
  sessions, and that uninstalling does not delete `memory-bank/`.
- README: corrected the slash command to `/memory-bank:memory-bank`.

### Added
- 25 sandboxed hook tests, shellcheck, and macOS CI.
- `.gitignore`, `.gitattributes`, plugin metadata (homepage, repository, license,
  keywords).

## [0.1.0] - 2026-04-11

- Initial release: `memory-bank` skill and Stop hook.
