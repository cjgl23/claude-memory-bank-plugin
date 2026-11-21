# Initialize Memory Bank

1. If `memory-bank/` already has files, stop and ask before changing anything. If it is a classic six-file bank, offer `/memory-bank:migrate` instead.
2. Explore the project (README, CLAUDE.md, manifests such as package.json or pyproject.toml, main source folders) to gather real content. Don't create empty stubs when you can derive content, and don't repeat what CLAUDE.md already says.
3. Create `memory-bank/brief.md` and `memory-bank/active.md` from the templates in `../templates/` (`brief.md`, `active.md`). Fill in what you learned; leave optional sections out if there is nothing to say. For a brand-new project, use what the user has described.
4. Create `memory-bank/decisions.md` from `../templates/decisions.md` only if there are decisions worth recording now.
5. Apply the Never Store rule from SKILL.md.
6. Tell the user what was created, with a two-line summary of each file, and remind them the folder is meant to be committed.
