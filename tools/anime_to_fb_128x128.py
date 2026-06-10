"""anime_to_fb_128x128.py - re-renders anime from anime_crop.png via display_128x128 driver."""
import os, sys
from PIL import Image, ImageEnhance
sys.path.insert(0, os.path.dirname(__file__))
from display_128x128 import write_panels

OUT_DIR = r'D:\claude_workspace\pov3d\zynq_pov\tools'
src_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(OUT_DIR, 'anime_crop.png')

im = Image.open(src_path).convert("RGB")
print(f"input: {im.size}")
# center square crop
w, h = im.size
s = min(w, h)
im = im.crop(((w-s)//2, (h-s)//2, (w-s)//2+s, (h-s)//2+s))
im = ImageEnhance.Color(im).enhance(1.2)
im = ImageEnhance.Brightness(im).enhance(1.1)
im = im.resize((128, 128), Image.LANCZOS)
print(f"resized: {im.size}")
# Chroma key + stretch + RGB channel compensation (memory project_pov3d_led_anime_display.md
# 单 panel 实测金发出来的公式):
#   1. clip(channel - 32, 0..192)    # 切灰底 + 高光
#   2. stretch [0,192] → BCM [0,63]  # 拉中段色差
#   3. R 100% / G 50% / B 75%        # panel 实测 G 视觉过强需要砍
#   4. << 2 回 8-bit (BCM truncate 取 high 6)
px = im.load()
threshold = 90
for y in range(128):
    for x in range(128):
        r, g, b = px[x, y]
        if max(r,g,b) < threshold and abs(r-g) < 15 and abs(g-b) < 15:
            px[x, y] = (0, 0, 0)
            continue
        sr = max(0, min(192, r - 32))
        sg = max(0, min(192, g - 32))
        sb = max(0, min(192, b - 32))
        r_b = (sr * 21) >> 6        # 0..63
        g_b = ((sg * 21) >> 6) >> 1 # 50%
        b_b = (((sb * 21) >> 6) * 3) >> 2  # 75%
        px[x, y] = (r_b << 2, g_b << 2, b_b << 2)
write_panels(im, OUT_DIR)
print("anime bins written via display_128x128 driver")
