"""Offline session progress state; this does not authorize or execute actions.

The runtime must protect the database from agent writes and independently
verify owner authorization and device state. A same-user SQLite file is not an
OS security boundary. An interrupted claimed action remains blocked.
"""
from __future__ import annotations

import sqlite3
from contextlib import closing
from pathlib import Path
from typing import Any

import session_plan


class SequenceError(ValueError):
    pass


def create_state(database: Path, plan: dict[str, Any], reviewed_hash: str, now=None) -> None:
    """Initialize progress for an already-reviewed plan; creates no authority."""
    session_plan.validate(plan, now)
    if session_plan.plan_hash(plan) != reviewed_hash:
        raise SequenceError("Plan digest mismatch")
    # 'x' prevents silently reinitializing or erasing an earlier session.
    with database.open("xb"):
        pass
    with closing(sqlite3.connect(database)) as db, db:
        db.execute("CREATE TABLE progress (id INTEGER PRIMARY KEY CHECK(id=1), digest TEXT NOT NULL, next_step INTEGER NOT NULL, inflight INTEGER, blocked INTEGER NOT NULL)")
        db.execute("INSERT INTO progress VALUES (1, ?, 0, NULL, 0)", (reviewed_hash,))


def begin_step(database: Path, plan: dict[str, Any], index: int,
               requested: dict[str, Any], reviewed_hash: str, now=None) -> None:
    """Claim one exact step before any external effect; never authorizes it."""
    if not database.is_file():
        raise SequenceError("Missing session state")
    with closing(sqlite3.connect(database, timeout=5, isolation_level=None)) as db, db:
        db.execute("BEGIN IMMEDIATE")
        try:
            row = db.execute("SELECT digest, next_step, inflight, blocked FROM progress WHERE id=1").fetchone()
            if not row or row[0] != reviewed_hash or row[1] != index or row[2] is not None or row[3]:
                raise SequenceError("Session is blocked, in progress, or out of order")
            session_plan.check_step(plan, index, requested, reviewed_hash, now)
            db.execute("UPDATE progress SET inflight=? WHERE id=1", (index,))
            db.execute("COMMIT")
        except BaseException:
            db.execute("ROLLBACK")
            raise


def finish_step(database: Path, index: int, outcome: str) -> None:
    """Record verified PASS or block after FAIL/UNKNOWN; no automatic retries."""
    if outcome not in {"PASS", "FAIL", "UNKNOWN"} or type(index) is not int:
        raise SequenceError("Invalid outcome or index")
    if not database.is_file():
        raise SequenceError("Missing session state")
    with closing(sqlite3.connect(database, timeout=5, isolation_level=None)) as db, db:
        db.execute("BEGIN IMMEDIATE")
        try:
            row = db.execute("SELECT next_step, inflight, blocked FROM progress WHERE id=1").fetchone()
            if not row or row[0] != index or row[1] != index or row[2]:
                raise SequenceError("No matching in-flight step")
            if outcome == "PASS":
                db.execute("UPDATE progress SET next_step=?, inflight=NULL WHERE id=1", (index + 1,))
            else:
                db.execute("UPDATE progress SET blocked=1 WHERE id=1")
            db.execute("COMMIT")
        except BaseException:
            db.execute("ROLLBACK")
            raise
