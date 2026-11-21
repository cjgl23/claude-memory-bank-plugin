# Privacy Policy for Claude Memory Bank Plugin

## Introduction
This privacy policy describes how the Claude Memory Bank Plugin ("the Plugin") handles information when used with Claude Code.

## Information Collection and Use
The Claude Memory Bank Plugin is designed to operate entirely locally on your machine. It does not collect, transmit, or store any personal data externally.

### Local Operations Only
- All plugin functionality occurs within your local Claude Code environment
- Memory bank files are stored exclusively in your project's `memory-bank/` directory
- No data is sent to external servers, APIs, or third-party services
- The plugin only reads and writes files within your local project directory

### Types of Information Handled
The plugin may process:
- Project file paths and modification timestamps (for staleness checking)
- Content of memory bank markdown files (for reading/updating context)
- Temporary working data during plugin execution (held only in memory)

All information remains strictly on your local machine and is never transmitted elsewhere.

## Data Storage and Security
- Memory bank data is stored as plain text Markdown files in your project's `memory-bank/` directory
- You have complete control over these files and can view, edit, or delete them at any time
- The plugin does not implement any additional security measures beyond standard file system permissions
- You are responsible for securing your local machine and project files

## Data Sharing
The plugin does not share any data with:
- Anthropic or Claude Code services (beyond standard plugin execution)
- Third-party services or APIs
- Any external servers or cloud storage
- Other users or systems

## Your Rights and Choices
You have complete control over:
- Whether to install or use the plugin
- What information is stored in your memory bank files
- When to initialize, update, or read memory bank data
- The ability to completely remove the plugin and all associated data

## Changes to This Policy
Any updates to this privacy policy will be reflected in this file. Continued use of the plugin after changes constitutes acceptance of the updated policy.

## Contact
If you have questions about this privacy policy or the plugin's data practices, please contact the plugin maintainer through the repository issues page.

## Effective Date
This policy is effective as of April 12, 2026.

---
*This plugin is licensed under the Apache License 2.0. See LICENSE file for details.*