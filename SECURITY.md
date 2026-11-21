# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.2.x   | :white_check_mark: |
| < 0.2   | :x:                |

## Reporting a Vulnerability

Please report security vulnerabilities by opening a GitHub issue with the label "security" or by emailing the maintainer directly at cjgl23@users.noreply.github.com.

When reporting a vulnerability, please include:

- A clear description of the issue
- Steps to reproduce the vulnerability
- Any relevant logs or error messages
- The version of the plugin you are using
- Any mitigations you have implemented

We aim to acknowledge receipt of vulnerability reports within 48 hours and provide an initial assessment within 5 business days. If the vulnerability is accepted, we will work on a fix and release a security update as soon as possible, typically within 14 days for critical issues.

If the vulnerability is declined, we will provide a detailed explanation of our decision and any recommended mitigations.

## Security Best Practices

When using this plugin:

- Regularly update to the latest version to receive security patches
- Never store credentials, tokens, or personal data in `memory-bank/` files: they are usually committed to git and are sent to the model as part of Claude's context
- Review memory bank changes before committing them
- The plugin itself runs no network code; see [PRIVACY.md](PRIVACY.md) for exactly what enters Claude's context
