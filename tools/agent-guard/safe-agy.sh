#!/usr/bin/env bash
# Usage: safe-agy.sh <worktree> <allowlist-file> -- <agy args...>
# 1) preflight: refuse to start if the pinned policy is missing, altered, or not wired.
# 2) enable the plugin for THIS session only (so the PreToolUse guard is active during it),
#    and restore its previous state on exit, even on failure (trap).
# 3) snapshot the worktree state, run agy, snapshot again.
# 4) fail (exit 2) on out-of-allowlist changes, a moved HEAD, or any change under .agents/.
#    It does NOT auto-revert: the operator decides.
# SAFE_TOGGLE=0 disables step 2 (used by the test suite only).
set -u
# Bash parses the complete function before execution, even if this source is edited later.
main() {
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/guard-lib.sh"

PLUGIN="${PLUGIN_NAME:-layer-sort-agent-kit}"
TOGGLE="${SAFE_TOGGLE:-1}"
W="${1:-}"; ALLOW="${2:-}"
[ -n "$W" ] && [ -n "$ALLOW" ] || fail "usage: safe-agy.sh <worktree> <allowlist> -- <agy args>"
shift 2
[ "${1:-}" = "--" ] && shift
git -C "$W" rev-parse --git-dir >/dev/null 2>&1 || fail "not a git worktree: $W"
[ -f "$ALLOW" ] || fail "allowlist missing: $ALLOW"

preflight

plugin_enabled() { agy plugin list 2>/dev/null | grep -q "^- $PLUGIN (enabled"; }
WAS_ENABLED=no
[ "$TOGGLE" = 1 ] && plugin_enabled && WAS_ENABLED=yes
restore() {
  if [ "$TOGGLE" = 1 ] && [ "$WAS_ENABLED" = no ]; then
    agy plugin disable "$PLUGIN" >/dev/null 2>&1
  fi
}
trap restore EXIT

if [ "$TOGGLE" = 1 ]; then
  agy plugin enable "$PLUGIN" >/dev/null 2>&1 || fail "could not enable plugin"
  plugin_enabled || fail "plugin not enabled after enable"
fi

TMP="$(mktemp -d)" || fail "could not create snapshot directory"
cat -- "$ALLOW" > "$TMP/allow" || fail "could not freeze allowlist"
# Both snapshots and comparison must use the operator-reviewed code from session start.
cat -- "$GUARD_STATE" > "$TMP/guard-state.mjs" || fail "could not freeze state helper"
GUARD_STATE="$TMP/guard-state.mjs"
state "$W" > "$TMP/before" || fail "before-state collection failed; agent not started"

AGY_CMD="${AGY_BIN:-agy}"
( cd "$W" && "$AGY_CMD" "$@" )
RC=$?

state "$W" > "$TMP/after" || fail "after-state collection failed; evidence retained in $TMP"
CHANGED="$(changed_paths "$TMP/before" "$TMP/after")" || fail "state comparison failed; evidence retained in $TMP"

BAD=""
while IFS= read -r p; do
  [ -z "$p" ] && continue
  if [ "$p" = "HEAD" ] || [ "$p" = "INDEX" ]; then
    BAD="$BAD
  - Git HEAD or index changed: $p"
    continue
  fi
  case "$p" in
    .agents/*) BAD="$BAD
  - protected path changed: $p"; continue ;;
  esac
  grep -qxF -- "$p" "$TMP/allow" || BAD="$BAD
  - out of scope: $p"
done <<EOF
$CHANGED
EOF

if [ -n "$BAD" ]; then
  echo "GUARD_VIOLATION (agent exit $RC):$BAD" >&2
  echo "State snapshots kept in $TMP. Nothing was reverted automatically." >&2
  exit 2
fi
echo "GUARD_OK (agent exit $RC, changed paths: $(printf '%s' "$CHANGED" | grep -c . || true))"
echo "State snapshots retained in $TMP for audit; remove them through normal operator housekeeping."
exit "$RC"
}
main "$@"
