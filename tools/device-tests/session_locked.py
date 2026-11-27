"""Internal locked orchestration prototype; no CLI, authorization or ADB dispatch.

Only trusted operator-side code can provide a dispatcher. Python callbacks and
same-user SQLite state are not security boundaries. Never expose this function
to an agent until the authorization, dispatcher, session binding and guard are
implemented and reviewed. Unit tests use simulated callbacks exclusively.
"""
from pathlib import Path
from typing import Any, Callable

import artifact_qa as artifact
import device_qa as device
import session_broker
import session_observe
import session_plan


def run_locked_step(database: Path, plan: dict[str, Any], reviewed_hash: str,
                    index: int, requested: dict[str, Any],
                    dispatch_locked: Callable[[dict[str, Any]], dict[str, Any]],
                    now=None) -> dict[str, Any]:
    """Hold build verification and the phone lock through observation and dispatch."""
    session_plan.check_step(plan, index, requested, reviewed_hash, now)
    with artifact.verified_cached_build(plan["run_id"], plan["source_commit"],
                                        plan["apk_sha256"]):
        with device.phone_lock():
            return session_broker.run_step(
                database, plan, reviewed_hash, index, requested,
                lambda: session_observe.observe_locked(plan, now), dispatch_locked, now)
