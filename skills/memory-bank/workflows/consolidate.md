# Consolidate Memory Bank

1. Read all memory bank files except `memory-bank/archive/`.
2. Trim the active file(s) to the current state: move finished items into the status section (or `progress.md` in a classic bank), and delete entries that are no longer true.
3. Remove content duplicated between files or already in `CLAUDE.md`. Keep each fact in one place.
4. Date any undated decisions and move them to `decisions.md` (or Decision History in a classic bank).
5. Check for anything that breaks the Never Store rule and remove it.
6. Summarize what was removed or moved, so the user can review the diff before committing.
