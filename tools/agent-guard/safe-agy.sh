#!/usr/bin/env bash
# Usage:
#   safe-agy.sh --status [project-worktree]
#   safe-agy.sh --check [project-worktree]
#   safe-agy.sh <registered-task-worktree> -- <agy arguments>
set -u

main() {
  export AGY_CLI_DISABLE_AUTO_UPDATE=true
  unset SAFE_AGY_SESSION_CLI
  local DIR INFRA_DIR TMP STATE_HELPER RUNTIME_HELPER COMPAT_HELPER TEST_DIR
  local W PROJECT_ROOT SNAP_DIR PLUGINS BUDGET RC CHANGED BAD
  DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)" || exit 3
  INFRA_DIR="$(cd -- "$DIR/../.." && pwd -P)" || exit 3
  . "$DIR/guard-lib.sh"

  for name in ${!LD_@}; do
    [ -z "${!name}" ] || fail "unsafe dynamic-loader environment variable set: $name"
  done
  for name in NODE_OPTIONS NODE_PATH BASH_ENV; do
    [ -z "${!name-}" ] || fail "unsafe Node/Bash startup environment variable set: $name"
  done

  if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Usage: safe-agy.sh --status [project-worktree]"
    echo "       safe-agy.sh --check [project-worktree]"
    echo "       safe-agy.sh <worktree> -- <agy arguments>"
    return 0
  fi

  if [ "${1:-}" = "--status" ]; then
    node "$DIR/compatibility.mjs" --status "${2:-$INFRA_DIR}"
    return $?
  fi

  W="${1:-}"
  if [ -z "$W" ]; then
    fail "worktree is required"
  fi

  if [ "$W" != "--check" ]; then
    shift
    [ "${1:-}" = "--" ] || fail "usage: safe-agy.sh <worktree> -- <agy arguments>"
    shift
  else
    shift
  fi

  umask 077
  TMP="$(mktemp -d)" || fail "could not create session directory"
  TEST_DIR="$TMP/compatibility-tests"
  mkdir "$TEST_DIR" || fail "could not create compatibility test snapshot"

  # Freeze the guard and compatibility harness before any agent process starts.
  cat "$DIR/guard-state.mjs" > "$TMP/guard-state.mjs" || fail "could not freeze state helper"
  cat "$DIR/runtime-config.mjs" > "$TMP/runtime-config.mjs" || fail "could not freeze runtime helper"
  cat "$DIR/compatibility.mjs" > "$TMP/compatibility.mjs" || fail "could not freeze compatibility helper"
  cat "$DIR/repair-coordinator.mjs" > "$TMP/repair-coordinator.mjs" || fail "could not freeze repair coordinator"
  for name in compatibility.mjs guard-state.mjs runtime-config.mjs repair-coordinator.mjs test-compatibility.sh test-compatibility.mjs test-repair-coordinator.mjs test-state.mjs test-launcher.mjs test-runtime-config.mjs test-active-compatibility.mjs; do
    [ -f "$DIR/$name" ] || fail "required compatibility test is missing: $name"
    cat "$DIR/$name" > "$TEST_DIR/$name" || fail "could not freeze compatibility test: $name"
  done
  mkdir "$TEST_DIR/fakes" || fail "could not create compatibility fixture directory"
  cat "$DIR/fakes/create-fixture.mjs" > "$TEST_DIR/fakes/create-fixture.mjs" || fail "could not freeze compatibility fixture"
  printf '%s\n' "$DIR" > "$TEST_DIR/test-source-dir" || fail "could not record compatibility fixture source directory"
  STATE_HELPER="$TMP/guard-state.mjs"
  RUNTIME_HELPER="$TMP/runtime-config.mjs"
  COMPAT_HELPER="$TMP/compatibility.mjs"
  verify_compat_snapshot() {
    for name in compatibility.mjs guard-state.mjs runtime-config.mjs repair-coordinator.mjs; do
      cmp -s "$DIR/$name" "$TMP/$name" || fail "frozen launcher helper differs from reviewed source: $name"
    done
    for name in compatibility.mjs guard-state.mjs runtime-config.mjs repair-coordinator.mjs test-compatibility.sh test-compatibility.mjs test-repair-coordinator.mjs test-state.mjs test-launcher.mjs test-runtime-config.mjs test-active-compatibility.mjs; do
      cmp -s "$DIR/$name" "$TEST_DIR/$name" || fail "frozen compatibility test differs from reviewed source: $name"
    done
    cmp -s "$DIR/fakes/create-fixture.mjs" "$TEST_DIR/fakes/create-fixture.mjs" || fail "frozen compatibility fixture differs from reviewed source"
    [ "$(cat "$TEST_DIR/test-source-dir")" = "$DIR" ] || fail "compatibility fixture source directory changed"
  }
  verify_compat_snapshot
  export SAFE_AGY_INFRA_DIR="$INFRA_DIR"
  export SAFE_AGY_COMPAT_TEST_DIR="$TEST_DIR"

  if [ "$W" = "--check" ]; then
    PROJECT_ROOT="${1:-$INFRA_DIR}"
    node "$COMPAT_HELPER" --check "$PROJECT_ROOT"
    RC=$?
    verify_compat_snapshot
    return "$RC"
  fi

  node "$RUNTIME_HELPER" args "$@" || fail "invalid launch arguments"
  PROJECT_ROOT="$(node "$RUNTIME_HELPER" project "$W")" || fail "invalid task worktree"

  # No fixed Antigravity version allowlist: require an approved executable,
  # dependency, host, launcher, policy and test fingerprint.
  node "$COMPAT_HELPER" --ensure "$W" >"$TMP/compatibility-output.log" 2>"$TMP/compatibility-error.log"
  RC=$?
  if [ "$RC" -ne 0 ] && [ "${SAFE_AGY_REPAIR_VERBOSE_FAILURE:-}" = "1" ]; then
    cat "$TMP/compatibility-output.log" >&2
  fi
  cat "$TMP/compatibility-error.log" >&2
  verify_compat_snapshot
  if [ "$RC" -ne 0 ]; then
    # Repair proposals use a separate, verified CLI and never replace this task.
    if [ "${SAFE_AGY_REPAIR_CHILD:-}" != "1" ] && [ "${SAFE_AGY_AUTO_REPAIR:-1}" != "0" ] &&
       grep -qE '^(RECOVERY_DIAGNOSIS: (unknown|test_failure)|SAFE_AGY_COMPATIBILITY_UNKNOWN: (Antigravity is not an ELF executable|ELF RPATH/RUNPATH is not supported by the dependency resolver))$' "$TMP/compatibility-error.log"; then
      if [ -x /usr/bin/flock ]; then
        local -a REPAIR_MODEL_ARGS=()
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --disable-slash-commands) shift ;;
            --model) REPAIR_MODEL_ARGS=(--model "$2"); shift 2 ;;
            *) shift 2 ;;
          esac
        done
        /usr/bin/flock -n "$PROJECT_ROOT/.git/agent-runtime-policy/auto-repair.lock" \
          node "$TMP/repair-coordinator.mjs" "$INFRA_DIR" "$W" "$TMP/compatibility-error.log" "${REPAIR_MODEL_ARGS[@]}" ||
          echo "AUTO_REPAIR_BLOCKED: another repair is running or recovery failed" >&2
      else
        echo "AUTO_REPAIR_BLOCKED: flock is required for automatic recovery" >&2
      fi
    fi
    fail "Antigravity compatibility gate did not PASS"
  fi

  if [ -z "${SNAP_DIR:-}" ]; then
    SNAP_DIR="$(node "$RUNTIME_HELPER" active "$W")" || fail "prepare a task before launching"
  fi
  export LS_PROJECT_ROOT="$PROJECT_ROOT" LS_POLICY_SNAPSHOT="$SNAP_DIR"
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
  GODOT_BIN_DIR="$(node "$RUNTIME_HELPER" godot-bin "$PROJECT_ROOT")" || fail "invalid private Godot runtime"
  if [ -n "$GODOT_BIN_DIR" ]; then export PATH="$GODOT_BIN_DIR:$PATH"; fi
  preflight
  node "$RUNTIME_HELPER" session "$SNAP_DIR" "$W" "$TMP" || fail "task grant unavailable"
  CLI_SOURCE="${AGY_BIN:-agy}"
  AGY_CMD="$(node "$RUNTIME_HELPER" freeze-cli "$CLI_SOURCE" "$TMP")" || fail "could not pin CLI executable"
  export SAFE_AGY_SESSION_CLI="$AGY_CMD"
  node "$RUNTIME_HELPER" verify-cli "$TMP" || fail "CLI changed during preflight"

  PLUGINS="$(cd "$W" && /usr/bin/timeout 20s node "$COMPAT_HELPER" --capture "$W" --settings "$TMP/settings.json" plugin list)" || fail "could not inspect plugins through the verified executable descriptor"
  printf '%s\n' "$PLUGINS" | grep -q '^- layer-sort-agent-kit (disabled' || fail "disable the overlapping layer-sort-agent-kit plugin once before using workspace agents"

  state "$W" > "$TMP/before" || fail "before-state collection failed; agent not started"
  BUDGET="$(cat "$TMP/timeout")" || fail "missing session deadline"
  (cd "$W" && /usr/bin/timeout --kill-after=10s "${BUDGET}s" node "$COMPAT_HELPER" --exec "$W" --settings "$TMP/settings.json" --mode accept-edits "$@")
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
