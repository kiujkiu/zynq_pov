"""128x128 corner test pattern:
- TL red quadrant 'TL'
- TR green quadrant 'TR'
- BL blue quadrant 'BL'
- BR yellow quadrant 'BR'
- Centered character 'P1'/'P2' to mark which side is which after rotation
"""
from PIL import Image, ImageDraw, ImageFont
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from display_128x128 import write_panels

OUT_DIR = r'D:\claude_workspace\pov3d\zynq_pov\tools'

img = Image.new('RGB', (128, 128), (0, 0, 0))
draw = ImageDraw.Draw(img)
# 4 quadrants
draw.rectangle((0,   0,   63,  63),  fill=(80, 0, 0))    # TL dark red
draw.rectangle((64,  0,  127,  63),  fill=(0, 80, 0))    # TR dark green
draw.rectangle((0,   64,  63, 127),  fill=(0, 0, 80))    # BL dark blue
draw.rectangle((64,  64, 127, 127),  fill=(80, 80, 0))   # BR dark yellow
# corner markers (single pixel bright)
draw.rectangle((0,   0,    7,   7),  fill=(255, 0,   0))     # TL
draw.rectangle((120, 0,  127,   7),  fill=(0, 255,   0))     # TR
draw.rectangle((0, 120,    7, 127),  fill=(0,   0, 255))     # BL
draw.rectangle((120,120, 127, 127),  fill=(255,255,  0))     # BR
# vertical arrow up in center (a "T" pointing up - column of pixels)
for y in range(20, 110):
    img.putpixel((63, y), (255, 255, 255))
    img.putpixel((64, y), (255, 255, 255))
# horizontal top bar of the T (top portion = "up direction")
for x in range(50, 78):
    img.putpixel((x, 20), (255, 255, 255))
    img.putpixel((x, 21), (255, 255, 255))

img.save(os.path.join(OUT_DIR, 'test_corners_128x128.png'))
write_panels(img, OUT_DIR)
print(f"test corners written; preview: test_corners_128x128.png")
print("Expected on panel:")
print("  TL bright RED dot (top-left)")
print("  TR bright GREEN dot (top-right)")
print("  BL bright BLUE dot (bottom-left)")
print("  BR bright YELLOW dot (bottom-right)")
print("  White T arrow pointing UP in center")
