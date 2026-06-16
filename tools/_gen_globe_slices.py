"""地球 globe 切片: 程序化实心球体 (R=52), 每体素按方向投影采样 equirect 地球图,
分类 1-bit 配色 蓝海/绿陆/白冰. poles 竖直 (POV 转起来大陆绕竖轴扫). 同 panel 链.
用法: python _gen_globe_slices.py [N_SLICES]  默认 720"""
import os, sys, math
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import display_128x128 as dm
from display_128x128 import transform_for_panel1, transform_for_panel2, pack_panel_bin
import _q15
dm.R_GAIN = dm.G_GAIN = dm.B_GAIN = 1.00   # 1-bit 旁路增益

N_SLICES = int(sys.argv[1]) if len(sys.argv) > 1 else 720
G, R = 128, 60   # 直径 120

# 地球 equirect 图
EARTH = r'D:\claude_workspace\pov3d\zynq_pov\tools\earth_clean.jpg'
earth = np.asarray(Image.open(EARTH).convert('RGB'))
H, W = earth.shape[:2]
print(f'earth map {W}x{H}')

# 实心球体, 体素按方向 (lat,lon) 采样地球图
ax = np.arange(G) - 64.0
X, Y, Z = np.meshgrid(ax, ax, ax, indexing='ij')   # [vx][vy][vz]
rr = np.sqrt(X*X + Y*Y + Z*Z)
TH = 3                                              # 壳厚 (voxel)
inside = (rr <= R) & (rr >= R - TH)                 # 空心壳: 只表面, 每片圆环
rsafe = np.where(rr < 1e-3, 1.0, rr)
lat = np.arcsin(np.clip(Y/rsafe, -1, 1))            # y 是极轴 → 纬度
lon = np.arctan2(Z, X)                              # 经度
u = (((lon + math.pi) / (2*math.pi)) * W).astype(np.int32) % W
v = np.clip((((math.pi/2 - lat) / math.pi) * (H-1)).astype(np.int32), 0, H-1)
samp = earth[v, u]                                  # [vx][vy][vz][3]
r_ = samp[...,0].astype(np.int32); g_ = samp[...,1].astype(np.int32); b_ = samp[...,2].astype(np.int32)

ocean = (b_ > g_ + 10) & (b_ > r_ + 10)
ice   = (r_ > 170) & (g_ > 170) & (b_ > 170)
vox = np.zeros((G, G, G, 3), np.uint8)
vox[inside] = [0, 255, 0]      # 默认陆地 绿
vox[inside & ocean] = [0, 0, 255]      # 海洋 蓝
vox[inside & ice]   = [255, 255, 255]  # 冰盖/云 白
print(f'globe: {int(inside.sum())} solid voxels (R={R})')

# multivox 式径向切片 (同 anime/cube)
d = np.arange(-64, 64); h = np.arange(-64, 64)
HH, DD = np.meshgrid(h, d, indexing='ij')
out = bytearray()
for a in range(N_SLICES):
    wxq, wzq = _q15.sample_xz(DD, a)   # Q15 定点, 跟板端 HLS pov_proj.cpp 逐位一致
    wx = np.clip(wxq.astype(np.int32)+64, 0, G-1)
    wz = np.clip(wzq.astype(np.int32)+64, 0, G-1)
    wy = np.clip(-HH+64-1, 0, G-1)
    img_a = vox[wx, wy, wz]
    img_a = np.where(img_a >= 128, 255, 0).astype(np.uint8)   # 1-bit 阈值
    img = Image.fromarray(img_a)
    img = img.rotate(180)
    L = img.crop((0,0,64,128)); Rc = img.crop((64,0,128,128))
    fx = Image.new('RGB',(128,128)); fx.paste(Rc,(0,0)); fx.paste(L,(64,0))
    t1,b1 = pack_panel_bin(transform_for_panel1(fx.crop((64,0,128,128))))
    t2,b2 = pack_panel_bin(transform_for_panel2(fx.crop((0,0,64,128))))
    out += t2+b2+t1+b1
    if a % 90 == 0: print(f'slice {a}: {int((img_a.sum(axis=2)>0).sum())} lit px')

OUT = rf'D:\claude_workspace\pov3d\zynq_pov\tools\globe_slices_{N_SLICES}.bin'
open(OUT,'wb').write(bytes(out))
print(f'{OUT}: {len(out)} bytes ({N_SLICES} globe slices)')
