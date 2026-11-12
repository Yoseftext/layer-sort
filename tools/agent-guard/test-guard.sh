#!/usr/bin/env bash
# Tests for safe-agy.sh. Uses a throwaway repo under /root/agent-policy/guard-tests-<ts>.
# Never touches the real worktrees or the installed plugin (preflight only reads them).
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SAFE="$DIR/safe-agy.sh"
FAKES="$DIR/fakes"
ROOT="/root/agent-policy/guard-tests-$(date +%s)"
TR="$ROOT/repo"
mkdir -p "$TR"
git -C "$TR" init -q
echo base > "$TR/base.txt"
git -C "$TR" add base.txt
git -C "$TR" -c user.email=t@example.com -c user.name=guard-test commit -qm base
BASE="$(git -C "$TR" rev-parse HEAD)"
ALLOW="$ROOT/allow.txt"
echo allowed.txt > "$ALLOW"
echo "{\"x\":1}" > "$ROOT/bad-hooks.json"
mkdir -p "$ROOT/fsnap/scripts"
echo bad > "$ROOT/fsnap/scripts/policy.sh"
echo bad > "$ROOT/fsnap/scripts/policy.mjs"
echo "0000  ./scripts/policy.sh" > "$ROOT/fsnap/MANIFEST.sha256"

PASS=0; FAILS=0
check() {
  if [ "$2" = "$3" ]; then echo "PASS $1 (got $3)"; PASS=$((PASS+1))
  else echo "FAIL $1 (want $2, got $3)"; FAILS=$((FAILS+1)); fi
}
reset_repo() { git -C "$TR" reset -q --hard "$BASE"; git -C "$TR" clean -fdq; }
run() { # $1=agy fake, rest = extra env assignments
  local fake="$1"; shift
  env SAFE_TOGGLE=0 "$@" AGY_BIN=bash bash "$SAFE" "$TR" "$ALLOW" -- "$fake" >"$ROOT/out.txt" 2>"$ROOT/err.txt"
  RC=$?; [ -f "$TR/allowed.txt" ] && PRESENT=yes || PRESENT=no
  reset_repo
}

# 1. Clean run: agent writes only allowlisted file -> allowed.
run "$FAKES/fake-ok.sh" X=1
check "allowlisted write passes" 0 "$RC"

# 2. Out-of-scope write -> violation.
run "$FAKES/fake-bad.sh" X=1
check "out-of-scope write is flagged" 2 "$RC"

# 3. Commit made by agent -> violation (HEAD moved).
run "$FAKES/fake-commit.sh" X=1
check "agent commit is flagged" 2 "$RC"

# 4. Write under .agents/ -> protected violation.
run "$FAKES/fake-agents.sh" X=1
check ".agents write is flagged" 2 "$RC"

# 5. Missing pinned snapshot -> refuse to start; agent must NOT run.
run "$FAKES/fake-ok.sh" SNAP_DIR=/nonexistent/snap
check "missing snapshot blocks start" 3 "$RC"
AGENT_RAN="$PRESENT"
check "agent not executed when blocked" no "$AGENT_RAN"

# 6. Tampered snapshot (manifest mismatch) -> refuse to start.
run "$FAKES/fake-ok.sh" SNAP_DIR="$ROOT/fsnap"
check "tampered snapshot blocks start" 3 "$RC"

# 7. Plugin hook not wired to pinned snapshot -> refuse to start.
run "$FAKES/fake-ok.sh" PLUGIN_HOOKS="$ROOT/bad-hooks.json"
check "unwired hook blocks start" 3 "$RC"

# 8. Sanity: the real pinned setup must pass preflight (read-only check).
run "$FAKES/fake-ok.sh" X=1
check "real pinned setup passes preflight" 0 "$RC"

echo "RESULT: pass=$PASS fail=$FAILS"
[ "$FAILS" -eq 0 ] && echo GUARD_TESTS_PASS || echo GUARD_TESTS_FAIL
exit "$FAILS"
