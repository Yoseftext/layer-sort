#!/usr/bin/bash
set -Eeuo pipefail
SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
cd "$ROOT"
exec /usr/bin/python3.13 -I -m unittest discover -s tests -p 'test_device_qa_wrapper.py' -v
