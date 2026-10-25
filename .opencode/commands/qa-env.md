---
description: Read-only environment inventory (repo, CI, tools, device, Shizuku state)
agent: repo-auditor
subagent: true
---

Run the G1.5 environment inventory and report it strictly.

1. Execute `bash tools/qa/qa-env.sh --json` (add any extra arguments: $ARGUMENTS).
2. Confirm the repo branch/HEAD, protected refs (`main`, `spike/godot-csharp-android`), CI status, installed tool versions, `agentctl status`, ADB device presence, free disk/RAM, and the read-only Shizuku capability state.
3. Use test IDs ENV-01..05 and SEC-01..04 from `docs/current/05-QA-TEST-CATALOG.md`; statuses must be `PASS`, `FAIL`, `SKIP`, or `UNVERIFIED`.
4. Do not change any machine, phone, or service state. Quote exact command output for every claim.
