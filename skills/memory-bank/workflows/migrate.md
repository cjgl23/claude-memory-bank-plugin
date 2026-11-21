# Migrate a Classic Memory Bank to the Standard Layout

Only run this when the user asks. Never delete their files.

1. Confirm `memory-bank/` holds classic files (`projectbrief.md`, `productContext.md`, `systemPatterns.md`, `techContext.md`, `activeContext.md`, `progress.md`). If `brief.md` or `active.md` already exist, stop and ask how to proceed.
2. Read the classic files.
3. Draft the new files using the templates in `../templates/`:
   - `brief.md` from `projectbrief.md`, `productContext.md`, `systemPatterns.md`, and `techContext.md`. Keep only what isn't obvious from the code or already in `CLAUDE.md`.
   - `active.md` from `activeContext.md` and `progress.md`, current focus first.
   - `decisions.md` from any Decision History or key-decision sections, as dated lines (use "date unknown" when there is no date).
   - Rules for Claude (patterns to always or never follow) belong in `CLAUDE.md`; list them separately as suggestions instead of moving them.
4. **Show the user the drafts and this plan, then wait for confirmation:** new files to write; classic files to move to `memory-bank/archive/`; suggested `CLAUDE.md` additions (not applied).
5. After confirmation, write the new files, then move each classic file to `memory-bank/archive/` (use `git mv` when the file is tracked by git). Leave topic notes in place.
6. Tell the user to review with `git diff` / `git status`, and that they can undo by moving the files back from `memory-bank/archive/` and deleting the new ones.
