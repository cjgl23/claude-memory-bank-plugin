# Changelog

All notable changes to this plugin are documented here. The project uses
[Semantic Versioning](https://semver.org/).

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
