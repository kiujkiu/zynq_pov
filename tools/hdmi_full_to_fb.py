"""Compress full HDMI 1280×720 content → 128×64 LED panel (no crop, just resize).
   Source: any 1280×720 image. Default: vid_frames_slice/f0.jpg (phone photo of HDMI).
"""
import sys, struct, os
from PIL import Image, ImageEnhance

src_path = sys.argv[1] if len(sys.argv) > 1 else r"D:\claude_workspace\pov3d\zynq_pov\vid_frames_slice\f0.jpg"
out_dir = r"D:\claude_workspace\pov3d\zynq_pov\tools"

im = Image.open(src_path).convert("RGB")
print(f"input: {im.size} {im.mode}")
w, h = im.size

# Crop AOC monitor screen area if this is a phone photo
# vid_frames_slice/f0.jpg is 1280×720 phone photo, monitor screen at roughly:
if "vid_frames_slice" in src_path and w >= 1200:
    # Crop monitor screen content (remove bezel)
    # Looking at the image: monitor screen spans x∈[80, 1200], y∈[40, 670]
    im = im.crop((80, 40, 1200, 670))
    print(f"monitor-cropped: {im.size}")

# Full resize 1280×720 (or cropped) → 128×64
# Don't preserve aspect (panel is 2:1 = 128:64, HDMI is 16:9 = 1280:720)
# Stretch to fit panel; alternative: letterbox to keep aspect
im = im.resize((128, 64), Image.LANCZOS)

# Light enhance (slice grid has low brightness in photo)
im = ImageEnhance.Brightness(im).enhance(1.3)
im = ImageEnhance.Contrast(im).enhance(1.3)
im = ImageEnhance.Color(im).enhance(1.4)

pix = im.load()
fb_top = bytearray()
fb_bot = bytearray()
for y in range(64):
    for x in range(128):
        r, g, b = pix[x, y]
        rgb = r | (g << 8) | (b << 16)
        word = struct.pack("<I", rgb)
        if y < 32:
            fb_top += word
        else:
            fb_bot += word

with open(os.path.join(out_dir, "fb_anime_top.bin"), "wb") as f:
    f.write(fb_top)
with open(os.path.join(out_dir, "fb_anime_bot.bin"), "wb") as f:
    f.write(fb_bot)
# Save preview 4x scaled for human view
im_preview = im.resize((128*4, 64*4), Image.NEAREST)
im_preview.save(os.path.join(out_dir, "fb_anime_preview.png"))
print(f"output: fb_anime_top/bot.bin + fb_anime_preview.png (4x scaled)")
