#!/usr/bin/env python3
"""적 사격음: 낮고 은은한 블립 -> assets/audio/eshoot.wav"""
import math, struct, wave, os

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "eshoot.wav")
DUR = 0.16
n = int(SR * DUR)
out = []
for i in range(n):
    t = i / SR; k = t / DUR
    f = 150 + (85 - 150) * k
    v = math.sin(2 * math.pi * f * t) + 0.25 * math.sin(4 * math.pi * f * t)
    out.append(math.tanh(v * 0.5) * 0.30 * math.exp(-5.0 * k))
peak = max(abs(v) for v in out)
g = 0.85 / peak
raw = b"".join(struct.pack("<h", int(max(-1, min(1, v * g)) * 32767)) for v in out)
with wave.open(OUT, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(raw)
print("eshoot low blip ->", OUT)
