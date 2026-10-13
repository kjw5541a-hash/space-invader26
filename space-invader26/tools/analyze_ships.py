#!/usr/bin/env python3
"""Kenney craft OBJ 분석: bbox + 재질별 z-centroid (기수 방향 판정용)."""
import sys, os

def analyze(path):
    verts = [(0.0, 0.0, 0.0)]
    cur = None
    per = {}
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            if line.startswith("v "):
                _, x, y, z = line.split()[:4]
                verts.append((float(x), float(y), float(z)))
            elif line.startswith("usemtl"):
                cur = line.split(None, 1)[1].strip()
            elif line.startswith("f "):
                idx = [int(p.split("/")[0]) for p in line.split()[1:]]
                for vi in idx:
                    per.setdefault(cur, []).append(verts[vi])
    allv = [v for vs in per.values() for v in vs]
    xs = [v[0] for v in allv]; ys = [v[1] for v in allv]; zs = [v[2] for v in allv]
    print("== %s  n=%d" % (os.path.basename(path), len(allv)))
    print("   bbox x[%.2f,%.2f] y[%.2f,%.2f] z[%.2f,%.2f]" % (
        min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))
    for m, vs in per.items():
        mz = sum(v[2] for v in vs) / len(vs)
        my = sum(v[1] for v in vs) / len(vs)
        print("   %-10s n=%5d zc=%+.2f yc=%+.2f" % (m, len(vs), mz, my))

base = sys.argv[1]
for n in ["craft_racer", "craft_speederA", "craft_speederB", "craft_speederC",
          "craft_speederD", "craft_miner", "craft_cargoA", "craft_cargoB"]:
    analyze(os.path.join(base, n + ".obj"))
