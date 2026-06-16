"""给 raw point_t bin 加 [magic='PPC0', count] 8 字节头, 供 main_render.c 注入 DDR。
用法: python3 tools/_make_pts_hdr.py [in.bin] [out.bin]
默认: anime_points.bin -> anime_points_hdr.bin (放 DDR 0x16000000)。
纯 stdlib。"""
import os, sys, struct
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "anime_points.bin")
dst = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "tools", "anime_points_hdr.bin")
raw = open(src, "rb").read()
assert len(raw) % 16 == 0, f"{src} not multiple of 16B"
count = len(raw) // 16
MAGIC = 0x30435050  # 'PPC0' little-endian
open(dst, "wb").write(struct.pack("<II", MAGIC, count) + raw)
print(f"{dst}: magic=PPC0 count={count} total={8+len(raw)} bytes")
