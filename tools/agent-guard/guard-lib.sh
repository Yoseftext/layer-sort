#!/usr/bin/env bash
# Shared checks for the Layer Sort agent guard. Sourced by safe-agy.sh and test-guard.sh.
# Purpose: close the fail-open gap found on 2026-11-12. Antigravity allows a command
# when its PreToolUse hook script is missing, so we refuse to START a session unless
# the pinned policy is intact and wired, and we verify AFTER the session that nothing
# escaped scope.
set -u
GUARD_STATE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/guard-state.mjs"

SNAP_DIR="${SNAP_DIR:-/root/agent-policy/layer-sort-agent-kit@pr-bf9ad55}"
INST_DIR="${INST_DIR:-/root/.gemini/config/plugins/layer-sort-agent-kit}"
PLUGIN_HOOKS="${PLUGIN_HOOKS:-$INST_DIR/hooks.json}"

fail() { echo "GUARD_FAIL: $*" >&2; exit 3; }

# Pre-session check: refuse to start if the policy is missing, altered, or not wired.
preflight() {
  [ -f "$SNAP_DIR/scripts/policy.sh" ] || fail "snapshot policy.sh missing: $SNAP_DIR"
  [ -f "$SNAP_DIR/scripts/policy.mjs" ] || fail "snapshot policy.mjs missing"
  ( cd "$SNAP_DIR" && sha256sum -c --quiet MANIFEST.sha256 ) || fail "snapshot does not match MANIFEST.sha256"
  local f
  for f in scripts/policy.sh scripts/policy.mjs; do
    [ -f "$INST_DIR/$f" ] || fail "installed $f missing"
    [ "$(sha256sum "$INST_DIR/$f" | cut -d' ' -f1)" = "$(sha256sum "$SNAP_DIR/$f" | cut -d' ' -f1)" ] \
      || fail "installed $f differs from pinned snapshot"
  done
  [ -f "$PLUGIN_HOOKS" ] || fail "plugin hooks.json missing"
  node "$GUARD_STATE" hook "$PLUGIN_HOOKS" "$SNAP_DIR" \
    || fail "plugin hook is not wired to the pinned snapshot"
  return 0
}

# Snapshot failures must reach the caller; never turn incomplete evidence into success.
state() { node "$GUARD_STATE" snapshot "$1"; }
changed_paths() { node "$GUARD_STATE" compare "$1" "$2"; }
