"""multivox 式切片: 体素化 + 面板像素逐点采样 (slicemap 几何, 无径向补偿—专利红线).
panel 像素 (col=带符号半径 d, row=高度 h) @ 角度 th → 采样 voxel[d·cos, h, d·sin].
1-bit 阈值, v6 DMA 64KB/slice 布局."""
import os, sys, struct, math
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import display_128x128 as dm
from display_128x128 import transform_for_panel1, transform_for_panel2, pack_panel_bin
# 1-bit 数据: 增益旁路 (0.95/0.85 会让 LUT 输出 56/44, bit0=0 → R/B 在 1-bit 模式隐身)
dm.R_GAIN = dm.G_GAIN = dm.B_GAIN = 1.00

SRC = r'D:\claude_workspace\pov3d\zynq_pov\anime_points.bin'
raw = open(SRC,'rb').read()
n = len(raw)//16
pts = np.frombuffer(raw, dtype=np.dtype([('x','<i2'),('y','<i2'),('z','<i2'),('p0','<i2'),
                                         ('r','u1'),('g','u1'),('b','u1'),('p1','u1'),('p2','<i4')]), count=n)
x=pts['x'].astype(np.int32); y=pts['y'].astype(np.int32); z=pts['z'].astype(np.int32)
col=np.stack([pts['r'],pts['g'],pts['b']],axis=1).astype(np.uint8)
print(f'{n} pts, x[{x.min()},{x.max()}] y[{y.min()},{y.max()}] z[{z.min()},{z.max()}]')

# 体素化 128^3, 原点居中 (+64), 1 unit/voxel, last-write
G = 128
vox = np.zeros((G,G,G,3), np.uint8)   # [vx][vy][vz]
vx=np.clip(x+64,0,G-1); vy=np.clip(y+64,0,G-1); vz=np.clip(z+64,0,G-1)
vox[vx,vy,vz] = col
print(f'voxelized: {np.any(vox>0,axis=3).sum()} occupied cells')

N_SLICES = int(sys.argv[1]) if len(sys.argv) > 1 else 360
d  = np.arange(-64,64)                 # 带符号半径 (panel 横向 128 列)
h  = np.arange(-64,64)                 # 高度 (panel 纵向 128 行)
HH, DD = np.meshgrid(h, d, indexing='ij')   # [row(py), col(px)]
out = bytearray()
for a in range(N_SLICES):
    th = 2*math.pi*a/N_SLICES
    c, s = math.cos(th), math.sin(th)
    wx = np.clip(np.rint(DD*c).astype(np.int32)+64, 0, G-1)
    wz = np.clip(np.rint(DD*s).astype(np.int32)+64, 0, G-1)
    wy = np.clip(-HH+64-1, 0, G-1)     # 屏幕 y 向下 → 模型 y 向上
    img_a = vox[wx, wy, wz]            # 128x128x3 gather
    img_a = np.where(img_a >= 128, 255, 0).astype(np.uint8)   # 1-bit 阈值
    img = Image.fromarray(img_a)
    img = img.rotate(180)              # 方向修正 (chess 验证)
    L = img.crop((0,0,64,128)); R = img.crop((64,0,128,128))
    fx = Image.new('RGB',(128,128)); fx.paste(R,(0,0)); fx.paste(L,(64,0))
    t1,b1 = pack_panel_bin(transform_for_panel1(fx.crop((64,0,128,128))))
    t2,b2 = pack_panel_bin(transform_for_panel2(fx.crop((0,0,64,128))))
    out += t2+b2+t1+b1   # 转接板 PANEL_BANK_SWAP
    if a % 90 == 0: print(f'slice {a}: {int((img_a.sum(axis=2)>0).sum())} lit px')
OUT = rf'D:\claude_workspace\pov3d\zynq_pov\tools\anime_slices_{N_SLICES}.bin'
open(OUT,'wb').write(bytes(out))
print(f'{OUT}: {len(out)} bytes ({N_SLICES} multivox-style slices)')
