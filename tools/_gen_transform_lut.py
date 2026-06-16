"""固化 panel 坐标变换为静态 LUT, 让 ARM/PL 不用重写 rotate/flip/bankswap/pack.
追踪每个 img_a(row,col) → 最终 64KB 全格式 slice 的 word index, 反出
  LUT[full_word_index] = (d = col-64, wy = 127-row)
ARM 逐角度: wx=round(d*cosθ)+64, wz=round(d*sinθ)+64, 采样 vox[wx][wy][wz], 阈值, pack.
内容无关, 算一次. 自验证: 用 LUT 重建一片地球 == _gen_globe_slices 的 compact 输出.
"""
import os, sys, math
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from display_128x128 import transform_for_panel1, transform_for_panel2

# ---- 1) 追踪几何: img_a(row,col) → panel hw pixel → full_word_index ----
idx = np.arange(128*128, dtype=np.int32).reshape(128,128)   # [row][col] = row*128+col
enc = np.zeros((128,128,3), np.uint8)
enc[...,0] = (idx >> 8).astype(np.uint8)      # 高 6 bit
enc[...,1] = (idx & 0xFF).astype(np.uint8)    # 低 8 bit
img = Image.fromarray(enc).rotate(180)
L = img.crop((0,0,64,128)); Rc = img.crop((64,0,128,128))
fx = Image.new('RGB',(128,128)); fx.paste(Rc,(0,0)); fx.paste(L,(64,0))
p1 = np.asarray(transform_for_panel1(fx.crop((64,0,128,128))))  # [hw_row 0..63][hw_col 0..127][3]
p2 = np.asarray(transform_for_panel2(fx.crop((0,0,64,128))))

# full slice 顺序: t2,b2,t1,b1 (转接板 bank swap). 每块 4096 word = hw_row*128+hw_col.
lut_d  = np.zeros(16384, np.int16)
lut_wy = np.zeros(16384, np.int16)
def decode(pan, base):
    for hw_row in range(64):
        for hw_col in range(128):
            px = pan[hw_row, hw_col]
            src = (int(px[0])<<8) | int(px[1])
            row, col = src//128, src%128
            blk = base + (0 if hw_row<32 else 4096)
            fwi = blk + (hw_row%32)*128 + hw_col
            lut_d[fwi]  = col - 64        # d
            lut_wy[fwi] = 127 - row       # wy (与角度无关)
decode(p2, 0)        # t2/b2
decode(p1, 8192)     # t1/b1

LUT = np.stack([lut_d, lut_wy], axis=1).astype(np.int16)  # [16384][2]
OUT = r'D:\claude_workspace\pov3d\zynq_pov\tools\transform_lut.bin'
LUT.tofile(OUT)
print(f'wrote {OUT}: {LUT.nbytes} bytes (16384 × int16 d,wy)')

# ---- 2) 自验证: 用 LUT 重建地球一片, 跟原管线 compact 比对 ----
# 重建地球 vox (同 _gen_globe_slices)
G, R, TH = 128, 60, 3
earth = np.asarray(Image.open(r'D:\claude_workspace\pov3d\zynq_pov\tools\earth_clean.jpg').convert('RGB'))
H, W = earth.shape[:2]
ax = np.arange(G)-64.0
X,Y,Z = np.meshgrid(ax,ax,ax, indexing='ij')
rr = np.sqrt(X*X+Y*Y+Z*Z); shell=(rr<=R)&(rr>=R-TH)
rs=np.where(rr<1e-3,1.0,rr); lat=np.arcsin(np.clip(Y/rs,-1,1)); lon=np.arctan2(Z,X)
u=(((lon+math.pi)/(2*math.pi))*W).astype(int)%W; v=np.clip((((math.pi/2-lat)/math.pi)*(H-1)).astype(int),0,H-1)
vox=np.zeros((G,G,G,3),np.uint8); vox[shell]=earth[v,u][shell]

def slice_via_lut(a):
    th=2*math.pi*a/720; c,s=math.cos(th),math.sin(th)
    d=LUT[:,0].astype(np.float64); wy=LUT[:,1].astype(np.int32)
    wx=np.clip(np.rint(d*c).astype(np.int32)+64,0,127)
    wz=np.clip(np.rint(d*s).astype(np.int32)+64,0,127)
    rgb=vox[wx,wy,wz]                       # [16384][3]
    on=(rgb>=128)                           # 阈值
    Gb,Bb,Rb=on[:,1],on[:,2],on[:,0]
    lane=(Gb.astype(np.uint32))|(Bb.astype(np.uint32)<<1)|(Rb.astype(np.uint32)<<2)
    lane=lane.reshape(2048,8)
    word=np.zeros(2048,np.uint32)
    for k in range(8): word|=lane[:,k]<<(k*3)
    return word

# 原管线 compact (复用 _gen + _pack 逻辑, 单片)
from display_128x128 import pack_panel_bin
import display_128x128 as dm
dm.R_GAIN=dm.G_GAIN=dm.B_GAIN=1.0
def slice_via_pc(a):
    th=2*math.pi*a/720; c,s=math.cos(th),math.sin(th)
    d=np.arange(-64,64); h=np.arange(-64,64); HH,DD=np.meshgrid(h,d,indexing='ij')
    wx=np.clip(np.rint(DD*c).astype(np.int32)+64,0,127); wz=np.clip(np.rint(DD*s).astype(np.int32)+64,0,127)
    wy=np.clip(-HH+64-1,0,127)
    ia=vox[wx,wy,wz]; ia=np.where(ia>=128,255,0).astype(np.uint8)
    im=Image.fromarray(ia).rotate(180)
    Ll=im.crop((0,0,64,128)); Rr=im.crop((64,0,128,128))
    f=Image.new('RGB',(128,128)); f.paste(Rr,(0,0)); f.paste(Ll,(64,0))
    t1,b1=pack_panel_bin(transform_for_panel1(f.crop((64,0,128,128))))
    t2,b2=pack_panel_bin(transform_for_panel2(f.crop((0,0,64,128))))
    full=np.frombuffer(t2+b2+t1+b1,dtype='<u4').reshape(2048,8)
    lane=(((full>>0)&1)<<1)|(((full>>8)&1)<<2)|(((full>>16)&1)<<0)
    word=np.zeros(2048,np.uint32)
    for k in range(8): word|=lane[:,k].astype(np.uint32)<<(k*3)
    return word

bad=0
for a in (0,1,90,123,359,500,719):
    if not np.array_equal(slice_via_lut(a), slice_via_pc(a)):
        bad+=1; print(f'  angle {a}: MISMATCH')
print('VERIFY:', 'ALL MATCH OK' if bad==0 else f'{bad} MISMATCH')
