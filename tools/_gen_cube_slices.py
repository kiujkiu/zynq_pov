"""六面体 (cube) 切片: 体素化一个空心立方体, 6 个面各一颜色, multivox 式逐点采样.
颜色用 1-bit-per-channel 的 6 个纯色: R/G/B/Y/C/M. 跟 _gen_anime_slices.py 同切片/panel 链.
用法: python _gen_cube_slices.py [N_SLICES]   默认 720"""
import os, sys, math
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import display_128x128 as dm
from display_128x128 import transform_for_panel1, transform_for_panel2, pack_panel_bin
dm.R_GAIN = dm.G_GAIN = dm.B_GAIN = 1.00   # 1-bit: 旁路增益

N_SLICES = int(sys.argv[1]) if len(sys.argv) > 1 else 720

# 体素化 128^3, 原点居中 (+64). 空心立方体, 6 面各一色, 壳厚 t.
G = 128
vox = np.zeros((G, G, G, 3), np.uint8)   # [vx][vy][vz]
HALF = 40                                 # 立方体半边长 (边长 80, 落在 ±64 内)
lo, hi = 64 - HALF, 64 + HALF             # 24 .. 104
t = 3                                     # 壳厚 (voxel)

# 6 个面: (轴, 位置, 颜色). 纯色 1-bit/通道.
RED, GRN, BLU = (255,0,0), (0,255,0), (0,0,255)
YEL, CYN, MAG = (255,255,0), (0,255,255), (255,0,255)
faces = [('x', lo, RED), ('x', hi, GRN),
         ('y', lo, BLU), ('y', hi, YEL),
         ('z', lo, CYN), ('z', hi, MAG)]

for axis, pos, col in faces:
    c = np.array(col, np.uint8)
    if axis == 'x':
        a0, a1 = (pos, pos+t) if pos == lo else (pos-t, pos)
        vox[a0:a1, lo:hi, lo:hi] = c
    elif axis == 'y':
        a0, a1 = (pos, pos+t) if pos == lo else (pos-t, pos)
        vox[lo:hi, a0:a1, lo:hi] = c
    else:  # z
        a0, a1 = (pos, pos+t) if pos == lo else (pos-t, pos)
        vox[lo:hi, lo:hi, a0:a1] = c
print(f'cube voxelized: {np.any(vox>0,axis=3).sum()} shell cells, edge {2*HALF}')

# multivox 式切片采样 (跟 anime gen 完全一致)
d = np.arange(-64, 64)
h = np.arange(-64, 64)
HH, DD = np.meshgrid(h, d, indexing='ij')
out = bytearray()
for a in range(N_SLICES):
    th = 2*math.pi*a/N_SLICES
    c, s = math.cos(th), math.sin(th)
    wx = np.clip(np.rint(DD*c).astype(np.int32)+64, 0, G-1)
    wz = np.clip(np.rint(DD*s).astype(np.int32)+64, 0, G-1)
    wy = np.clip(-HH+64-1, 0, G-1)
    img_a = vox[wx, wy, wz]
    img_a = np.where(img_a >= 128, 255, 0).astype(np.uint8)   # 1-bit 阈值
    img = Image.fromarray(img_a)
    img = img.rotate(180)                # 方向修正 (chess 验证)
    L = img.crop((0,0,64,128)); R = img.crop((64,0,128,128))
    fx = Image.new('RGB',(128,128)); fx.paste(R,(0,0)); fx.paste(L,(64,0))
    t1,b1 = pack_panel_bin(transform_for_panel1(fx.crop((64,0,128,128))))
    t2,b2 = pack_panel_bin(transform_for_panel2(fx.crop((0,0,64,128))))
    out += t2+b2+t1+b1   # 转接板 PANEL_BANK_SWAP
    if a % 90 == 0: print(f'slice {a}: {int((img_a.sum(axis=2)>0).sum())} lit px')

OUT = rf'D:\claude_workspace\pov3d\zynq_pov\tools\cube_slices_{N_SLICES}.bin'
open(OUT,'wb').write(bytes(out))
print(f'{OUT}: {len(out)} bytes ({N_SLICES} cube slices)')
