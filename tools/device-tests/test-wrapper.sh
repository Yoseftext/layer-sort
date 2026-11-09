#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
exec /usr/bin/python3 -m unittest discover -s tests -p 'test_device_qa_wrapper.py' -v
