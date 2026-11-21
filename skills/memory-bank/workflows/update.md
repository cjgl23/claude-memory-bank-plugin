# Update Memory Bank (incremental)

Run this when the user asks, when a memory bank reminder appears, or proactively after significant changes and at natural checkpoints.

1. Identify the layout (see SKILL.md). Read the active file(s): `active.md`, or `activeContext.md` and `progress.md` in a classic bank. Read other files only if this session changed what they describe.
2. Review what changed or was learned in this session.
3. Update only what needs it:
   - **Active file(s):** almost always. Put the current focus first, then next steps, status, known issues, and recent changes. Overwrite stale entries; this is a snapshot, not a log.
   - **Brief** (`brief.md`, or `projectbrief.md` / `productContext.md` / `systemPatterns.md` / `techContext.md`): only if scope, architecture, tech, or the glossary changed.
   - **Decisions** (`decisions.md`, or Decision History in `progress.md`): add a dated line for any decision that is hard to reverse: `- [YYYY-MM-DD] Decision | Why: … | Trade-off: …`.
4. Keep the active file short (about one page). If it grows past roughly 150 lines, suggest `consolidate memory bank`.
5. Apply the Never Store rule from SKILL.md.
6. Confirm in one or two lines what was updated.

Parallel sessions on the same branch edit the same active file. Keep edits small and section-scoped so merges stay easy; one writer per branch is the safest habit.
