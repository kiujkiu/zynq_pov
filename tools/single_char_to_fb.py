"""Single 3D model render → 128×64 LED. Letterbox to preserve aspect.
   Default: tools/anime_crop.png (clean glb render).
"""
import sys, struct, os
from PIL import Image, ImageEnhance, ImageOps

src_path = sys.argv[1] if len(sys.argv) > 1 else r"D:\claude_workspace\pov3d\zynq_pov\tools\anime_crop.png"
out_dir = r"D:\claude_workspace\pov3d\zynq_pov\tools"

im = Image.open(src_path).convert("RGB")
print(f"input: {im.size} {im.mode}")
w, h = im.size

# Crop off top text bar if present (e.g. "RAW (no lighting):" label)
# Auto-crop top 5% to skip caption
top_crop = int(h * 0.05)
im = im.crop((0, top_crop, w, h))
w, h = im.size

# Find character bounding box (non-grey pixels)
# Background is grey (~128). Find content bounds.
import numpy as np
arr = np.array(im)
# Distance from neutral grey
diff = np.abs(arr.astype(int) - 128).sum(axis=2)
mask = diff > 60   # not grey
ys, xs = np.where(mask)
if len(xs) > 0:
    x0, x1 = max(xs.min() - 5, 0), min(xs.max() + 5, w)
    y0, y1 = max(ys.min() - 5, 0), min(ys.max() + 5, h)
    im = im.crop((x0, y0, x1, y1))
    print(f"content-cropped: {im.size}")

# Letterbox to 2:1 keep aspect (better than stretch distortion)
target_aspect = 128/64  # 2.0
w, h = im.size
src_aspect = w / h
if src_aspect < target_aspect:
    new_w = int(h * target_aspect)
    pad = (new_w - w) // 2
    im = ImageOps.expand(im, border=(pad, 0, new_w - w - pad, 0), fill=(0,0,0))
else:
    new_h = int(w / target_aspect)
    pad = (new_h - h) // 2
    im = ImageOps.expand(im, border=(0, pad, 0, new_h - h - pad), fill=(0,0,0))
print(f"letterboxed: {im.size}")

# Resize to 128×64
im = im.resize((128, 64), Image.LANCZOS)
print(f"resized: {im.size}")

# Replace neutral grey background with BLACK (so panel doesn't get washed out)
import numpy as np
arr = np.array(im).astype(np.float32)
# Grey = low saturation. Compute max-min across channels (=chroma)
chroma = arr.max(axis=2) - arr.min(axis=2)
# Pixels with low chroma + medium luma (60..200) → grey background → black
luma = arr.mean(axis=2)
mask = (chroma < 30) & (luma > 50) & (luma < 220)
arr[mask] = 0

# LED panel R >> G >> B 严重不平衡, 预补偿:
# panel R 约 6× G, 5× B 亮度. 要让 RGB 看起来平衡:
# - R 衰减到 1/6 (高 R 像素不会盖过其他色)
# - G 保持
# - B 略提升
arr = arr / 255.0
arr[:,:,0] *= 0.35   # R 衰减 (panel R 太强但黄色还要 R)
arr[:,:,1] *= 0.90   # G 保持
arr[:,:,2] *= 1.30   # B 提升 (panel B 弱)
# Saturation boost via channel difference enhancement
arr = np.clip(arr, 0, 1)
arr = np.power(arr, 0.85)
arr = (arr * 255).astype(np.uint8)
im = Image.fromarray(arr, "RGB")
im = ImageEnhance.Color(im).enhance(2.5)

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
im_preview = im.resize((128*6, 64*6), Image.NEAREST)
im_preview.save(os.path.join(out_dir, "fb_anime_preview.png"))
print(f"output: fb_anime_top/bot.bin + preview (6x scaled)")
