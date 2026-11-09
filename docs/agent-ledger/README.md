# Layer Sort Agent Task Ledger

Append-only evidence ledger for real agent tasks. It records tool output, not a process exit code or an agent's unverified claim.

## Fixed record schema

Each JSONL row contains exactly these six project fields:

- `task_id`: stable, unique task ID.
- `agent`: actual agent that performed the task.
- `commit`: full 40-character repository commit used for the task.
- `apk_hash`: SHA-256 of the exact APK when the task depends on an APK; otherwise `null`.
- `result`: structured result with `status`, `tool`, `tool_result`, `summary`, and `evidence`.
- `reviewer_findings`: list of findings, or `null` when no patch was submitted for review / review has not occurred.

Allowed statuses are `PASS`, `FAIL`, and `UNKNOWN`. A timeout, missing tool output, or incomplete evidence is `UNKNOWN`, never an inferred pass.

## Integrity rules

1. One JSON object per line. Never rewrite an existing row; append a correction as a new task ID and reference the superseded record in its evidence.
2. `result.tool_result` must preserve the actual tool response payload or raw response text. An `exit_code` by itself is rejected.
3. Record the full commit SHA. Use `apk_hash: null` only when no APK is involved.
4. Do not assign agent scores from two smoke tasks. The initial two tasks validate collection and traceability only.
5. Do not claim a Reviewer pass when no patch was reviewed. Use `reviewer_findings: null`.
6. Never place secrets, personal data, device serials, or raw unrestricted logs in the ledger.

## Commands

From the repository root:

```sh
bash tools/agents/test-task-ledger.sh
/usr/bin/python3 tools/agents/task_ledger.py validate --min-records 2
/usr/bin/python3 tools/agents/task_ledger.py append --record /path/to/actual-tool-result.json
```

The validator prints a JSON result including the record count, task IDs, number of preserved tool results, and ledger SHA-256. A successful process exit without this JSON payload is not sufficient evidence.

## Initial acceptance tasks

Use two real, bounded, read-only subagent tasks. Capture the actual `invoke_subagent` launch response and the completed subagent response delivered through `send_message`, then append both records. The native `manage_task` tool is process control only (`list`, `kill`, `status`, `send_input`); it does not create or update tasks and is not the ledger backend. Assign stable ledger task IDs locally. No device actions, shell access for agents, file writes, APK build, or agent scoring is part of this acceptance test.
