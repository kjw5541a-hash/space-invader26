#!/usr/bin/env python3
"""웅장+영웅 BGM (D minor epic, 112BPM, 8마디 루프) -> sounds/bgm.wav"""
import math, random, struct, wave, os

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sounds", "bgm.wav")
random.seed(11)

BPM = 112.0
BEAT = 60.0 / BPM
BAR = 4 * BEAT

# (bass_root, triad) x 8 bars: Dm Dm Bb Bb F F C C
CHORDS = [
    (73.42, (146.83, 174.61, 220.00)),
    (73.42, (146.83, 174.61, 220.00)),
    (58.27, (116.54, 146.83, 174.61)),
    (58.27, (116.54, 146.83, 174.61)),
    (87.31, (174.61, 220.00, 261.63)),
    (87.31, (174.61, 220.00, 261.63)),
    (65.41, (130.81, 164.81, 196.00)),
    (65.41, (130.81, 164.81, 196.00)),
]
# 영웅 모티프 (5~8마디, beat 단위)
MEL = [
    (16, 1, 587.33), (17, 1, 698.46), (18, 2, 880.00),
    (20, 2, 783.99), (22, 1, 698.46), (23, 1, 659.26),
    (24, 1, 698.46), (25, 1, 659.26), (26, 1, 587.33), (27, 1, 523.25),
    (28, 4, 587.33),
]

TOTAL = 8 * BAR
N = int(SR * TOTAL)
mix = [0.0] * N

def add(t0, samples, vol=1.0):
    s = int(t0 * SR)
    for i, v in enumerate(samples):
        j = s + i
        if 0 <= j < N:
            mix[j] += v * vol

def square(ph): return 1.0 if (ph % 1.0) < 0.5 else -1.0
def saw(ph): return 2.0 * (ph % 1.0) - 1.0
def soft(x): return math.tanh(1.4 * x) * 0.85

def tone(f, dur, wtype="square", vol=0.5, slide_to=None, attack=0.01, decay=2.0):
    n = int(SR * dur); o = []; ph = 0.0
    for i in range(n):
        t = i / SR; k = t / dur
        ff = f + (slide_to - f) * k if slide_to else f
        ph += ff / SR
        v = square(ph) if wtype == "square" else (saw(ph) if wtype == "saw" else math.sin(2 * math.pi * ph))
        env = min(1.0, t / max(attack, 1e-4)) * math.exp(-decay * k)
        o.append(v * vol * env)
    return o

def pad_tone(f, dur, vol=0.10):
    n = int(SR * dur); o = []; ph = [0.0, 0.0, 0.0]
    for i in range(n):
        t = i / SR; k = t / dur
        v = 0.0
        for d, det in enumerate((0.997, 1.0, 1.003)):
            ph[d] += f * det / SR
            v += saw(ph[d])
        v /= 3.0
        atk = min(1.0, t / 0.4)
        rel = min(1.0, (dur - t) / 0.3) if dur - t < 0.3 else 1.0
        o.append(v * vol * atk * rel)
    return o

def kick(t0, vol=0.9):
    add(t0, tone(130, 0.22, "sine", vol, slide_to=38, attack=0.003, decay=5.0))

def taiko(t0, vol=1.0):
    n = int(SR * 0.5); o = []; last = 0.0
    for i in range(n):
        t = i / SR; k = t / 0.5
        f = 95 + (32 - 95) * k
        v = math.sin(2 * math.pi * f * t) * math.exp(-4.5 * k)
        last += 0.25 * (random.uniform(-1, 1) - last)
        o.append((v + last * 0.5 * math.exp(-6 * k)) * vol)
    add(t0, o)

def snare(t0, vol=0.5):
    n = int(SR * 0.14); o = []; prev = 0.0
    for i in range(n):
        t = i / SR; k = t / 0.14
        x = random.uniform(-1, 1)
        hp = x - prev; prev = x
        v = hp * 0.8 + math.sin(2 * math.pi * 190 * t) * 0.35
        o.append(v * vol * math.exp(-9 * k))
    add(t0, o)

def crash(t0, vol=0.28):
    n = int(SR * 1.2); o = []; last = 0.0
    for i in range(n):
        t = i / SR
        last += 0.4 * (random.uniform(-1, 1) - last)
        o.append(last * vol * math.exp(-3.0 * t))
    add(t0, o)

for b in range(8):
    t0 = b * BAR
    root, tri = CHORDS[b]
    taiko(t0, 1.0 if b in (0, 4) else 0.7)
    if b == 0:
        crash(t0)
    for bi in range(4):
        kick(t0 + bi * BEAT, 0.9 if bi == 0 else 0.7)
        if bi in (1, 3):
            snare(t0 + bi * BEAT, 0.5)
    for e in range(8):
        f = root * (1.5 if e == 6 else 1.0)
        add(t0 + e * BEAT / 2, tone(f, 0.24, "square", 0.30 if e > 0 else 0.42, attack=0.005, decay=3.0))
    for f in tri:
        add(t0, pad_tone(f, BAR, 0.11))

for (sb, db, f) in MEL:
    t0 = sb * BEAT
    dur = db * BEAT
    add(t0, tone(f, dur, "square", 0.34, attack=0.02, decay=1.1))
    add(t0, tone(f * 2, dur, "sine", 0.12, attack=0.02, decay=1.1))

mix = [soft(v * 0.8) for v in mix]
peak = max(1e-6, max(abs(v) for v in mix))
g = 0.92 / peak
fade = int(SR * 0.03)
for i in range(fade):
    mix[i] *= i / fade; mix[-1 - i] *= i / fade
raw = b"".join(struct.pack("<h", int(max(-1, min(1, v * g)) * 32767)) for v in mix)
with wave.open(OUT, "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(raw)
print("bgm epic %.1fs -> %s" % (TOTAL, OUT))
