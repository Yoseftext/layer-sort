#!/usr/bin/env python3
"""Combine structured QA reports; FAIL/UNVERIFIED never becomes PASS."""
import argparse
import json
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument("runs", nargs="+", type=Path, help="report.json files or directories containing one")
p.add_argument("--out", type=Path, help="Markdown index path")
a = p.parse_args()
items = []
for run in a.runs:
    source = run / "report.json" if run.is_dir() else run
    try:
        item = json.loads(source.read_text())
        status = item["status"]
        if status not in ("PASS", "FAIL", "SKIP", "UNVERIFIED"):
            raise ValueError("invalid status")
        items.append((source, item["workflow"], status))
    except (OSError, ValueError, KeyError) as e:
        items.append((source, "unreadable", "FAIL"))
lines = ["# G1.5 QA report index", "", "| Workflow | Status | Evidence |", "|---|---|---|"]
lines += [f"| {name} | {status} | `{path}` |" for path, name, status in items]
overall = "FAIL" if any(s == "FAIL" for _, _, s in items) else ("UNVERIFIED" if any(s == "UNVERIFIED" for _, _, s in items) else "PASS")
lines += ["", f"**Overall: {overall}**", ""]
text = "\n".join(lines)
print(text, end="")
if a.out:
    a.out.parent.mkdir(parents=True, exist_ok=True)
    a.out.write_text(text)
raise SystemExit(0 if overall == "PASS" else 1)
