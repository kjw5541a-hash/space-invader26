#!/usr/bin/env python3
"""Neon Space Invader SFX/BGM generator - pure stdlib, 22050Hz 16-bit mono WAV."""
import math, random, struct, wave, os

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sounds")
os.makedirs(OUT, exist_ok=True)
random.seed(7)

def save(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    g = 0.92 / peak
    raw = b"".join(struct.pack("<h", int(max(-1, min(1, s * g)) * 32767)) for s in samples)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(raw)
    print(name, len(samples) / SR, "s")

def env_ad(n, a=0.005, d=0.08):
    e = []
    for i in range(n):
        t = i / SR
        v = min(1.0, t / a) * math.exp(-t / max(d, 1e-4))
        e.append(v)
    return e

def square(ph): return 1.0 if (ph % 1.0) < 0.5 else -1.0
def soft_clip(x): return math.tanh(1.6 * x) * 0.8

def sweep(f0, f1, dur, wtype="square", vol=0.6, vib=0.0, vib_rate=30.0):
    n = int(SR * dur); out = []; ph = 0.0
    e = env_ad(n, d=dur * 0.9)
    for i in range(n):
        t = i / SR; k = t / dur
        f = f0 + (f1 - f0) * k
        if vib: f *= 1.0 + vib * math.sin(2 * math.pi * vib_rate * t)
        ph += f / SR
        if wtype == "square": v = square(ph)
        elif wtype == "saw": v = 2.0 * (ph % 1.0) - 1.0
        else: v = math.sin(2 * math.pi * ph)
        v += 0.25 * math.sin(4 * math.pi * ph)  # harmonic richness
        out.append(soft_clip(v * vol) * e[i])
    return out

def noise_burst(dur, vol=0.8, lp_from=6000, lp_to=400, sub_from=110, sub_to=32):
    n = int(SR * dur); out = []
    last = 0.0
    for i in range(n):
        t = i / SR; k = t / dur
        cutoff = lp_from + (lp_to - lp_from) * k
        a = max(0.02, min(0.9, cutoff / SR))
        last = last + a * (random.uniform(-1, 1) - last)
        sub_f = sub_from + (sub_to - sub_from) * k
        sub = math.sin(2 * math.pi * sub_f * t) * (1 - k)
        v = last * 1.4 + sub * 0.8
        out.append(soft_clip(v * vol) * math.exp(-3.2 * k))
    return out

def arp(notes, note_dur=0.1, wtype="square", vol=0.5):
    out = []
    for f in notes:
        out += sweep(f, f, note_dur, wtype, vol)
    return out

# 1. player shoot: bright laser sweep down
save("shoot.wav", sweep(980, 480, 0.12, "square", 0.55))
# 2. enemy shoot: darker zap
save("enemy_shoot.wav", sweep(330, 130, 0.16, "saw", 0.45))
# 3. explosion: noise + sub drop
save("explosion.wav", noise_burst(0.45))
# 4. player hit: heavy distorted thud
a = sweep(150, 55, 0.32, "square", 0.7)
b = noise_burst(0.3, 0.5)
save("hit.wav", [x + y * 0.6 for x, y in zip(a + [0]*(len(b)-len(a)), b + [0]*(len(a)-len(b)))])
# 5. wave clear: rising arp C5 E5 G5 C6
save("wave.wav", arp([523.25, 659.25, 783.99, 1046.5], 0.1))
# 6. boss warning: alarm x3
w = []
for _ in range(3):
    w += sweep(233, 233, 0.14, "square", 0.5)
    w += sweep(349, 349, 0.14, "square", 0.5)
save("boss.wav", w)
# 7. game over: descending with vibrato
save("gameover.wav", sweep(440, 105, 0.95, "saw", 0.5, vib=0.02, vib_rate=22))
# 8. power/down blip reuse: enemy hit tick
save("tick.wav", sweep(700, 700, 0.05, "square", 0.4))

# 9. BGM: 8s chiptune loop, 140 BPM, Am-F-C-G
bpm = 140; beat = 60.0 / bpm
bassline = [110, 110, 131, 87, 130.8, 130.8, 98, 98]  # A A C G... approx
arp_notes = [220, 261.6, 329.6, 440, 349.2, 440, 523.25, 392]
bars = int(8.0 / (beat * len(bassline) / 2)) + 1
seq_len = int(SR * 8.0)
bgm = [0.0] * seq_len
step = beat / 2
idx = 0; t = 0.0
bi = 0
while t < 8.0:
    f = bassline[bi % len(bassline)]
    dur = step
    n = int(SR * dur)
    start = int(t * SR)
    ph = 0.0
    for i in range(n):
        if start + i >= seq_len: break
        ph += f / SR
        v = square(ph) * 0.30 + math.sin(2 * math.pi * ph) * 0.15
        bgm[start + i] += v * math.exp(-2.0 * (i / SR) / dur)
    # hats
    hn = int(SR * 0.03); hs = int((t + step / 2) * SR)
    for i in range(hn):
        if hs + i >= seq_len: break
        bgm[hs + i] += random.uniform(-1, 1) * 0.08 * math.exp(-i / (SR * 0.01))
    # sparkle arp every 2 steps
    if bi % 2 == 0:
        af = arp_notes[(bi // 2) % len(arp_notes)] * 2
        an = int(SR * 0.12); astart = start
        ph2 = 0.0
        for i in range(an):
            if astart + i >= seq_len: break
            ph2 += af / SR
            bgm[astart + i] += (math.sin(2 * math.pi * ph2) * 0.12) * math.exp(-6 * i / an)
    t += step; bi += 1
bgm = [soft_clip(v * 0.7) for v in bgm]
# short fade at loop edges to avoid click
fade = int(SR * 0.02)
for i in range(fade):
    bgm[i] *= i / fade; bgm[-1 - i] *= i / fade
save("bgm.wav", bgm)
print("done ->", OUT)
