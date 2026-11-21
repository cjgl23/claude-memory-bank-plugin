# Capture a Rule

1. Rules for how Claude should work belong in `CLAUDE.md` or `.claude/rules/`, which load every session, not in the memory bank.
2. Propose the exact wording and the file (a path-scoped file in `.claude/rules/` if the rule only applies to part of the code). Ask before writing; these files are shared with the team.
3. If the rule is a project decision rather than an instruction (for example, "we chose Postgres over MySQL"), record it as a dated line in `decisions.md` (or Decision History in `progress.md` for a classic bank) instead.
4. Personal preferences that only matter to this user belong in Claude Code's auto memory, not in shared files.
