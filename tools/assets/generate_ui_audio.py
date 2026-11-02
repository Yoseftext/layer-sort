#!/usr/bin/env python3
"""Original Layer Sort synthesis; generated WAVs are dedicated under CC0-1.0.
No samples, downloaded audio, AI model output or third-party libraries.
Run from repository root: python3 tools/assets/generate_ui_audio.py
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
CUES = {"select": (0.10, (660, 990)), "pour": (0.54, (240, 360)),
        "invalid": (0.12, (190, 155)), "complete": (0.34, (660, 880, 1320)),
        "win": (0.78, (523.25, 659.25, 783.99, 1046.5)), "ui": (0.07, (440, 660))}


def render(name, duration, notes):
    rng = random.Random(1407)
    pcm = []
    phase = 0.0
    for index in range(int(RATE * duration)):
        t = index / RATE
        note = notes[min(int(t / duration * len(notes)), len(notes) - 1)]
        # Rounded attack/release and restrained harmonics avoid sharp clicks.
        envelope = min(t / 0.014, 1.0) * min((duration - t) / 0.045, 1.0)
        phase += math.tau * note / RATE
        value = math.sin(phase) * 0.12
        value += math.sin(phase * 2) * 0.025
        if name == "pour":
            value = (math.sin(math.tau * (260 * t + 110 * t * t)) * 0.035
                     + rng.uniform(-1, 1) * 0.022) * (0.65 + 0.35 * math.sin(42 * t)**2)
        pcm.append(round(max(-0.22, min(0.22, value * envelope)) * 32767))
    path = Path("content/audio") / (name + ".wav")
    with wave.open(str(path), "wb") as output:
        output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        output.writeframes(struct.pack("<" + "h" * len(pcm), *pcm))


if __name__ == "__main__":
    for cue, (length, pitches) in CUES.items():
        render(cue, length, pitches)
