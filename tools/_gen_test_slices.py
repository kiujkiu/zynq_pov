"""8 个测试 slice (各 64KB, BRAM word 布局), DMA bring-up 用.
颜色按实测映射 byte0=B byte1=R byte2=G, 6-bit."""
import struct
def word(r,g,b): return b | (r<<8) | (g<<16)
COLORS = [  # (R,G,B) 6-bit
    (63,0,0),(0,63,0),(0,0,63),(63,63,63),
    (63,63,0),(63,0,63),(0,63,63),(20,20,20),
]
out = bytearray()
for si,(r,g,b) in enumerate(COLORS):
    w = struct.pack('<I', word(r,g,b))
    out += w * 16384   # 4 bank × 4096 word
open(r'D:\claude_workspace\pov3d\zynq_pov\tools\slices_test.bin'.replace('\\','/').replace('D:','/mnt/d'),'wb').write(out)
print(f"slices_test.bin: {len(out)} bytes (8 slices)")
