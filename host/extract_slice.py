"""Extract single slice N from anime_slices.bin into top/bot 16KB bin files.

Usage: extract_slice.py <slice_idx>
Output (in zynq_pov root): slice_top.bin, slice_bot.bin (16 KB each)
"""
import sys
from pathlib import Path

SLICE_BYTES = 128 * 64 * 4  # 32 KB
HALF_BYTES = 128 * 32 * 4   # 16 KB

idx = int(sys.argv[1]) if len(sys.argv) > 1 else 0
ROOT = Path(__file__).resolve().parent.parent

with open(ROOT / "anime_slices.bin", "rb") as f:
    f.seek(idx * SLICE_BYTES)
    data = f.read(SLICE_BYTES)

assert len(data) == SLICE_BYTES, f"got {len(data)}, expected {SLICE_BYTES}"
top = data[:HALF_BYTES]
bot = data[HALF_BYTES:]

with open(ROOT / "slice_top.bin", "wb") as f: f.write(top)
with open(ROOT / "slice_bot.bin", "wb") as f: f.write(bot)
print(f"slice {idx}: top {len(top)} byte → slice_top.bin, bot {len(bot)} byte → slice_bot.bin")
