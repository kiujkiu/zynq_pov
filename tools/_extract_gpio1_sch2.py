"""更细抽 GPIO1: site + pin number + connector pin number"""
import fitz, re

pdf = r'D:\芯片资料\zynq7020-484\01_硬件资料\SCH_Schematic1_2024-10-07.pdf'
doc = fitz.open(pdf)
page = doc[7]  # page 8 (0-indexed)
words = page.get_text("words")

# extract all words on page 8
print("--- raw words near GPIO1 area (y 300-700) ---")
for w in sorted(words, key=lambda w: (round(w[1]), w[0])):
    x, y, _, _, txt = w[0], w[1], w[2], w[3], w[4]
    if 300 < y < 700 and (re.match(r'IO_L\d+', txt) or re.match(r'^\d{1,2}$', txt) or txt in ('GPIO1','GPIO2')):
        print(f"  y={y:.0f} x={x:.0f}  {txt}")
