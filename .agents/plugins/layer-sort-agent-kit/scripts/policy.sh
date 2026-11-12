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

# Workspace hooks use a workspace-relative command. Resolve it from the hook CWD,
# then reject lexical aliases and symlinked path components before starting Node.
SCRIPT_PATH="$BASH_SOURCE"
case "$SCRIPT_PATH" in
  /*) ;;
  *)
    SCRIPT_CWD="$(pwd -P 2>/dev/null)" || deny
    SCRIPT_PATH="$SCRIPT_CWD/$SCRIPT_PATH"
    ;;
esac

case "$SCRIPT_PATH" in
  */.agents/plugins/layer-sort-agent-kit/scripts/policy.sh) ;;
  *) deny ;;
esac
[ -f "$SCRIPT_PATH" ] && [ ! -L "$SCRIPT_PATH" ] || deny

SCRIPT_DIR="${SCRIPT_PATH%/policy.sh}"
SCRIPT_DIR="$(cd -- "$SCRIPT_DIR" 2>/dev/null && pwd -P)" || deny
[ "$SCRIPT_PATH" = "$SCRIPT_DIR/policy.sh" ] || deny

case "$SCRIPT_DIR" in
  */.agents/plugins/layer-sort-agent-kit/scripts) ;;
  *) deny ;;
esac
WORKSPACE_ROOT="${SCRIPT_DIR%/.agents/plugins/layer-sort-agent-kit/scripts}"
[ -n "$WORKSPACE_ROOT" ] || deny
[ "$SCRIPT_DIR" = "$WORKSPACE_ROOT/.agents/plugins/layer-sort-agent-kit/scripts" ] || deny

for DIRECTORY in \
  "$WORKSPACE_ROOT" \
  "$WORKSPACE_ROOT/.agents" \
  "$WORKSPACE_ROOT/.agents/plugins" \
  "$WORKSPACE_ROOT/.agents/plugins/layer-sort-agent-kit" \
  "$SCRIPT_DIR"
do
  [ -d "$DIRECTORY" ] && [ ! -L "$DIRECTORY" ] || deny
  DIRECTORY_REAL="$(cd -- "$DIRECTORY" 2>/dev/null && pwd -P)" || deny
  [ "$DIRECTORY_REAL" = "$DIRECTORY" ] || deny
done

POLICY_PATH="$SCRIPT_DIR/policy.mjs"
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
