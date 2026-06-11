import struct, os
OUT = r'D:\claude_workspace\pov3d\zynq_pov\tools'
# panel1 hw framebuffer: 128 col x 64 row. word(i): hw_row=i//128, hw_col=i%128
# left half (hw_col<64) = 50% (0x1F), right half = 100% (0x3F)
def val(level):  # white at given 6-bit level
    v = level & 0x3F
    return v | (v<<8) | (v<<16)
LO, HI = val(0x1F), val(0x3F)
def panel1_half(row_base):
    data = bytearray()
    for i in range(4096):
        hw_col = i % 128
        w = LO if hw_col < 64 else HI
        data += struct.pack('<I', w)
    return bytes(data)
top1 = panel1_half(0)    # hw_row 0..31
bot1 = panel1_half(32)   # hw_row 32..63
black = struct.pack('<I', 0) * 4096
for name, d in [('top1',top1),('bot1',bot1),('top2',black),('bot2',black)]:
    open(os.path.join(OUT, f'fb_anime_128_{name}.bin'),'wb').write(d)
print("panel1 half-split bins written (L=50% R=100%, panel2=black)")
