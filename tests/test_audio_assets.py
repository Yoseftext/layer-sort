import hashlib
import importlib.util
import os
import struct
import tempfile
import unittest
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('audio_source', ROOT / 'tools/assets/generate_ui_audio.py')
source = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source)


class AudioAssetTests(unittest.TestCase):
    def test_bounded_mono_pcm_and_peak(self):
        for name, (duration, _) in source.CUES.items():
            with self.subTest(cue=name), wave.open(str(ROOT / 'content/audio' / (name + '.wav'))) as audio:
                self.assertEqual((audio.getnchannels(), audio.getsampwidth(), audio.getframerate()), (1, 2, 22050))
                self.assertLessEqual(audio.getnframes(), 22050)
                self.assertEqual(audio.getnframes(), int(22050 * duration))
                samples = struct.unpack('<' + 'h' * audio.getnframes(), audio.readframes(audio.getnframes()))
                self.assertGreater(max(map(abs, samples)), 0)
                self.assertLessEqual(max(map(abs, samples)), round(0.22 * 32767))

    def test_assets_reproduce_from_original_source(self):
        previous = Path.cwd()
        with tempfile.TemporaryDirectory() as temporary:
            try:
                os.chdir(temporary)
                Path('content/audio').mkdir(parents=True)
                for name, (duration, notes) in source.CUES.items():
                    source.render(name, duration, notes)
                    generated = Path('content/audio', name + '.wav').read_bytes()
                    expected = (ROOT / 'content/audio' / (name + '.wav')).read_bytes()
                    self.assertEqual(hashlib.sha256(generated).digest(), hashlib.sha256(expected).digest())
            finally:
                os.chdir(previous)
