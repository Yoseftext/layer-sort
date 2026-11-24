from __future__ import annotations

import importlib.util
import importlib.metadata
import os
import random
import struct
import tempfile
import unittest
import zlib
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("visual_match", ROOT / "tools/visual-qa/visual_match.py")
assert SPEC and SPEC.loader
visual = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(visual)
try:
    HAS_CV = (importlib.metadata.version("opencv-python-headless") == "4.12.0.88" and
              importlib.metadata.version("numpy") == "2.2.6")
except importlib.metadata.PackageNotFoundError:
    HAS_CV = False
RUN = "20261124T123456.123456Z"


def png(pixels: list[list[int]]) -> bytes:
    height, width = len(pixels), len(pixels[0])
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
    rows = b"".join(b"\x00" + bytes(row) for row in pixels)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 0, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))


class VisualTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.screens = self.root / ".runtime/device-qa"
        self.templates = self.root / "tools/visual-qa/templates"
        (self.screens / RUN).mkdir(parents=True)
        self.templates.mkdir(parents=True)
        self.patches = [patch.object(visual, "ROOT", self.root), patch.object(visual, "SCREENSHOTS", self.screens),
                        patch.object(visual, "TEMPLATES", self.templates)]
        for item in self.patches:
            item.start()
            self.addCleanup(item.stop)
        rng = random.Random(9)
        self.screen = [[rng.randrange(256) for _ in range(50)] for _ in range(40)]
        self.template = [row[13:21] for row in self.screen[9:16]]
        (self.screens / RUN / "screen.png").write_bytes(png(self.screen))
        (self.templates / "target.png").write_bytes(png(self.template))

    def test_reads_only_bounded_png_from_fixed_directory(self) -> None:
        data, width, height = visual.safe_png(self.screens, self.screens / RUN / "screen.png")
        self.assertEqual((width, height), (50, 40))
        self.assertTrue(data.startswith(b"\x89PNG"))
        with self.assertRaises(visual.VisualError):
            visual.safe_png(self.templates, self.screens / RUN / "screen.png")
        for run, template in (("../../outside", "target"), (RUN, "../outside"), (RUN, "TARGET")):
            with self.subTest(run=run, template=template), self.assertRaises(visual.VisualError):
                visual.match(run, template)

    def test_rejects_symlink_and_hardlink_image(self) -> None:
        image = self.templates / "target.png"
        image.unlink()
        image.symlink_to(self.screens / RUN / "screen.png")
        with self.assertRaises(visual.VisualError):
            visual.safe_png(self.templates, image)
        image.unlink()
        os.link(self.screens / RUN / "screen.png", image)
        with self.assertRaises(visual.VisualError):
            visual.safe_png(self.templates, image)

    def test_rejects_large_dimensions_and_larger_template(self) -> None:
        image = self.templates / "target.png"
        image.write_bytes(b"\x89PNG\r\n\x1a\n" + b"\x00\x00\x00\x0dIHDR" + struct.pack(">II", 8192, 8192))
        with self.assertRaises(visual.VisualError):
            visual.safe_png(self.templates, image)
        image.write_bytes(png([[1] * 51 for _ in range(2)]))
        with self.assertRaisesRegex(visual.VisualError, "larger than"):
            visual.match(RUN, "target")

    @unittest.skipUnless(HAS_CV, "optional locked OpenCV/NumPy not installed")
    def test_real_match_finds_unique_pattern_without_claiming_gameplay_pass(self) -> None:
        result = visual.match(RUN, "target")
        self.assertEqual((result["best_match"]["x"], result["best_match"]["y"]), (13, 9))
        self.assertGreater(result["best_match"]["score"], 0.99)
        self.assertEqual(result["visual_verdict"], "UNVERIFIED")
        self.assertFalse(result["device_contacted"])
        self.assertFalse(result["input_executed"])

    @unittest.skipUnless(HAS_CV, "optional locked OpenCV/NumPy not installed")
    def test_real_match_rejects_uniform_template(self) -> None:
        (self.templates / "target.png").write_bytes(png([[5] * 5 for _ in range(5)]))
        with self.assertRaisesRegex(visual.VisualError, "too uniform"):
            visual.match(RUN, "target")


if __name__ == "__main__":
    unittest.main()
