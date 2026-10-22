"""Original synthesized game cues. Python standard library; no sampled recordings.
CC0-1.0 dedication by the project for these generated WAV assets.
"""
import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
ROOT.mkdir(parents=True, exist_ok=True)
CUES = {
    'select': [(880, .045)], 'undo': [(660, .04)],
    'shuffle': [(440, .055), (660, .055)],
    'correct': [(659.25, .085), (880, .13)],
    'extra': [(783.99, .07), (1046.5, .14)],
    'invalid': [(330, .08), (293.66, .10)],
    'reveal': [(587.33, .06), (783.99, .075), (1174.66, .12)],
    'victory': [(523.25, .10), (659.25, .10), (783.99, .11), (1046.5, .24)],
    'coins': [(1046.5, .06), (1318.5, .075), (1567.98, .10)],
}
for name, notes in CUES.items():
    samples = []
    for freq, duration in notes:
        count = int(44100 * duration)
        for i in range(count):
            time = i / 44100
            envelope = min(1, i / 180) * (1 - i / count) ** 1.7
            tone = math.sin(2 * math.pi * freq * time) + .15 * math.sin(4 * math.pi * freq * time)
            samples.append(int(9500 * envelope * tone))
    with wave.open(str(ROOT / f'{name}.wav'), 'wb') as out:
        out.setparams((1, 2, 44100, 0, 'NONE', 'not compressed'))
        out.writeframes(struct.pack('<' + 'h' * len(samples), *samples))
