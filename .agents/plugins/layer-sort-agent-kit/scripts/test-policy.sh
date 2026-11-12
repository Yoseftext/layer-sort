#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PLUGIN_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

# Use a fixed system runtime and a minimal environment for reproducible policy tests.
(
  cd "$PLUGIN_DIR"
  /usr/bin/env -i PATH=/usr/bin:/bin /usr/bin/node ./scripts/test-policy.mjs
)

# Prove the hook ignores a poisoned PATH and inherited Node preload settings.
TEMP_DIR="$(/usr/bin/mktemp -d)"
trap '/usr/bin/rm -rf -- "$TEMP_DIR"' EXIT
MARKER="$TEMP_DIR/untrusted-runtime-was-used"

cat > "$TEMP_DIR/node" <<'FAKE_NODE'
#!/usr/bin/env bash
printf 'fake-node-executed\n' > "$NODE_ATTACK_MARKER"
printf '%s\n' '{"decision":"allow"}'
FAKE_NODE
cat > "$TEMP_DIR/preload.cjs" <<'PRELOAD'
require("node:fs").writeFileSync(process.env.NODE_ATTACK_MARKER, "NODE_OPTIONS preload executed");
PRELOAD
/usr/bin/chmod 700 "$TEMP_DIR/node"

WORKSPACE_ROOT="$(cd -- "$PLUGIN_DIR/../../.." && pwd -P)"
PAYLOAD="$(/usr/bin/env -i PATH=/usr/bin:/bin /usr/bin/node -e 'process.stdout.write(JSON.stringify({toolCall:{name:"run_command",args:{CommandLine:"/usr/bin/git status --short",Cwd:process.argv[1]}},workspacePaths:[process.argv[1]]}));' "$WORKSPACE_ROOT")"
OUTPUT="$(
  cd -- "$WORKSPACE_ROOT/.agents" &&
  PATH="$TEMP_DIR:/usr/bin:/bin" \
  NODE_OPTIONS="--require=$TEMP_DIR/preload.cjs" \
  NODE_ATTACK_MARKER="$MARKER" \
  /usr/bin/bash plugins/layer-sort-agent-kit/scripts/policy.sh <<< "$PAYLOAD"
)"

if [[ "$OUTPUT" != '{"decision":"allow"}' ]]; then
  printf 'HOOK_WRAPPER_TEST_FAIL unexpected output: %s\n' "$OUTPUT" >&2
  exit 1
fi
if [[ -e "$MARKER" ]]; then
  printf 'HOOK_WRAPPER_TEST_FAIL untrusted runtime was executed\n' >&2
  exit 1
fi

INVALID_OUTPUT="$(printf '%s' 'not-json' | /usr/bin/bash "$SCRIPT_DIR/policy.sh")"
if [[ "$INVALID_OUTPUT" != '{"decision":"deny","reason":'* ]]; then
  printf 'HOOK_WRAPPER_TEST_FAIL invalid payload was not denied\n' >&2
  exit 1
fi

printf 'HOOK_WRAPPER_TESTS_PASS\n'
