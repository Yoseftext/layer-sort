#!/usr/bin/env bash
# Usage: safe-agy.sh <registered-task-worktree> -- <agy arguments>
set -u
main() {
  DIR="$(cd "$(dirname "$0")" && pwd)"
  . "$DIR/guard-lib.sh"
  W="${1:-}"; [ -n "$W" ] || fail "worktree is required"
  shift
  [ "${1:-}" = "--" ] || fail "usage: safe-agy.sh <worktree> -- <agy arguments>"
  shift

  TMP="$(mktemp -d)" || fail "could not create session directory"
  cat "$DIR/guard-state.mjs" > "$TMP/guard-state.mjs" || fail "could not freeze state helper"
  cat "$DIR/runtime-config.mjs" > "$TMP/runtime-config.mjs" || fail "could not freeze runtime helper"
  STATE_HELPER="$TMP/guard-state.mjs"
  RUNTIME_HELPER="$TMP/runtime-config.mjs"
  node "$RUNTIME_HELPER" args "$@" || fail "invalid launch arguments"
  PROJECT_ROOT="$(node "$RUNTIME_HELPER" project "$W")" || fail "invalid task worktree"
  if [ -z "${SNAP_DIR:-}" ]; then
    SNAP_DIR="$(node "$RUNTIME_HELPER" active "$W")" || fail "prepare a task before launching"
  fi
  export LS_PROJECT_ROOT="$PROJECT_ROOT" LS_POLICY_SNAPSHOT="$SNAP_DIR"
  GODOT_BIN_DIR="$(node "$RUNTIME_HELPER" godot-bin "$PROJECT_ROOT")" || fail "invalid private Godot runtime"
  if [ -n "$GODOT_BIN_DIR" ]; then export PATH="$GODOT_BIN_DIR:$PATH"; fi
  preflight
  node "$RUNTIME_HELPER" session "$SNAP_DIR" "$W" "$TMP" || fail "task grant unavailable"
  on_exit() {
    local rc=$?
    if ! node "$RUNTIME_HELPER" revoke "$SNAP_DIR"; then
      echo "GUARD_FAIL: could not revoke task grant; inspect $SNAP_DIR" >&2
      rc=3
    fi
    if ! node "$RUNTIME_HELPER" release-cli "$PROJECT_ROOT" "$TMP"; then
      echo "GUARD_FAIL: could not verify disposable CLI cleanup" >&2
      rc=3
    fi
    exit "$rc"
  }
  trap on_exit EXIT

  export AGY_CLI_DISABLE_AUTO_UPDATE=true
  CLI_SOURCE="${AGY_BIN:-}"
  if [ -z "$CLI_SOURCE" ]; then CLI_SOURCE="$(node "$RUNTIME_HELPER" cli-source "$PROJECT_ROOT")" || fail "invalid approved CLI runtime"; fi
  AGY_CMD="$(node "$RUNTIME_HELPER" freeze-cli "$CLI_SOURCE" "$TMP")" || fail "could not pin CLI executable"
    VERSION="$(timeout 15s "$AGY_CMD" --version)" || fail "could not inspect CLI version"
    case "$VERSION" in 1.5.8|1.5.13) ;; *) fail "untested CLI version $VERSION; compatibility review required" ;; esac
    PLUGINS="$(cd "$W" && timeout 20s "$AGY_CMD" --settings "$TMP/settings.json" plugin list)" || fail "could not inspect plugins"
    printf '%s\n' "$PLUGINS" | grep -q '^- layer-sort-agent-kit (disabled' || fail "disable the overlapping layer-sort-agent-kit plugin once before using workspace agents"
  node "$RUNTIME_HELPER" verify-cli "$TMP" || fail "CLI changed during preflight"
  state "$W" > "$TMP/before" || fail "before-state collection failed; agent not started"
  BUDGET="$(cat "$TMP/timeout")" || fail "missing session deadline"
    (cd "$W" && timeout --kill-after=10s "${BUDGET}s" "$AGY_CMD" --settings "$TMP/settings.json" --mode accept-edits "$@")
  RC=$?
  node "$RUNTIME_HELPER" verify-cli "$TMP" || fail "pinned CLI changed during execution"
  node "$RUNTIME_HELPER" manifest "$SNAP_DIR" || fail "policy changed during the session"
  node "$RUNTIME_HELPER" revoke "$SNAP_DIR" || fail "could not close task write authority"
  state "$W" > "$TMP/after" || fail "after-state collection failed; evidence retained in $TMP"
  CHANGED="$(changed_paths "$TMP/before" "$TMP/after")" || fail "state comparison failed; evidence retained in $TMP"
  BAD=""
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    case "$p" in
      HEAD|INDEX|.agents/*) BAD="$BAD
  - protected state changed: $p"; continue ;;
    esac
    grep -qxF -- "$p" "$TMP/allow" || BAD="$BAD
  - out of scope: $p"
  done <<EOF
$CHANGED
EOF
  if [ -n "$BAD" ]; then
    echo "GUARD_VIOLATION (agent exit $RC):$BAD" >&2
    echo "Evidence retained in $TMP. No automatic rollback." >&2
    exit 2
  fi
  echo "GUARD_OK (agent exit $RC, changed paths: $(printf '%s' "$CHANGED" | grep -c . || true))"
  echo "Evidence retained in $TMP; task grant revoked."
  exit "$RC"
}
main "$@"
