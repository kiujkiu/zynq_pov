"""anime_crop.png → 128x128, 按 2026-06-03 颜色记录: 背景置黑 + [32,224] 中段 stretch.
增益 R1.0/G0.5/B0.75 + byte 映射在 display_128x128.pack_panel_bin 里."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image, ImageEnhance
from display_128x128 import write_panels

OUT = r'D:\claude_workspace\pov3d\zynq_pov\tools'
img = Image.open(os.path.join(OUT, 'anime_crop.png')).convert('RGB')
w, h = img.size
s = min(w, h)
img = img.crop(((w-s)//2, (h-s)//2, (w-s)//2+s, (h-s)//2+s)).resize((128,128), Image.LANCZOS)
img = ImageEnhance.Color(img).enhance(1.2)

a = np.asarray(img).astype(int)
# 背景置黑: 取四角中值当背景色, 距离 < 40 → 黑
corners = np.array([a[2,2], a[2,-3], a[-3,2], a[-3,-3]])
bg = np.median(corners, axis=0)
dist = np.abs(a - bg).sum(axis=2)
mask_bg = dist < 60
# 中段 stretch [32,224] → [0,255] (2026-06-03 记录: 拉大 anime 100-180 中段色差)
st = np.clip((a - 32) * 255 // 192, 0, 255)
st[mask_bg] = 0
img = Image.fromarray(st.astype(np.uint8))

# 方向修正 (chess 验证): rotate180 + 左右半幅交换
img = img.rotate(180)
L = img.crop((0,0,64,128)); R = img.crop((64,0,128,128))
fixed = Image.new('RGB',(128,128)); fixed.paste(R,(0,0)); fixed.paste(L,(64,0))
write_panels(fixed, OUT)
print(f"anime bins v2: bg-black ({mask_bg.sum()} px), stretch, gains R1.0/G0.5/B0.75")
