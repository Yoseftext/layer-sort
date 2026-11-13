#!/usr/bin/env bash
# Application-level startup checks and post-run detection; not an OS sandbox.
set -u
fail() { echo "GUARD_FAIL: $*" >&2; exit 3; }
preflight() {
  node "$RUNTIME_HELPER" manifest "$SNAP_DIR" || fail "snapshot integrity verification failed"
  node "$RUNTIME_HELPER" hook "$W/.agents/hooks.json" || fail "workspace Hook does not match the supported dispatcher"
}
state() { node "$STATE_HELPER" snapshot "$1"; }
changed_paths() { node "$STATE_HELPER" compare "$1" "$2"; }
