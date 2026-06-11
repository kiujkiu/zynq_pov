"""Check how many unique colors are in a bin file."""
import struct
for name in ['top1', 'bot1', 'top2', 'bot2']:
    path = rf'D:\claude_workspace\pov3d\zynq_pov\tools\fb_anime_128_{name}.bin'
    with open(path, 'rb') as f:
        data = f.read()
    colors = set()
    for i in range(0, len(data), 4):
        w = struct.unpack('<I', data[i:i+4])[0]
        colors.add(w & 0xFFFFFF)
    print(f"{name}.bin: {len(colors)} unique colors")
    if len(colors) <= 16:
        print(f"  colors: {[hex(c) for c in sorted(colors)]}")
