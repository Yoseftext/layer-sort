# Optional visual matching

This project-local, offline screenshot helper compares one saved PNG against a
reviewed PNG template with OpenCV. It does not capture a screen, launch or tap
anything, or decide whether the game is correct. A match score and bounding box
are evidence for human/model review, not a gameplay PASS or a click instruction.

## Reproduce the isolated environment

On Linux CPython 3.13, aarch64 or x86_64, from this worktree:

```sh
python3 -m venv .runtime/visual-qa/venv
PIP_NO_INPUT=1 .runtime/visual-qa/venv/bin/python -m pip install --disable-pip-version-check --no-cache-dir --only-binary=:all: --require-hashes --index-url https://pypi.org/simple -r tools/visual-qa/requirements-py313-linux.txt
.runtime/visual-qa/venv/bin/python -I -m unittest discover -s tests -p test_device_qa_visual.py -v
```

This leaves the system Python and existing Appium virtualenv unchanged. The
lockfile accepts only the enumerated PyPI wheel SHA-256 hashes for NumPy 2.2.6
and OpenCV headless 4.12.0.88 on those platforms. A different Python/platform
must produce `UNVERIFIED` until separately pinned and tested. On this PRoot host,
installation and all five visual unit tests passed on synthetic PNGs; no actual
Layer Sort screenshot has been analyzed yet. As with the rest of this same-user
workspace, the Hook is not an OS sandbox; the local venv is not protected from
other processes running as the same user.

OpenCV is Apache-2.0; the Python wheel build scripts are MIT and the wheels
include third-party components, including LGPL-2.1 FFmpeg. See the upstream
[wheel licensing](https://github.com/opencv/opencv-python#licensing) and the
[third-party notices](https://github.com/opencv/opencv-python/blob/4.x/LICENSE-3RD-PARTY.txt).
NumPy is BSD-3-Clause with bundled-library notices available in its wheel.
These tools remain development-only; do not package them into the game APK.
To disable the optional tool, stop invoking it; retain evidence and the isolated
environment until the owner decides to remove them.

## Use after a real screenshot and a reviewed template exist

```sh
tools/device-tests/agentctl visual-match --run 20261124T123456.123456Z --template tube_1
```

The example run ID and template are placeholders. The run ID must correspond
to `.runtime/device-qa/<run>/screen.png`; the reference must be a reviewed
`tools/visual-qa/templates/<name>.png`. See `templates/README.md`. Neither
arbitrary file paths nor URL inputs are accepted. Input is capped at 16 MiB,
4 megapixels and 8192 pixels per side, and OpenCV is limited to one thread.
The tool rejects a uniform template; similar objects, animation or scaling can
still cause false matches. Preserve the hashes and compare with state/log
oracles. The tool reports screenshot origin and the qualitative verdict as
`UNVERIFIED` even when calculation succeeds.
