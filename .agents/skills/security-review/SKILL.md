---
name: security-review
description: Use before changing Git workflows, permissions, credentials, Android integrations, plugins, MCP servers, hooks, or release/build configuration.
---

# Layer Sort Security Review

Check:

- Git branch protection and exact owner authorization under ADR-0007.
- No direct pushes to `main`, force pushes, history rewrites, branch/tag deletion, or unauthorized merges.
- No secrets in tracked files, logs, screenshots, test artifacts, prompts, or reports.
- No keystore/password/token/private-key reads or output.
- No new credentials, paid services, billing, Firebase Blaze, ads, IAP, or production signing.
- No new external asset or dependency without provenance, license, checksum/pin, and owner approval.
- No raw ADB/Appium operations that alter system settings, permissions, services, or other apps.
- No global Termux/Debian package changes without owner approval.
- No MCP server or hook with broad filesystem, network, shell, or credential access.

Do not claim a policy is technically enforced when it exists only as natural-language instructions. Report the difference between tool allowlists, command approval settings, sandboxing, GitHub branch protections, and prose rules.
