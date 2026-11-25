from __future__ import annotations

import hashlib
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/device-tests"))
import visible_evidence as visible


class VisibleEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "original.png"
        self.source.write_bytes(b"captured evidence")
        self.digest = hashlib.sha256(self.source.read_bytes()).hexdigest()
        mock_root = patch.object(visible, "VISIBLE_ROOT", self.root / "LayerSort")
        mock_root.start()
        self.addCleanup(mock_root.stop)

    def test_copies_and_verifies_without_overwriting_previous_evidence(self):
        first = visible.publish(self.source, "screenshot", self.digest)
        second = visible.publish(self.source, "screenshot", self.digest)
        self.assertEqual(first["status"], "PASS")
        self.assertEqual(second["status"], "PASS")
        self.assertNotEqual(first["path"], second["path"])
        self.assertEqual(Path(first["path"]).read_bytes(), self.source.read_bytes())
        self.assertEqual(Path(second["path"]).read_bytes(), self.source.read_bytes())
        self.assertTrue(self.source.exists())

    def test_digest_mismatch_is_unknown_and_keeps_source(self):
        result = visible.publish(self.source, "screenshot", "a" * 64)
        self.assertEqual(result["status"], "UNKNOWN")
        self.assertTrue(self.source.exists())

    def test_rejects_wrong_kind_and_symbolic_link(self):
        self.assertEqual(visible.publish(self.source, "arbitrary", self.digest)["status"], "UNKNOWN")
        link = self.root / "link"
        link.symlink_to(self.source)
        self.assertEqual(visible.publish(link, "screenshot", self.digest)["status"], "UNKNOWN")

    def test_unavailable_visible_storage_is_unknown(self):
        visible.VISIBLE_ROOT.parent.joinpath("occupied").write_text("file")
        with patch.object(visible, "VISIBLE_ROOT", visible.VISIBLE_ROOT.parent / "occupied" / "child"):
            self.assertEqual(visible.publish(self.source, "screenshot", self.digest)["status"], "UNKNOWN")
        self.assertTrue(self.source.exists())


if __name__ == "__main__":
    unittest.main()
