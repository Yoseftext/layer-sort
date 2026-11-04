#!/usr/bin/env python3
"""Original Layer Sort synthesis; WAVs dedicated under CC0-1.0.
No samples, downloaded audio, AI model output or third-party libraries.
Run from repository root: python3 tools/assets/generate_ui_audio.py
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
CUES = {"select": (0.08, (880, 1420)), "pour": (0.26, ()),
        "invalid": (0.09, (190, 330)), "complete": (0.28, (880, 1320)),
        "win": (0.60, (523.25, 659.25, 783.99)), "ui": (0.07, (440, 660))}


def glass(t, notes, decay):
    # Damped partials rather than a sustained electronic note/stepped arpeggio.
    return sum(math.sin(math.tau * frequency * t) * math.exp(-t * decay * (1 + i * 0.4)) / (1 + i * 2)
               for i, frequency in enumerate(notes))


def render(name, duration, notes):
    rng = random.Random(1407)
    pcm = []
    low = slow = phase = 0.0
    for index in range(int(RATE * duration)):
        t = index / RATE
        envelope = min(t / 0.012, 1.0) * min((duration - t) / 0.035, 1.0)
        if name == "ui":
            # Preserve the existing navigation sound exactly; gameplay-only slice.
            note = notes[min(int(t / duration * len(notes)), len(notes) - 1)]
            phase += math.tau * note / RATE
            value = math.sin(phase) * 0.12 + math.sin(phase * 2) * 0.025
            envelope = min(t / 0.014, 1.0) * min((duration - t) / 0.045, 1.0)
        elif name == "pour":
            # Band-limited turbulence with finite bubble resonances and a quiet
            # glass body. No periodic fundamental or white-noise hiss on its own.
            low += 0.28 * (rng.uniform(-1, 1) - low)
            slow += 0.025 * (low - slow)
            value = 0.15 * (low - slow) * (0.85 + 0.15 * math.sin(t * 31))
            for onset, pitch in [(0.012, 720), (0.052, 1080), (0.097, 830), (0.145, 1230), (0.202, 670)]:
                age = t - onset
                if age >= 0:
                    attack = min(age / 0.004, 1.0)
                    value += 0.035 * attack * math.exp(-age * 80) * math.sin(math.tau * pitch * (age - age * age * 1.4))
            value += glass(t, (1560, 2390), 35) * 0.008
        elif name == "win":
            value = 0.0
            for i, note in enumerate(notes):
                age = t - i * 0.07
                if age >= 0:
                    value += min(age / 0.015, 1.0) * glass(age, (note, note * 2.01), 8) * 0.065
        else:
            value = glass(t, notes, {"select": 48, "invalid": 40, "complete": 16}[name])
            value *= {"select": 0.15, "invalid": 0.11, "complete": 0.12}[name]
        pcm.append(round(max(-0.22, min(0.22, value * envelope)) * 32767))
    path = Path("content/audio") / (name + ".wav")
    with wave.open(str(path), "wb") as output:
        output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        output.writeframes(struct.pack("<" + "h" * len(pcm), *pcm))


if __name__ == "__main__":
    for cue, (length, pitches) in CUES.items():
        render(cue, length, pitches)
