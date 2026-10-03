# Security policy

Synclip handles clipboard contents, which often include passwords and one-time codes, so security reports are taken seriously.

## Reporting a vulnerability

Report privately through GitHub: **Security → Report a vulnerability** on this repository. Please don't open a public issue.

Include what you found, how to reproduce it, and the impact you expect. You'll get an acknowledgement within 7 days.

## Supported versions

Only the latest release receives security fixes while the project is pre-1.0.

## Scope

The threat model is in [PLAN.md §4.2](PLAN.md). Reports that break its stated guarantees (the server reading clip content, joining a room without approval, a removed device decrypting new clips) are the most valuable.
