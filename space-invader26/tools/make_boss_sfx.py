#!/usr/bin/env python3
"""보스 전용 SFX: 발사음(묵직 레이저) + 피격음(둔탁 쿵) -> assets/audio/*.wav"""
import math, random, struct, wave, os

SR = 22050
BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
random.seed(5)

def save(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    g = 0.9 / peak
    raw = b"".join(struct.pack("<h", int(max(-1, min(1, s * g)) * 32767)) for s in samples)
    with wave.open(os.path.join(BASE, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(raw)
    print(name, "%.2fs" % (len(samples) / SR))

# 발사: 300->120Hz 사각+톱 혼합, 0.18초, 무게감 있게
n = int(SR * 0.18); out = []; ph = 0.0
for i in range(n):
    t = i / SR; k = t / 0.18
    f = 300 + (120 - 300) * k
    ph += f / SR
    sq = 1.0 if (ph % 1.0) < 0.5 else -1.0
    sw = 2.0 * (ph % 1.0) - 1.0
    v = (sq * 0.6 + sw * 0.4) * 0.55 * math.exp(-3.5 * k)
    out.append(math.tanh(v * 1.5))
save("boss_shoot.wav", out)

# 피격: 120->55Hz 사인 쿵 + 노이즈, 0.13초, 금속성 없이 둔탁하게
n = int(SR * 0.13); out = []; last = 0.0
for i in range(n):
    t = i / SR; k = t / 0.13
    f = 120 + (55 - 120) * k
    v = math.sin(2 * math.pi * f * t) * math.exp(-9 * k)
    last += 0.2 * (random.uniform(-1, 1) - last)
    v += last * 0.4 * math.exp(-14 * k)
    out.append(math.tanh(v))
save("boss_hit.wav", out)
