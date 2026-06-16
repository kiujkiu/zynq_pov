"""产 TB 输入: globe voxel grid (128^3 x 4B voxel_t r,g,b,pad) + 复制 transform_lut.bin.
voxel 用 1-bit 阈值后的 0/255 (跟 _gen_globe_slices 一致), 这样 IP 阈值 >=128 等价."""
import numpy as np, math, os
TOOLS=r'D:\claude_workspace\pov3d\zynq_pov\tools'
OUT=r'D:\claude_workspace\pov3d\zynq_pov\02_hello_zynq\hls_pov'
G,R,TH=128,60,3
from PIL import Image
earth=np.asarray(Image.open(os.path.join(TOOLS,'earth_clean.jpg')).convert('RGB'))
H,W=earth.shape[:2]
ax=np.arange(G)-64.0
X,Y,Z=np.meshgrid(ax,ax,ax,indexing='ij')
rr=np.sqrt(X*X+Y*Y+Z*Z); inside=(rr<=R)&(rr>=R-TH)
rs=np.where(rr<1e-3,1.0,rr); lat=np.arcsin(np.clip(Y/rs,-1,1)); lon=np.arctan2(Z,X)
u=(((lon+math.pi)/(2*math.pi))*W).astype(np.int32)%W
v=np.clip((((math.pi/2-lat)/math.pi)*(H-1)).astype(np.int32),0,H-1)
samp=earth[v,u]; r_=samp[...,0].astype(np.int32);g_=samp[...,1].astype(np.int32);b_=samp[...,2].astype(np.int32)
ocean=(b_>g_+10)&(b_>r_+10); ice=(r_>170)&(g_>170)&(b_>170)
vox=np.zeros((G,G,G,3),np.uint8)
vox[inside]=[0,255,0]; vox[inside&ocean]=[0,0,255]; vox[inside&ice]=[255,255,255]
# 1-bit 阈值 (与 _gen_globe_slices img_a>=128->255 一致)
voxb=np.where(vox>=128,255,0).astype(np.uint8)
# voxel_t = r,g,b,pad. grid 索引 (wx*128+wy)*128+wz, channel order r,g,b
out=np.zeros((G,G,G,4),np.uint8)
out[...,0]=voxb[...,0]; out[...,1]=voxb[...,1]; out[...,2]=voxb[...,2]
out.tofile(os.path.join(OUT,'tb_globe_voxel.bin'))
print('wrote tb_globe_voxel.bin',out.nbytes,'bytes (128^3 x4)')
# 复制 LUT
import shutil; shutil.copy(os.path.join(TOOLS,'transform_lut.bin'),os.path.join(OUT,'tb_transform_lut.bin'))
print('copied transform_lut.bin')
# 复制 golden compact (globe)
shutil.copy(os.path.join(TOOLS,'globe_slices_720_compact.bin'),os.path.join(OUT,'tb_globe_golden_compact.bin'))
print('copied globe_slices_720_compact.bin as golden')
