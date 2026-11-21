# Changelog

All notable changes to this plugin are documented here. The project uses
[Semantic Versioning](https://semver.org/).

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
