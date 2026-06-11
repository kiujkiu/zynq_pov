"""128x128 4x4 chessboard: each cell 32x32, large enough to see clearly."""
import os, sys, colorsys
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
from display_128x128 import write_panels

OUT_DIR = r'D:\claude_workspace\pov3d\zynq_pov\tools'
img = Image.new('RGB', (128, 128), (0, 0, 0))
draw = ImageDraw.Draw(img)
CELL = 32

# 5x7 pixel digits
DIGITS = {
    '0': ['01110','10001','10001','10001','10001','10001','01110'],
    '1': ['00100','01100','00100','00100','00100','00100','01110'],
    '2': ['01110','10001','00001','00010','00100','01000','11111'],
    '3': ['01110','10001','00001','00110','00001','10001','01110'],
    '4': ['00010','00110','01010','10010','11111','00010','00010'],
    '5': ['11111','10000','11110','00001','00001','10001','01110'],
    '6': ['00110','01000','10000','11110','10001','10001','01110'],
    '7': ['11111','00001','00010','00100','01000','01000','01000'],
    '8': ['01110','10001','10001','01110','10001','10001','01110'],
    '9': ['01110','10001','10001','01111','00001','00010','01100'],
}

def draw_digit(draw_img, ch, x, y, color):
    if ch not in DIGITS: return
    for dy, row in enumerate(DIGITS[ch]):
        for dx, c in enumerate(row):
            if c == '1':
                draw_img.putpixel((x+dx, y+dy), color)

def cell_color(idx):
    # Bright distinct colors per cell (15 named + black)
    palette = [
        (255, 0,   0),    # 0 RED
        (255, 128, 0),    # 1 ORANGE
        (255, 255, 0),    # 2 YELLOW
        (128, 255, 0),    # 3 lime
        (0,   255, 0),    # 4 GREEN
        (0,   255, 128),  # 5 mint
        (0,   255, 255),  # 6 CYAN
        (0,   128, 255),  # 7 sky
        (0,   0,   255),  # 8 BLUE
        (128, 0,   255),  # 9 violet
        (255, 0,   255),  # 10 MAGENTA
        (255, 0,   128),  # 11 pink
        (128, 64,  0),    # 12 brown
        (128, 128, 128),  # 13 gray
        (255, 255, 255),  # 14 WHITE
        (64,  64,  64),   # 15 dark gray
    ]
    return palette[idx % 16]

for row in range(4):
    for col in range(4):
        idx = row * 4 + col
        x0 = col * CELL
        y0 = row * CELL
        draw.rectangle((x0, y0, x0+CELL-1, y0+CELL-1), fill=cell_color(idx))
        # number at top-left of cell (large 5x7 digit)
        tens = idx // 10
        ones = idx % 10
        white = (255, 255, 255)
        if tens > 0:
            draw_digit(img, str(tens), x0+3, y0+3, white)
            draw_digit(img, str(ones), x0+10, y0+3, white)
        else:
            draw_digit(img, str(ones), x0+3, y0+3, white)
        # corner marker: black 3x3 at top-left of cell (to verify grid alignment)
        for dx in range(3):
            for dy in range(3):
                img.putpixel((x0+CELL-3+dx, y0+dy), (255, 255, 255))

img.save(os.path.join(OUT_DIR, 'test_chessboard4_128x128.png'))
write_panels(img, OUT_DIR)
print("4x4 chessboard written, 32x32 cells, idx 0..15")
print("  idx 0 top-LEFT, idx 3 top-RIGHT, idx 12 bot-LEFT, idx 15 bot-RIGHT")
