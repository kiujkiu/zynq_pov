"""
display_128x128.py - POV3D 128x128 dual-panel display driver

Abstracts the two 64x128 portrait panels (panel 2 left + panel 1 right) as a
single 128x128 logical screen.

Hardware layout:
  - Panel 1: viewer's RIGHT, 64w x 128h portrait (90 CW physical mount)
  - Panel 2: viewer's LEFT,  64w x 128h portrait (90 CW physical mount)
  - Each panel hw native: 128 cols x 64 rows landscape

Usage:
    from display_128x128 import write_panels
    img = PIL.Image of 128x128 RGB
    write_panels(img, out_dir=r'D:\\claude_workspace\\pov3d\\zynq_pov\\tools')
  produces:
    fb_anime_128_top1.bin / bot1.bin / top2.bin / bot2.bin

Transform per panel:
  1. Split image -> img_left (cols 0..63), img_right (cols 64..127)
  2. rotate(-90, expand=True) to fit panel hw 128w x 64h
  3. transpose(FLIP_LEFT_RIGHT) to correct viewer L/R orientation
  4. Pack row-major into top_half (rows 0..31) + bot_half (rows 32..63) bin
"""
import os, struct, sys
from PIL import Image

def transform_for_panel1(img_half):
    """Panel 1: rotate(-90). v34mtr: 去掉 row-swap (转接板上右屏不再需要,
    否则屏上半幅 [5,6]/[7,8] 对调). 直连时代需要 row-swap."""
    hw = img_half.rotate(-90, expand=True)
    if PANEL1_ROWSWAP:
        top = hw.crop((0, 0, 128, 32)); bot = hw.crop((0, 32, 128, 64))
        sw = Image.new('RGB', (128, 64)); sw.paste(bot,(0,0)); sw.paste(top,(0,32))
        return sw
    return hw

def transform_for_panel2(img_half):
    """Panel 2 (viewer left): mirrored mount, pre-flip horizontally."""
    return (img_half
            .transpose(Image.FLIP_LEFT_RIGHT)
            .rotate(-90, expand=True)
            .transpose(Image.FLIP_TOP_BOTTOM))

# 两屏亮度均衡: panel 1 (右) 比 panel 2 (左) 亮 ~8% (DCLK2 走普通脚 Y14, 见 memory).
# 把亮的 panel 1 软件降到跟 panel 2 一致. 1.0 = 不动.
PANEL1_ROWSWAP = False   # 转接板: 去 row-swap
PANEL_BANK_SWAP = True   # 转接板: panel1/2 输出物理接反
PANEL1_BRIGHT = 0.90
PANEL2_BRIGHT = 1.00

# 通道增益 (2026-06-11 当前 bit 实测): 右屏单色满值 camera 读 R228/G183/B218
# → G 最弱, 把 R/B 压到 G 水平. (06-03 记录 "G 过亮砍半" 是旧 bit/旧接线, 已不符;
#  R×0.35 是 160x180 ICND 面板的, 同样不适用)
R_GAIN, G_GAIN, B_GAIN = 0.95, 1.00, 0.85

# sRGB→线性 gamma 2.2 LUT (2026-06-11 黄卡实测): LED BCM 是线性占空, 图片是 sRGB
# 编码. 不做 gamma 解码所有中间调冲白 (发色金 187,165,88 显示成粉白).
# HDMI 显示器自带 2.2 解码所以 HDMI 路径不需要, LED 必须.
GAMMA = 2.2
_G_LUT = [min(63, round(((v / 255.0) ** GAMMA) * 63)) for v in range(256)]

def pack_panel_bin(panel_hw, bright=1.0):
    """Pack panel hw 128x64 image to (top_half_bytes, bot_half_bytes), 16KB each."""
    pix = panel_hw.load()
    top_data, bot_data = bytearray(), bytearray()
    for hw_row in range(64):
        for hw_col in range(128):
            r, g, b = pix[hw_col, hw_row]
            r8 = min(255, int(r * R_GAIN * bright))
            g8 = min(255, int(g * G_GAIN * bright))
            b8 = min(255, int(b * B_GAIN * bright))
            r6, g6, b6 = _G_LUT[r8], _G_LUT[g8], _G_LUT[b8]
            # byte→LED 实测映射 (2026-06-11): byte0→蓝 byte1→红 byte2→绿
            word = struct.pack('<I', b6 | (r6 << 8) | (g6 << 16))
            (top_data if hw_row < 32 else bot_data).append(word[0])
            (top_data if hw_row < 32 else bot_data).append(word[1])
            (top_data if hw_row < 32 else bot_data).append(word[2])
            (top_data if hw_row < 32 else bot_data).append(word[3])
    assert len(top_data) == 16384 and len(bot_data) == 16384
    return bytes(top_data), bytes(bot_data)

def write_panels(img, out_dir):
    """img: PIL 128x128 RGB. Writes 4 bin files to out_dir."""
    if img.size != (128, 128):
        img = img.convert('RGB').resize((128, 128), Image.LANCZOS)
    else:
        img = img.convert('RGB')
    img_left  = img.crop((0,  0,  64, 128))   # panel 2 (viewer's LEFT)
    img_right = img.crop((64, 0, 128, 128))   # panel 1 (viewer's RIGHT)
    panel1_hw = transform_for_panel1(img_right)
    panel2_hw = transform_for_panel2(img_left)
    top1, bot1 = pack_panel_bin(panel1_hw, PANEL1_BRIGHT)
    top2, bot2 = pack_panel_bin(panel2_hw, PANEL2_BRIGHT)
    # PANEL_BANK_SWAP (2026-06-15 转接板): panel1/panel2 输出 bank 物理接反,
    # 把两块数据写到对方的 BRAM 区. 直连时代 = False.
    if PANEL_BANK_SWAP:
        top1, bot1, top2, bot2 = top2, bot2, top1, bot1
    files = {
        'fb_anime_128_top1.bin': top1,
        'fb_anime_128_bot1.bin': bot1,
        'fb_anime_128_top2.bin': top2,
        'fb_anime_128_bot2.bin': bot2,
    }
    for name, data in files.items():
        with open(os.path.join(out_dir, name), 'wb') as f:
            f.write(data)
    # save preview
    img.save(os.path.join(out_dir, 'fb_anime_128_preview.png'))
    panel1_hw.save(os.path.join(out_dir, 'fb_anime_128_panel1_hw.png'))
    panel2_hw.save(os.path.join(out_dir, 'fb_anime_128_panel2_hw.png'))
    return files

if __name__ == '__main__':
    OUT_DIR = r'D:\claude_workspace\pov3d\zynq_pov\tools'
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(OUT_DIR, 'anime_crop.png')
    img = Image.open(src).convert('RGB')
    # auto-crop square center
    w, h = img.size
    s = min(w, h)
    img = img.crop(((w-s)//2, (h-s)//2, (w-s)//2+s, (h-s)//2+s))
    img = img.resize((128, 128), Image.LANCZOS)
    # anime crop has color boost from before
    from PIL import ImageEnhance
    img = ImageEnhance.Color(img).enhance(1.2)
    img = ImageEnhance.Brightness(img).enhance(1.1)
    write_panels(img, OUT_DIR)
    print(f"wrote 4 BRAM bins + previews to {OUT_DIR}")
