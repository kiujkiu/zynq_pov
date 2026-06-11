"""128x128 chessboard test: 8x8 grid, 16x16 per cell, each cell unique color + number."""
import os, sys
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(__file__))
from display_128x128 import write_panels

OUT_DIR = r'D:\claude_workspace\pov3d\zynq_pov\tools'

img = Image.new('RGB', (128, 128), (0, 0, 0))
draw = ImageDraw.Draw(img)

# 8x8 grid, 16x16 per cell
CELL = 16

def cell_color(idx):
    # generate 64 distinct colors via HSV
    import colorsys
    h = (idx % 64) / 64.0
    s = 0.9
    v = 0.6  # dim enough that white text shows
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r*255), int(g*255), int(b*255))

# tiny 3x5 pixel digits for 0-9 (one-pixel strokes)
DIGITS = {
    '0': ['111','101','101','101','111'],
    '1': ['010','110','010','010','111'],
    '2': ['111','001','111','100','111'],
    '3': ['111','001','111','001','111'],
    '4': ['101','101','111','001','001'],
    '5': ['111','100','111','001','111'],
    '6': ['111','100','111','101','111'],
    '7': ['111','001','010','100','100'],
    '8': ['111','101','111','101','111'],
    '9': ['111','101','111','001','111'],
}

def draw_digit(draw_img, ch, x, y, color):
    if ch not in DIGITS:
        return
    for dy, row in enumerate(DIGITS[ch]):
        for dx, c in enumerate(row):
            if c == '1':
                draw_img.putpixel((x+dx, y+dy), color)

for row in range(8):
    for col in range(8):
        idx = row * 8 + col
        x0 = col * CELL
        y0 = row * CELL
        # fill cell with color
        draw.rectangle((x0, y0, x0+CELL-1, y0+CELL-1), fill=cell_color(idx))
        # draw cell number top-left, 1 px from edge
        # decimal: tens digit + ones digit
        tens = idx // 10
        ones = idx % 10
        # white text
        white = (255, 255, 255)
        if tens > 0:
            draw_digit(img, str(tens), x0+1, y0+1, white)
            draw_digit(img, str(ones), x0+5, y0+1, white)
        else:
            draw_digit(img, str(ones), x0+1, y0+1, white)

img.save(os.path.join(OUT_DIR, 'test_chessboard_128x128.png'))
write_panels(img, OUT_DIR)
print("chessboard written, expected:")
print("  8x8 grid of 16x16 cells")
print("  cell 0 at top-LEFT (red-ish HSV 0)")
print("  cell 7 at top-RIGHT")
print("  cell 56 at bottom-LEFT")
print("  cell 63 at bottom-RIGHT")
print("  each cell white digit count 0..63 in top-LEFT corner")
