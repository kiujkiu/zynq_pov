import struct, os
OUT = r'D:\claude_workspace\pov3d\zynq_pov\tools'
def val(level):
    v = level & 0x3F
    return v | (v<<8) | (v<<16)
LO, HI = val(0x1F), val(0x3F)   # 50% / 100%
def half():   # hw_col<64 = 50%, >=64 = 100%
    data = bytearray()
    for i in range(4096):
        data += struct.pack('<I', LO if (i % 128) < 64 else HI)
    return bytes(data)
p = half()
for name in ('top1','bot1','top2','bot2'):   # panel1 + panel2 同 pattern
    open(os.path.join(OUT, f'fb_anime_128_{name}.bin'),'wb').write(p)
print("both panels half-split (L=50% R=100%) written")
