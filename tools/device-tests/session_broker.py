"""Offline orchestration prototype; not authorization or a device entrypoint.

Only a trusted operator runtime may provide the callbacks. This does not protect
same-user state, issue approval, acquire a phone lock, or call a device.
"""
from pathlib import Path
from typing import Any, Callable
import session_plan
import session_sequence


class BrokerError(ValueError):
    pass


def run_step(database: Path, plan: dict[str, Any], reviewed_hash: str, index: int,
             requested: dict[str, Any], observe: Callable[[], dict[str, Any]],
             dispatch: Callable[[dict[str, Any]], dict[str, Any]], now=None) -> dict[str, Any]:
    """Check evidence, claim, recheck, then dispatch one ordered operation.

    Callback results must never be supplied by the agent. A process crash after
    claiming leaves the step in flight; it must not be retried automatically.
    """
    session_plan.check_step(plan, index, requested, reviewed_hash, now)
    session_plan.check_preconditions(plan, observe(), now)
    session_sequence.begin_step(database, plan, index, requested, reviewed_hash, now)
    try:
        session_plan.check_preconditions(plan, observe(), now)
        result = dispatch(dict(plan["operations"][index]))
        if not isinstance(result, dict) or result.get("action") != requested["action"]:
            raise BrokerError("Invalid executor result")
        status = result.get("status")
        if status not in ("PASS", "FAIL", "SKIP", "UNKNOWN"):
            raise BrokerError("Invalid executor status")
        session_sequence.finish_step(database, index, "PASS" if status == "PASS" else "UNKNOWN")
        return result
    except BaseException:
        try:
            session_sequence.finish_step(database, index, "UNKNOWN")
        except BaseException:
            pass
        raise
