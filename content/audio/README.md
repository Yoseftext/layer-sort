# Original Layer Sort audio

All six WAVs are original mathematical synthesis from `tools/assets/generate_ui_audio.py`, created by OpenAI Codex for Layer Sort. No external sample, recording, model output or downloaded asset was used. Generated waveforms are deliberately dedicated under **CC0-1.0** (see LICENSE.txt); no attribution required. Existing in-game credits identify the synthesis and CC0 URL. The asset license does not relicense unrelated project source.

Format: mono, 22,050 Hz, signed 16-bit PCM WAV. Optimizations: short durations, conservative peak, no loops, no soundtrack; four reusable AudioStreamPlayer voices. Godot uses its normal WAV importer; no native codec/plugin added. Reproduce: `python3 tools/assets/generate_ui_audio.py`; tests check formats, peaks and exact deterministic bytes. No dimensions apply to audio; sample counts follow duration × sample rate.

| Asset | Duration | Source bytes | PCM peak | SHA-256 |
|---|---:|---:|---:|---|
| `complete.wav` | 0.28s | 12392 | 0.121 | `3153266eaf519927ed2ab05e7b38e2aa88b0c9b3cbf99cb1c7df2d985ff1ea76` |
| `invalid.wav` | 0.09s | 4012 | 0.078 | `4964cc54fdb86989fe2b3312f7ea8d957352d2491416dd7e5f3c401dc74c27e9` |
| `pour.wav` | 0.26s | 11510 | 0.103 | `942af721d180cea56074de1802c54758a909f70703c519f60b6858fe839478e2` |
| `select.wav` | 0.08s | 3572 | 0.102 | `217c4c914aa4a066a2ea8e017f45f6eeffdc8d4a8ff86fd2e650b37b1d0a48cb` |
| `ui.wav` | 0.07s | 3130 | 0.129 | `9b1cf5928b7c30ece218831a7ab0431ca080b29da91916d41958c9971fbf3bff` |
| `win.wav` | 0.60s | 26504 | 0.105 | `972bafcb5bbb3dbe22ceb65b29ac8d7de5ecea3edd527d86819be8af6d8ccb52` |

Speaker quality, device volume, audio focus and latency still require owner/OPPO listening. Cloud Dummy audio tests verify routing/lifecycle, not acoustic acceptance.

Pour revision: seeded low-pass turbulence and five exponentially decaying bubble chirps; original synthesis, same CC0 dedication. 260 ms cue begins at actual transfer onset (25% of the 480 ms presentation), not the initial lift.

G5-Final P2: damped glass partials replace the gameplay stepped tones; a band-limited flow/noise bed and finite bubble resonances refine Pour. The win cue uses overlapping soft chord attacks. Gameplay cue gains are explicit and completion is quieter than win. UI navigation WAV remains byte-identical. Total six source WAVs: 61120 bytes. This is an original-synthesis revision with the existing CC0 dedication, no external assets or new runtime system. Technical format/envelope/routing tests do not prove subjective sound quality; final phone audition remains owner QA.
