#!/usr/bin/env bash
# Hook failures must not silently permit the proposed tool call.
set +e
if command -v node >/dev/null 2>&1; then
  node scripts/policy.mjs
  status=$?
  if [ "$status" -eq 0 ]; then
    exit 0
  fi
fi
printf '%s\n' '{"decision":"deny","reason":"Policy engine failed; request denied closed."}'
exit 0
