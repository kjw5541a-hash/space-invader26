#!/usr/bin/env python3
"""TTF cmap에서 필요한 글리프 포함 여부 확인 (stdlib만)."""
import struct, sys

path = sys.argv[1] if len(sys.argv) > 1 else "fonts/NanumGothic-Bold.ttf"
data = open(path, "rb").read()

num_tables = struct.unpack(">H", data[4:6])[0]
tables = {}
for i in range(num_tables):
    off = 12 + i * 16
    tag = data[off:off + 4].decode("latin1")
    tbl_off = struct.unpack(">L", data[off + 8:off + 12])[0]
    tbl_len = struct.unpack(">L", data[off + 12:off + 16])[0]
    tables[tag] = (tbl_off, tbl_len)

coff, _ = tables["cmap"]
ncmap = struct.unpack(">H", data[coff + 2:coff + 4])[0]
sub = None
for i in range(ncmap):
    o = coff + 4 + i * 8
    pid, eid, so = struct.unpack(">HHL", data[o:o + 8])
    fmt = struct.unpack(">H", data[coff + so:coff + so + 2])[0]
    if (pid, eid) in ((3, 1), (0, 3), (0, 0)) and fmt == 4:
        sub = coff + so
        break
assert sub, "format-4 cmap 없음"

segX2 = struct.unpack(">H", data[sub + 6:sub + 8])[0]
n = segX2 // 2
ends = struct.unpack(">%dH" % n, data[sub + 14:sub + 14 + 2 * n])
starts = struct.unpack(">%dH" % n, data[sub + 16 + 2 * n:sub + 16 + 4 * n])
deltas = struct.unpack(">%dh" % n, data[sub + 16 + 4 * n:sub + 16 + 6 * n])
ro_off = sub + 16 + 6 * n

def glyph(cp):
    for i in range(n):
        if starts[i] <= cp <= ends[i]:
            if deltas[i] != 0 or True:
                ro = struct.unpack(">H", data[ro_off + 2 * i:ro_off + 2 * i + 2])[0]
                if ro == 0:
                    return (cp + deltas[i]) & 0xFFFF
                p = ro_off + 2 * i + ro + 2 * (cp - starts[i])
                g = struct.unpack(">H", data[p:p + 2])[0]
                return (g + deltas[i]) & 0xFFFF if g else 0
    return 0

need = {
    "가": 0xAC00, "한": 0xD55C, "글": 0xAE00, "웨": 0xC6E8, "이": 0xC774,
    "브": 0xBE0C, "보": 0xBCF4, "스": 0xC2A4, "♥": 0x2665, "◀": 0x25C0,
    "▶": 0x25B6, "—": 0x2014, "탭": 0xD0ED, "W": 0x57, "0": 0x30,
}
ok = True
for ch, cp in need.items():
    g = glyph(cp)
    print(("OK  " if g else "MISS"), ch, hex(cp), "gid=%d" % g)
    if not g:
        ok = False
print("RESULT:", "ALL-OK" if ok else "MISSING-GLYPH")
