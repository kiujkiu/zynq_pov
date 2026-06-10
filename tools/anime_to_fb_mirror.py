"""anime_to_fb_mirror.py - mirror mode, single-panel proven color formula.

完全自带 transform + 公式, 不走 display_128x128.pack_panel_bin (那个 0.35/0.9/1.3 系数
是 chess 时调的 G 主导, 套 anime 会粉青). 公式来自 memory project_pov3d_led_anime_display.md
单 panel HDMI bridge 实测的金发+蓝披风显示:
    sr = clip(r - 32, 0, 192)
    r_b = (sr * 21) >> 6   # → 0..63
    g_b = ((sg * 21) >> 6) >> 1            # R 100%, G 50%, B 75%
    b_b = (((sb * 21) >> 6) * 3) >> 2

Panel layout (memory project_pov3d_dual_panel_v34g_chess.md):
  - panel 1 transform: rotate(-90) + hw row swap 0..31 ↔ 32..63
  - panel 2 transform: flip_lr + rotate(-90) + flip_tb (镜像 mount)
  - 单 panel anime fit 64×128 portrait, mirror 两块 panel 各自显示一个完整角色
"""
import os, sys, struct
from PIL import Image, ImageEnhance

OUT_DIR = r'D:\claude_workspace\pov3d\zynq_pov\tools'
# Per-panel gain (panel 1 缺 B = chain GRB 末端 B fail, panel 2 缺 G = chain BRG 末端 G fail)
# 默认: panel 1 R 0.5 G 0.7 B 1.5 (砍 R 提 B), panel 2 R 0.5 G 1.5 B 0.7 (砍 R 提 G)
P1_R = float(sys.argv[1]) if len(sys.argv) > 1 else 0.5
P1_G = float(sys.argv[2]) if len(sys.argv) > 2 else 0.7
P1_B = float(sys.argv[3]) if len(sys.argv) > 3 else 1.5
P2_R = float(sys.argv[4]) if len(sys.argv) > 4 else 0.5
P2_G = float(sys.argv[5]) if len(sys.argv) > 5 else 1.5
P2_B = float(sys.argv[6]) if len(sys.argv) > 6 else 0.7
print(f"P1 gain: R={P1_R} G={P1_G} B={P1_B}")
print(f"P2 gain: R={P2_R} G={P2_G} B={P2_B}")
src_path = os.path.join(OUT_DIR, 'anime_crop.png')

# ---- Load + fit + chroma key (一次, 给两块 panel 共用) ----
im = Image.open(src_path).convert("RGB")
print(f"input: {im.size}")
w, h = im.size
s = min(w, h)
im = im.crop(((w-s)//2, (h-s)//2, (w-s)//2+s, (h-s)//2+s))
im = ImageEnhance.Color(im).enhance(1.2)
im = ImageEnhance.Brightness(im).enhance(1.1)

target_w, target_h = 64, 128
scale = min(target_w / im.size[0], target_h / im.size[1])
new_w, new_h = max(1, int(im.size[0] * scale)), max(1, int(im.size[1] * scale))
im_resized = im.resize((new_w, new_h), Image.LANCZOS)
panel_img = Image.new('RGB', (target_w, target_h), (0, 0, 0))
panel_img.paste(im_resized, ((target_w - new_w) // 2, (target_h - new_h) // 2))

# Chroma key 灰底 → 黑
px = panel_img.load()
threshold = 90
for y in range(target_h):
    for x in range(target_w):
        r, g, b = px[x, y]
        if max(r, g, b) < threshold and abs(r-g) < 15 and abs(g-b) < 15:
            px[x, y] = (0, 0, 0)

# ---- Per-panel transform ----
def transform_for_panel1(img):
    hw = img.rotate(-90, expand=True)
    top = hw.crop((0, 0, 128, 32))
    bot = hw.crop((0, 32, 128, 64))
    out = Image.new('RGB', (128, 64))
    out.paste(bot, (0, 0))
    out.paste(top, (0, 32))
    return out

def transform_for_panel2(img):
    return (img.transpose(Image.FLIP_LEFT_RIGHT)
              .rotate(-90, expand=True)
              .transpose(Image.FLIP_TOP_BOTTOM))

def pack_panel_bin(panel_hw, r_gain, g_gain, b_gain):
    pix = panel_hw.load()
    top_data = bytearray()
    bot_data = bytearray()
    for hw_row in range(64):
        for hw_col in range(128):
            r, g, b = pix[hw_col, hw_row]
            r_b = min(63, int(r * r_gain) >> 2)
            g_b = min(63, int(g * g_gain) >> 2)
            b_b = min(63, int(b * b_gain) >> 2)
            word = struct.pack('<I', (r_b & 0x3F) | ((g_b & 0x3F) << 8) | ((b_b & 0x3F) << 16))
            target = top_data if hw_row < 32 else bot_data
            target.extend(word)
    assert len(top_data) == 16384 and len(bot_data) == 16384
    return bytes(top_data), bytes(bot_data)

# ---- Generate panel 1 / panel 2 bins ----
panel1_hw = transform_for_panel1(panel_img)
panel2_hw = transform_for_panel2(panel_img)
top1, bot1 = pack_panel_bin(panel1_hw, P1_R, P1_G, P1_B)
top2, bot2 = pack_panel_bin(panel2_hw, P2_R, P2_G, P2_B)

files = {
    'fb_anime_128_top1.bin': top1,
    'fb_anime_128_bot1.bin': bot1,
    'fb_anime_128_top2.bin': top2,
    'fb_anime_128_bot2.bin': bot2,
}
for name, data in files.items():
    with open(os.path.join(OUT_DIR, name), 'wb') as f:
        f.write(data)
panel_img.save(os.path.join(OUT_DIR, 'fb_anime_128_preview.png'))
print(f"mirror anime bins written (single-panel R100/G50/B75 formula)")
