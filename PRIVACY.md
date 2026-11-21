# Privacy Policy for Claude Memory Bank Plugin

## Summary

The Claude Memory Bank Plugin ("the Plugin") runs no network code of its own and
collects no telemetry. It reads and writes plain Markdown files in your project.
Those files, and the Plugin's hook messages, become part of Claude's context, so
they are processed by the model provider in the same way as anything else Claude
Code reads. Treat Memory Bank files like any other file you commit.

## What the Plugin Does on Your Machine

- **The `memory-bank` skill** tells Claude how to create, read, and update files in
  your project's `memory-bank/` directory.
- **The Stop hook** (`scripts/memory-bank-hook.sh`) runs locally at the end of each
  Claude turn. It compares file modification times in your project, filters out
  git-ignored and generated files, and may return a short message that lists up
  to five changed file paths.
- The Plugin does not send data to any server, API, or third party, and does not
  collect analytics.

## What Leaves Your Machine

- **Model context.** When Claude reads or writes Memory Bank files, their contents
  enter the conversation. The hook's message, including the changed file paths,
  does too. Claude Code sends that context to the model provider under your Claude
  Code terms and settings. The Plugin adds no separate transmission.
- **Version control.** `memory-bank/` is usually committed. Once you commit and push
  it, its contents reach your git remote, forks, CI systems, and anyone with access
  to the repository.
- **Remote and cloud sessions.** If you use Claude Code in a remote or cloud
  environment, the Memory Bank files live in that environment's copy of your
  repository.

## Keeping Sensitive Information Out

Do not store credentials, API keys, tokens, passwords, connection strings, private
keys, personal data, or customer data in Memory Bank files. The skill instructs
Claude not to write such information there. Review the files before committing,
as you would review any other change.

If you work alone and do not want the Memory Bank shared, add `memory-bank/` to
your `.gitignore`.

## Your Control Over the Data

- Memory Bank files are plain Markdown. You can read, edit, or delete them at any
  time.
- **Uninstalling the Plugin does not delete `memory-bank/` directories.** To remove
  the data, delete the `memory-bank/` folder from each project (and from git
  history if it was committed and you need it fully removed).
- You choose whether to initialize a Memory Bank in each project. The Stop hook does
  nothing in projects without one.

## Changes to This Policy

Updates to this policy are recorded in this file and in `CHANGELOG.md`.

## Contact

Questions about this policy or the Plugin's data handling can be raised on the
repository's issues page.

## Effective Date

This policy is effective as of November 21, 2026.

---
*This plugin is licensed under the Apache License 2.0. See LICENSE file for details.*
