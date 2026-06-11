with open(r'D:\claude_workspace\pov3d\zynq_pov\tools\fb_anime_128_top1.bin', 'rb') as f:
    d = f.read(16)
words = [int.from_bytes(d[i:i+4], 'little') for i in range(0, 16, 4)]
print('top1.bin hw[0][0..3]:')
for i, w in enumerate(words):
    r = w & 0xff
    g = (w >> 8) & 0xff
    b = (w >> 16) & 0xff
    print(f'  word[{i}] = 0x{w:08x} (R={r} G={g} B={b})')

# Also read last few words = hw[0][124..127]
with open(r'D:\claude_workspace\pov3d\zynq_pov\tools\fb_anime_128_top1.bin', 'rb') as f:
    f.seek(127*4)
    d = f.read(4)
w = int.from_bytes(d, 'little')
r = w & 0xff; g = (w >> 8) & 0xff; b = (w >> 16) & 0xff
print(f'top1.bin hw[0][127] = 0x{w:08x} (R={r} G={g} B={b})')
