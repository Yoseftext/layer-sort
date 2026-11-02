# Original Layer Sort audio

All six WAVs are original mathematical synthesis from `tools/assets/generate_ui_audio.py`, created by OpenAI Codex for Layer Sort. No external sample, recording, model output or downloaded asset was used. Generated waveforms are deliberately dedicated under **CC0-1.0** (see LICENSE.txt); no attribution required. Existing in-game credits identify the synthesis and CC0 URL. The asset license does not relicense unrelated project source.

Format: mono, 22,050 Hz, signed 16-bit PCM WAV. Optimizations: short durations, conservative peak, no loops, no soundtrack; four reusable AudioStreamPlayer voices. Godot uses its normal WAV importer; no native codec/plugin added. Reproduce: `python3 tools/assets/generate_ui_audio.py`; tests check formats, peaks and exact deterministic bytes. No dimensions apply to audio; sample counts follow duration × sample rate.

| Asset | Duration | Source bytes | PCM peak | SHA-256 |
|---|---:|---:|---:|---|
| `complete.wav` | 0.34s | 15038 | 0.129 | `a175449721636feb1ef16800268e4859f5b54b1382d33c9940e8fc08ceccc9a2` |
| `invalid.wav` | 0.12s | 5336 | 0.129 | `bde041b803901121dfaf7a4c166a9397bad78e08940b1696ebcccb3b7d6d94da` |
| `pour.wav` | 0.54s | 23858 | 0.057 | `bbf931394327d9fac622f79586c4584699d8df323e5e2c14b8e2ef5c73045272` |
| `select.wav` | 0.10s | 4454 | 0.129 | `97e6dd23230cedb29eaeb02a83140bfcd41e45257f6cd7ccd25542868ddebb25` |
| `ui.wav` | 0.07s | 3130 | 0.129 | `9b1cf5928b7c30ece218831a7ab0431ca080b29da91916d41958c9971fbf3bff` |
| `win.wav` | 0.78s | 34442 | 0.129 | `eaeb1e9d72693a263c40030b44c1f61e2467b6fb7665c31547731a764c67382e` |

Speaker quality, device volume, audio focus and latency still require owner/OPPO listening. Cloud Dummy audio tests verify routing/lifecycle, not acoustic acceptance.
