"""make 128x128 image: 8x8 grid, each 16x16 cell unique gradient color + number 1-64."""
import os, sys, colorsys
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(__file__))
from display_128x128 import write_panels

OUT_DIR = r'D:\claude_workspace\pov3d\zynq_pov\tools'

def find_font(size):
    candidates = [
        r'C:\Windows\Fonts\consola.ttf',
        r'C:\Windows\Fonts\arial.ttf',
        r'C:\Windows\Fonts\verdana.ttf',
    ]
    for p in candidates:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()

img = Image.new('RGB', (128, 128), (0, 0, 0))
draw = ImageDraw.Draw(img)
font = find_font(10)

for row in range(8):
    for col in range(8):
        idx = row * 8 + col + 1
        hue = (idx - 1) / 64.0
        r, g, b = colorsys.hsv_to_rgb(hue, 1.0, 1.0)
        cell_rgb = (int(r * 255), int(g * 255), int(b * 255))
        x0, y0 = col * 16, row * 16
        draw.rectangle([x0, y0, x0 + 15, y0 + 15], fill=cell_rgb)
        luma = 0.299 * cell_rgb[0] + 0.587 * cell_rgb[1] + 0.114 * cell_rgb[2]
        text_color = (0, 0, 0) if luma > 140 else (255, 255, 255)
        text = str(idx)
        bbox = draw.textbbox((0, 0), text, font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        tx = x0 + (16 - tw) // 2 - bbox[0]
        ty = y0 + (16 - th) // 2 - bbox[1]
        draw.text((tx, ty), text, fill=text_color, font=font)

img.save(os.path.join(OUT_DIR, 'chess_8x8_src.png'))
write_panels(img, OUT_DIR)
print(f"wrote chess_8x8 → 4 panel bins in {OUT_DIR}")
