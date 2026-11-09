#!/usr/bin/env python3
"""Append-only ledger for real agent-tool task results. Python stdlib only."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_LEDGER = ROOT / "docs" / "agent-ledger" / "tasks.jsonl"
STATUSES = {"PASS", "FAIL", "UNKNOWN"}
TASK_ID_PATTERN = re.compile(r"^[A-Z][A-Z0-9_-]{2,63}$")
AGENT_PATTERN = re.compile(r"^[a-z][a-z0-9-]{1,63}$")
COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40}$")
APK_HASH_PATTERN = re.compile(r"^[0-9a-f]{64}$")
REQUIRED_FIELDS = {
    "task_id",
    "agent",
    "commit",
    "apk_hash",
    "result",
    "reviewer_findings",
}
RESULT_FIELDS = {"status", "tool", "tool_result", "summary", "evidence"}


class LedgerError(ValueError):
    """Raised when a ledger record is incomplete or inconsistent."""


def require_string(value: object, field: str, pattern: re.Pattern[str] | None = None) -> str:
    if not isinstance(value, str) or not value.strip():
        raise LedgerError(f"{field} must be a non-empty string")
    if pattern is not None and pattern.fullmatch(value) is None:
        raise LedgerError(f"{field} has an invalid format")
    return value


def validate_record(value: object) -> dict[str, object]:
    if not isinstance(value, dict):
        raise LedgerError("record must be a JSON object")
    if set(value) != REQUIRED_FIELDS:
        missing = sorted(REQUIRED_FIELDS - set(value))
        extra = sorted(set(value) - REQUIRED_FIELDS)
        raise LedgerError(f"record fields mismatch; missing={missing}, extra={extra}")

    task_id = require_string(value["task_id"], "task_id", TASK_ID_PATTERN)
    require_string(value["agent"], "agent", AGENT_PATTERN)
    require_string(value["commit"], "commit", COMMIT_PATTERN)

    apk_hash = value["apk_hash"]
    if apk_hash is not None:
        require_string(apk_hash, "apk_hash", APK_HASH_PATTERN)

    result = value["result"]
    if not isinstance(result, dict) or set(result) != RESULT_FIELDS:
        raise LedgerError(f"result must contain exactly {sorted(RESULT_FIELDS)}")

    status = require_string(result["status"], "result.status")
    if status not in STATUSES:
        raise LedgerError("result.status must be PASS, FAIL, or UNKNOWN")
    require_string(result["tool"], "result.tool")
    require_string(result["summary"], "result.summary")

    tool_result = result["tool_result"]
    if isinstance(tool_result, str):
        if not tool_result.strip():
            raise LedgerError("result.tool_result cannot be empty")
    elif isinstance(tool_result, (dict, list)):
        if not tool_result:
            raise LedgerError("result.tool_result cannot be empty")
        if isinstance(tool_result, dict) and set(tool_result) == {"exit_code"}:
            raise LedgerError("exit_code alone is not an actual tool result")
    else:
        raise LedgerError("result.tool_result must preserve the tool output payload")

    evidence = result["evidence"]
    if not isinstance(evidence, list) or any(
        not isinstance(item, str) or not item.strip() for item in evidence
    ):
        raise LedgerError("result.evidence must be an array of non-empty strings")

    findings = value["reviewer_findings"]
    if findings is not None and (
        not isinstance(findings, list)
        or any(not isinstance(item, str) or not item.strip() for item in findings)
    ):
        raise LedgerError("reviewer_findings must be null or an array of non-empty strings")

    return value


def read_ledger(path: Path) -> list[dict[str, object]]:
    if not path.exists():
        return []
    records: list[dict[str, object]] = []
    seen: set[str] = set()
    with path.open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            if not line.strip():
                raise LedgerError(f"blank line at {line_number}; JSONL must be append-only records")
            try:
                parsed: object = json.loads(line)
            except json.JSONDecodeError as error:
                raise LedgerError(f"invalid JSON at line {line_number}: {error.msg}") from error
            record = validate_record(parsed)
            task_id = str(record["task_id"])
            if task_id in seen:
                raise LedgerError(f"duplicate task_id at line {line_number}: {task_id}")
            seen.add(task_id)
            records.append(record)
    return records


def append_record(ledger: Path, raw_record: object) -> dict[str, object]:
    record = validate_record(raw_record)
    existing = read_ledger(ledger)
    task_id = str(record["task_id"])
    if any(item["task_id"] == task_id for item in existing):
        raise LedgerError(f"task_id already exists: {task_id}")

    ledger.parent.mkdir(parents=True, exist_ok=True)
    encoded = (json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n").encode("utf-8")
    with ledger.open("ab") as handle:
        handle.write(encoded)
        handle.flush()
        os.fsync(handle.fileno())

    digest = hashlib.sha256(encoded.rstrip(b"\n")).hexdigest()
    return {
        "status": "PASS",
        "operation": "append",
        "task_id": task_id,
        "record_count": len(existing) + 1,
        "tool_result_verified": True,
        "record_sha256": digest,
    }


def validate_ledger(ledger: Path, minimum_records: int) -> dict[str, object]:
    records = read_ledger(ledger)
    if len(records) < minimum_records:
        raise LedgerError(
            f"minimum record count not met: expected {minimum_records}, found {len(records)}"
        )
    content = ledger.read_bytes() if ledger.exists() else b""
    return {
        "status": "PASS",
        "operation": "validate",
        "record_count": len(records),
        "tool_results_verified": len(records),
        "task_ids": [record["task_id"] for record in records],
        "ledger_sha256": hashlib.sha256(content).hexdigest(),
    }


def emit(payload: dict[str, object], exit_code: int) -> int:
    print(json.dumps(payload, ensure_ascii=False, sort_keys=True))
    return exit_code


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    append_parser = subparsers.add_parser("append", help="append one real tool-result record")
    append_parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    append_parser.add_argument("--record", type=Path, required=True)

    validate_parser = subparsers.add_parser("validate", help="validate all ledger records")
    validate_parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    validate_parser.add_argument("--min-records", type=int, default=0)

    args = parser.parse_args(argv)
    try:
        if args.command == "append":
            raw: object = json.loads(args.record.read_text(encoding="utf-8"))
            return emit(append_record(args.ledger, raw), 0)
        if args.min_records < 0:
            raise LedgerError("--min-records cannot be negative")
        return emit(validate_ledger(args.ledger, args.min_records), 0)
    except (OSError, json.JSONDecodeError, LedgerError) as error:
        return emit({"status": "FAIL", "error": str(error)}, 1)


if __name__ == "__main__":
    sys.exit(main())
