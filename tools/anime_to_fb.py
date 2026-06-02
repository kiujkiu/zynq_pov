"""Convert anime image → HUB75E fb_top/bot.bin (128×64 panel).
   Default source: tools/anime_crop.png (clean rendered glb).
"""
import sys, struct, os
from PIL import Image, ImageEnhance

src_path = sys.argv[1] if len(sys.argv) > 1 else r"D:\claude_workspace\pov3d\zynq_pov\tools\anime_crop.png"
out_dir = r"D:\claude_workspace\pov3d\zynq_pov\tools"

im = Image.open(src_path).convert("RGB")
print(f"input: {im.size} {im.mode}")
w, h = im.size

# Crop to square-ish aspect for 128×64 (2:1) - take vertical center 2× wider
target_w, target_h = 128, 64
target_aspect = target_w / target_h  # 2.0
src_aspect = w / h
if src_aspect > target_aspect:
    # source is wider — crop sides
    new_w = int(h * target_aspect)
    x0 = (w - new_w) // 2
    im = im.crop((x0, 0, x0 + new_w, h))
else:
    # source is taller — crop top/bot
    new_h = int(w / target_aspect)
    y0 = (h - new_h) // 2
    im = im.crop((0, y0, w, y0 + new_h))
print(f"aspect-cropped: {im.size}")

# Light boost (rendered image already clean)
im = ImageEnhance.Color(im).enhance(1.2)
im = ImageEnhance.Brightness(im).enhance(1.1)
# Downsample
im = im.resize((target_w, target_h), Image.LANCZOS)
print(f"resized: {im.size}")

pix = im.load()
fb_top_data = bytearray()
fb_bot_data = bytearray()

for y in range(64):
    for x in range(128):
        r, g, b = pix[x, y]
        rgb = r | (g << 8) | (b << 16)
        word = struct.pack("<I", rgb)
        if y < 32:
            fb_top_data += word
        else:
            fb_bot_data += word

with open(os.path.join(out_dir, "fb_anime_top.bin"), "wb") as f:
    f.write(fb_top_data)
with open(os.path.join(out_dir, "fb_anime_bot.bin"), "wb") as f:
    f.write(fb_bot_data)
im.save(os.path.join(out_dir, "fb_anime_preview.png"))
print(f"output: fb_anime_top/bot.bin + fb_anime_preview.png")
