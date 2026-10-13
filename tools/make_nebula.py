#!/usr/bin/env python3
"""팔레트 맞춤 성운 PNG 생성 (stdlib만, 512x256, 투명 배경)."""
import math, random, struct, zlib, os

W, H = 512, 256
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "kenney", "nebula.png")
random.seed(42)

# 정수 해시 기반 value noise
def h2(x, y):
    n = (x * 374761393 + y * 668265263) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFFFFFF) / 4294967295.0

def smooth(t): return t * t * (3 - 2 * t)

def noise(x, y):
    xi, yi = int(math.floor(x)), int(math.floor(y))
    xf, yf = x - xi, y - yi
    a, b = h2(xi, yi), h2(xi + 1, yi)
    c, d = h2(xi, yi + 1), h2(xi + 1, yi + 1)
    u, v = smooth(xf), smooth(yf)
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v

def fbm(x, y):
    v, amp, f = 0.0, 0.55, 1.0
    for _ in range(4):
        v += amp * noise(x * f, y * f)
        amp *= 0.5; f *= 2.03
    return v

# 성운 덩어리 중심 3개 (보라/블루/틸)
blobs = [(0.30, 0.45, 0.34, (150, 70, 220)), (0.62, 0.55, 0.30, (60, 120, 230)), (0.82, 0.35, 0.22, (40, 220, 200))]

px = bytearray()
for j in range(H):
    for i in range(W):
        nx, ny = i / W * 3.0, j / H * 3.0
        d = fbm(nx, ny)
        r = g = b = a = 0.0
        for bx, by, br, col in blobs:
            dist = math.hypot(i / W - bx, (j / H - by) * 1.6)
            m = max(0.0, 1.0 - dist / br) ** 1.6 * (0.35 + 0.65 * d)
            r += col[0] * m; g += col[1] * m; b += col[2] * m
            a += m
        a = min(1.0, a * 0.85)
        # 가장자리 페이드 (타일 경계 은폐)
        edge = min(1.0, min(i, W - 1 - i) / 40.0, min(j, H - 1 - j) / 40.0)
        a *= max(0.0, edge)
        px += bytes((min(255, int(r)), min(255, int(g)), min(255, int(b)), int(a * 255)))

def chunk(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0)))
raw = b"".join(b"\x00" + bytes(px[r * W * 4:(r + 1) * W * 4]) for r in range(H))
png += chunk(b"IDAT", zlib.compress(bytes(raw), 6)) + chunk(b"IEND", b"")
open(OUT, "wb").write(png)
print("wrote", OUT, len(png) // 1024, "KB")
