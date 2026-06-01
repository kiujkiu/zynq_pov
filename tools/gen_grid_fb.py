"""Generate fb_top.bin + fb_bot.bin for 8×4 grid (16×16 each)
   cells: number 0..15 (cell_idx % 16), 3-color gradient R→G→B"""
import struct, os

# 5x7 font for digits '0'..'9' (column-major, bit 0 = top row)
FONT = {
    '0': [0x3E,0x51,0x49,0x45,0x3E],
    '1': [0x00,0x42,0x7F,0x40,0x00],
    '2': [0x42,0x61,0x51,0x49,0x46],
    '3': [0x21,0x41,0x45,0x4B,0x31],
    '4': [0x18,0x14,0x12,0x7F,0x10],
    '5': [0x27,0x45,0x45,0x45,0x39],
    '6': [0x3C,0x4A,0x49,0x49,0x30],
    '7': [0x01,0x71,0x09,0x05,0x03],
    '8': [0x36,0x49,0x49,0x49,0x36],
    '9': [0x06,0x49,0x49,0x29,0x1E],
}

def gradient_3color(t, total=32):
    """R→G→B, t in [0, total-1]"""
    half = (total - 1) / 2.0
    if t <= half:
        k = t / half
        return (int(255 * (1 - k)), int(255 * k), 0)
    else:
        k = (t - half) / (total - 1 - half)
        return (0, int(255 * (1 - k)), int(255 * k))

# fb arrays: 32 rows × 128 cols × 24-bit
fb_top = [[0] * 128 for _ in range(32)]   # panel row 0..31
fb_bot = [[0] * 128 for _ in range(32)]   # panel row 32..63

def fb_set(x, y, r, g, b):
    if not (0 <= x < 128 and 0 <= y < 64):
        return
    rgb = r | (g << 8) | (b << 16)
    if y < 32:
        fb_top[y][x] = rgb
    else:
        fb_bot[y - 32][x] = rgb

def draw_char(x, y, ch, color, scale=1):
    """draw char at (x, y), each font pixel becomes scale×scale block"""
    if ch not in FONT:
        return
    glyph = FONT[ch]
    r, g, b = (color >> 0) & 0xFF, (color >> 8) & 0xFF, (color >> 16) & 0xFF
    for col in range(5):
        column = glyph[col]
        for row in range(7):
            if column & (1 << row):
                for dx in range(scale):
                    for dy in range(scale):
                        fb_set(x + col * scale + dx, y + row * scale + dy, r, g, b)

# Fill 8×4 grid
for r in range(4):
    for c in range(8):
        cell_idx = r * 8 + c
        digit = cell_idx  # 0..31, 每 cell 不重复
        cr, cg, cb = gradient_3color(cell_idx, 32)

        # Fill 16×16 cell with grad color
        for py in range(r * 16, r * 16 + 16):
            for px in range(c * 16, c * 16 + 16):
                fb_set(px, py, cr, cg, cb)

        # Draw digit centered (single-digit scale=2 → 10×14; two-digit scale=1 → 11×7)
        digit_str = str(digit)
        if len(digit_str) == 1:
            sc = 2
            text_w = 5 * sc      # 10
            text_h = 7 * sc      # 14
            text_x = c * 16 + (16 - text_w) // 2
            text_y = r * 16 + (16 - text_h) // 2
            draw_char(text_x, text_y, digit_str, 0xFFFFFF, scale=sc)
        else:
            # two-digit: 11×7 居中
            sc = 1
            text_w = len(digit_str) * 5 + (len(digit_str) - 1)
            text_x = c * 16 + (16 - text_w) // 2
            text_y = r * 16 + (16 - 7) // 2
            for ci, ch in enumerate(digit_str):
                draw_char(text_x + ci * 6, text_y, ch, 0xFFFFFF, scale=sc)

# Write binary: 4096 pixels × 4 bytes (LSB 24-bit RGB, top byte 0)
OUT_DIR = "."
with open(os.path.join(OUT_DIR, "fb_top.bin"), "wb") as f:
    for row in fb_top:
        for px in row:
            f.write(struct.pack("<I", px))
with open(os.path.join(OUT_DIR, "fb_bot.bin"), "wb") as f:
    for row in fb_bot:
        for px in row:
            f.write(struct.pack("<I", px))

# Stats
n = sum(1 for row in fb_top + fb_bot for px in row if px != 0)
print(f"fb_top.bin + fb_bot.bin: 16384 bytes each (4096 pixels × 4)")
print(f"non-zero pixels: {n} / 8192 ({100*n/8192:.1f}%)")
print(f"cell (0,0) corner: top[0][0] = 0x{fb_top[0][0]:06X}")
print(f"cell (3,7) corner: bot[31][127] = 0x{fb_bot[31][127]:06X}")
