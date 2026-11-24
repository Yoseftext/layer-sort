#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export CI=true
export GIT_TERMINAL_PROMPT=0
export GCM_INTERACTIVE=Never
export NO_COLOR=1
export TERM=dumb
export SAFE_AGY_TEST_SCOPE=compatibility
for name in ${!LD_@}; do
  if [ -n "${!name}" ]; then
    echo "SAFE_AGY_COMPATIBILITY_UNKNOWN: unsafe dynamic-loader environment variable set: $name" >&2
    exit 78
  fi
done
for name in NODE_OPTIONS NODE_PATH BASH_ENV; do
  if [ -n "${!name-}" ]; then
    echo "SAFE_AGY_COMPATIBILITY_UNKNOWN: unsafe Node/Bash startup environment variable set: $name" >&2
    exit 78
  fi
done
node --check "$DIR/compatibility.mjs"
node --check "$DIR/runtime-config.mjs"
node --check "$DIR/test-active-compatibility.mjs"
node --check "$DIR/test-launcher.mjs"
node --check "$DIR/test-runtime-config.mjs"
case "${1:---unit}" in
  --unit)
    exec node --test "$DIR/test-compatibility.mjs"
    ;;
  --regression)
    exec node --test "$DIR/test-compatibility.mjs" "$DIR/test-state.mjs" "$DIR/test-runtime-config.mjs" "$DIR/test-launcher.mjs"
    ;;
  --status)
    exec node "$DIR/compatibility.mjs" --status "${2:-$PWD}"
    ;;
  --active)
    node --test "$DIR/test-compatibility.mjs" "$DIR/test-state.mjs" "$DIR/test-runtime-config.mjs" "$DIR/test-launcher.mjs"
    exec node "$DIR/test-active-compatibility.mjs" "${@:2}"
    ;;
  *)
    echo "Usage: test-compatibility.sh [--unit|--regression|--active <project-root>|--status <project-root>]" >&2
    exit 64
    ;;
esac
