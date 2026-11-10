#!/usr/bin/env bash
set +e

deny() {
  printf '%s\n' '{"decision":"deny","reason":"Policy wrapper failed; request denied closed."}'
  exit 0
}

SCRIPT_DIR="${BASH_SOURCE%/*}"
if [ "$SCRIPT_DIR" = "$BASH_SOURCE" ]; then
  SCRIPT_DIR="."
fi
SCRIPT_DIR="$(cd -P -- "$SCRIPT_DIR" 2>/dev/null && pwd -P)" || deny
[ -f "$SCRIPT_DIR/policy.mjs" ] || deny

NODE_BIN="$(command -v node 2>/dev/null)"
[ -n "$NODE_BIN" ] || deny
case "$NODE_BIN" in
  /*) ;;
  *) deny ;;
esac
[ -x "$NODE_BIN" ] || deny

OUTPUT="$("$NODE_BIN" "$SCRIPT_DIR/policy.mjs" 2>/dev/null)"
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
