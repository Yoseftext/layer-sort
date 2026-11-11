#!/usr/bin/env bash
set +e

deny() {
  printf '%s\n' '{"decision":"deny","reason":"Policy wrapper failed; request denied closed."}'
  exit 0
}

# The hook must not trust PATH or inherited Node/Git loader configuration.
# Antigravity supplies the hook payload on stdin; the policy uses only Node built-ins.
unset NODE_OPTIONS NODE_PATH NODE_EXTRA_CA_CERTS NODE_V8_COVERAGE NODE_DEBUG
unset LD_PRELOAD LD_LIBRARY_PATH GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM
unset GIT_CONFIG_COUNT GIT_PAGER GIT_EXTERNAL_DIFF

SCRIPT_PATH="$BASH_SOURCE"
case "$SCRIPT_PATH" in
  /*/scripts/policy.sh) ;;
  *) deny ;;
esac
[ -f "$SCRIPT_PATH" ] && [ ! -L "$SCRIPT_PATH" ] || deny

PLUGIN_ROOT="${SCRIPT_PATH%/scripts/policy.sh}"
PLUGIN_ROOT="$(cd -- "$PLUGIN_ROOT" 2>/dev/null && pwd -P)" || deny
PROJECT_ROOT="/root/projects/layer-sort"
PROJECT_ROOT="$(cd -- "$PROJECT_ROOT" 2>/dev/null && pwd -P)" || deny
case "$PLUGIN_ROOT" in
  "$PROJECT_ROOT/.agents/plugins/layer-sort-agent-kit") ;;
  "$PROJECT_ROOT"/.worktrees/*/.agents/plugins/layer-sort-agent-kit) ;;
  *) deny ;;
esac

POLICY_PATH="$PLUGIN_ROOT/scripts/policy.mjs"
[ -f "$POLICY_PATH" ] && [ ! -L "$POLICY_PATH" ] || deny
[ -x /usr/bin/env ] && [ ! -L /usr/bin/env ] || deny
[ -x /usr/bin/timeout ] && [ ! -L /usr/bin/timeout ] || deny
[ -f /usr/bin/node ] && [ -x /usr/bin/node ] && [ ! -L /usr/bin/node ] || deny

OUTPUT="$(/usr/bin/env -i PATH=/usr/bin:/bin /usr/bin/timeout --signal=KILL 5s /usr/bin/env -i PATH=/usr/bin:/bin /usr/bin/node "$POLICY_PATH" 2>/dev/null)"
STATUS=$?
[ "$STATUS" -eq 0 ] || deny

case "$OUTPUT" in
  '{"decision":"allow"}')
    printf '%s\n' "$OUTPUT"
    ;;
  '{"decision":"deny","reason":'*)
    printf '%s\n' "$OUTPUT"
    ;;
  *)
    deny
    ;;
esac
