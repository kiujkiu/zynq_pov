"""精确抽 GPIO1: 按 y 坐标对齐 pin number + site name"""
import fitz, re
pdf = r'D:\芯片资料\zynq7020-484\01_硬件资料\SCH_Schematic1_2024-10-07.pdf'
doc = fitz.open(pdf)
page = doc[7]  # page 8
words = page.get_text("words")

# GPIO1 area: x range 250-470 (left site at 320, right site at 449, pin numbers between)
gpio1_words = [w for w in words if 250 < w[0] < 470 and 300 < w[1] < 720]

# group by y (~7 unit tolerance)
from collections import defaultdict
rows = defaultdict(list)
for w in gpio1_words:
    y_key = round(w[1] / 4) * 4
    rows[y_key].append(w)

print("--- GPIO1 SCH page 8 rows (y, items) ---")
for y_key in sorted(rows.keys()):
    items = sorted(rows[y_key], key=lambda w: w[0])
    # 去重
    seen = set()
    uniq = []
    for w in items:
        key = (w[0], w[4])
        if key not in seen:
            seen.add(key)
            uniq.append(w)
    line = " | ".join(f"x={w[0]:.0f} {w[4]}" for w in uniq)
    print(f"y={y_key}: {line}")
