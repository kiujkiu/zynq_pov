"""政治风地球仪: 自然图分海/陆 → scipy 连通区标记各大洲 → 每洲一糖果色 + 蓝海.
实心球 R=60 (直径120), 8 色: 蓝海 + 绿/黄/品红/青/白/红 大洲. POV 转起来大陆绕竖轴扫.
用法: python _gen_globe_pol.py [N_SLICES]  默认 720"""
import os, sys, math
import numpy as np
from PIL import Image
import scipy.ndimage as ndi
sys.path.insert(0, os.path.dirname(__file__))
import display_128x128 as dm
from display_128x128 import transform_for_panel1, transform_for_panel2, pack_panel_bin
dm.R_GAIN = dm.G_GAIN = dm.B_GAIN = 1.00

N_SLICES = int(sys.argv[1]) if len(sys.argv) > 1 else 720
G, R = 128, 60

# 1) 自然地球图 → 海/陆 → 大洲连通区 → 糖果色政治图
EARTH = r'D:\claude_workspace\pov3d\zynq_pov\tools\earth_equirect.jpg'
earth = np.asarray(Image.open(EARTH).convert('RGB')).astype(np.int32)
H, W = earth.shape[:2]
r0, g0, b0 = earth[...,0], earth[...,1], earth[...,2]
ocean = (b0 > r0 + 8) & (b0 > g0 + 8)          # 蓝 = 海
land = ~ocean
lbl, nreg = ndi.label(land)                     # 4-连通 大洲/岛
sizes = np.bincount(lbl.ravel())
order = np.argsort(-sizes[1:]) + 1              # region id 按面积降序
PAL = [(0,255,0),(255,255,0),(255,0,255),(0,255,255),(255,255,255),(255,0,0)]  # 绿黄品青白红
colmap = np.zeros((H, W, 3), np.uint8)
colmap[ocean] = (0, 0, 255)                     # 海蓝
for i, rid in enumerate(order):
    colmap[lbl == rid] = PAL[i % len(PAL)]      # 每洲一色, 邻洲隔海无所谓重用
print(f'political map: {nreg} land regions, ocean {ocean.mean()*100:.0f}%')

# 2) 实心球 R=60, 体素按方向采样政治图
ax = np.arange(G) - 64.0
X, Y, Z = np.meshgrid(ax, ax, ax, indexing='ij')
rr = np.sqrt(X*X + Y*Y + Z*Z)
inside = rr <= R
rsafe = np.where(rr < 1e-3, 1.0, rr)
lat = np.arcsin(np.clip(Y/rsafe, -1, 1))
lon = np.arctan2(Z, X)
u = (((lon + math.pi) / (2*math.pi)) * W).astype(np.int32) % W
v = np.clip((((math.pi/2 - lat) / math.pi) * (H-1)).astype(np.int32), 0, H-1)
samp = colmap[v, u]
vox = np.zeros((G, G, G, 3), np.uint8)
vox[inside] = samp[inside]
print(f'globe: {int(inside.sum())} solid voxels (R={R}, 直径{2*R})')

# 3) 径向切片 (同 anime/cube)
d = np.arange(-64, 64); h = np.arange(-64, 64)
HH, DD = np.meshgrid(h, d, indexing='ij')
out = bytearray()
for a in range(N_SLICES):
    th = 2*math.pi*a/N_SLICES
    c, s = math.cos(th), math.sin(th)
    wx = np.clip(np.rint(DD*c).astype(np.int32)+64, 0, G-1)
    wz = np.clip(np.rint(DD*s).astype(np.int32)+64, 0, G-1)
    wy = np.clip(-HH+64-1, 0, G-1)
    img_a = vox[wx, wy, wz]
    img_a = np.where(img_a >= 128, 255, 0).astype(np.uint8)
    img = Image.fromarray(img_a).rotate(180)
    L = img.crop((0,0,64,128)); Rc = img.crop((64,0,128,128))
    fx = Image.new('RGB',(128,128)); fx.paste(Rc,(0,0)); fx.paste(L,(64,0))
    t1,b1 = pack_panel_bin(transform_for_panel1(fx.crop((64,0,128,128))))
    t2,b2 = pack_panel_bin(transform_for_panel2(fx.crop((0,0,64,128))))
    out += t2+b2+t1+b1
    if a % 90 == 0: print(f'slice {a}: {int((img_a.sum(axis=2)>0).sum())} lit px')

OUT = rf'D:\claude_workspace\pov3d\zynq_pov\tools\globe_slices_{N_SLICES}.bin'
open(OUT,'wb').write(bytes(out))
print(f'{OUT}: {len(out)} bytes ({N_SLICES} political globe slices)')
