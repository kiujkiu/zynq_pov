"""Crop one anime character portrait from blender render → save anime_crop.png."""
from PIL import Image, ImageEnhance
src = Image.open(r"D:\workspace\zynq_pov\host\blender\baked_vs_raw.png")
# baked_vs_raw is 3 rows × 4 cols of renders; grab top-left character
w, h = src.size  # ~582 × 605?
# Crop top-left character roughly
top_h = h // 3
char_w = w // 4
crop = src.crop((0, 20, char_w, top_h - 10)).convert("RGB")
# Enhance for low-res
crop = ImageEnhance.Contrast(crop).enhance(1.8)
crop = ImageEnhance.Color(crop).enhance(1.5)
crop = ImageEnhance.Brightness(crop).enhance(1.3)
out = r"D:\workspace\zynq_pov\tools\anime_crop.png"
crop.save(out)
print(f"saved {out} {crop.size}")
