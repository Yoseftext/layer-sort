from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.agents.task_ledger import (
    LedgerError,
    append_record,
    read_ledger,
    validate_ledger,
    validate_record,
)


def valid_record(task_id: str = "LS-TASK-001") -> dict[str, object]:
    return {
        "task_id": task_id,
        "agent": "repo-auditor",
        "commit": "eca5665c4d63cbd8b6c1d461e7c840d26ff8ac6b",
        "apk_hash": None,
        "result": {
            "status": "PASS",
            "tool": "manage_task",
            "tool_result": {
                "task_id": "actual-tool-task-123",
                "content": [{"type": "text", "text": "Task created and returned by tool"}],
            },
            "summary": "Read-only repository inventory task completed.",
            "evidence": ["actual-tool-task-123"],
        },
        "reviewer_findings": None,
    }


class TaskLedgerTests(unittest.TestCase):
    def test_accepts_actual_tool_payload(self) -> None:
        record = validate_record(valid_record())
        self.assertEqual(record["task_id"], "LS-TASK-001")

    def test_rejects_exit_code_without_tool_payload(self) -> None:
        record = valid_record()
        result = record["result"]
        assert isinstance(result, dict)
        result["tool_result"] = {"exit_code": 0}
        with self.assertRaisesRegex(LedgerError, "exit_code alone"):
            validate_record(record)

    def test_rejects_incomplete_commit_hash(self) -> None:
        record = valid_record()
        record["commit"] = "eca5665"
        with self.assertRaisesRegex(LedgerError, "commit has an invalid format"):
            validate_record(record)

    def test_rejects_malformed_apk_hash(self) -> None:
        record = valid_record()
        record["apk_hash"] = "not-a-hash"
        with self.assertRaisesRegex(LedgerError, "apk_hash has an invalid format"):
            validate_record(record)

    def test_rejects_unknown_status(self) -> None:
        record = valid_record()
        result = record["result"]
        assert isinstance(result, dict)
        result["status"] = "DONE"
        with self.assertRaisesRegex(LedgerError, "must be PASS"):
            validate_record(record)

    def test_append_and_validate_two_actual_records(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            ledger = Path(temporary) / "tasks.jsonl"
            first = append_record(ledger, valid_record("LS-TASK-001"))
            second = append_record(ledger, valid_record("LS-TASK-002"))
            self.assertEqual(first["record_count"], 1)
            self.assertEqual(second["record_count"], 2)
            result = validate_ledger(ledger, minimum_records=2)
            self.assertEqual(result["status"], "PASS")
            self.assertEqual(result["tool_results_verified"], 2)
            self.assertEqual(len(read_ledger(ledger)), 2)

    def test_duplicate_task_id_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            ledger = Path(temporary) / "tasks.jsonl"
            append_record(ledger, valid_record())
            with self.assertRaisesRegex(LedgerError, "already exists"):
                append_record(ledger, valid_record())

    def test_corrupt_jsonl_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            ledger = Path(temporary) / "tasks.jsonl"
            ledger.write_text("{bad json}\n", encoding="utf-8")
            with self.assertRaisesRegex(LedgerError, "invalid JSON"):
                read_ledger(ledger)

    def test_reviewer_findings_are_explicit(self) -> None:
        record = valid_record()
        record["reviewer_findings"] = "not reviewed"
        with self.assertRaisesRegex(LedgerError, "reviewer_findings"):
            validate_record(record)


if __name__ == "__main__":
    unittest.main()
