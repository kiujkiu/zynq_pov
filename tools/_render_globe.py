"""numpy 正交投影渲染 textured sphere 前视图 (无 PBR/无反光), 给 claude/用户看贴图+朝向."""
import os, math, numpy as np
from PIL import Image
TOOLS=r'D:\claude_workspace\pov3d\zynq_pov\tools'
tex=np.asarray(Image.open(os.path.join(TOOLS,'earth_clean.jpg')).convert('RGB'))
H,W=tex.shape[:2]
S=300
img=np.full((S,S,3),30,np.uint8)
yy,xx=np.mgrid[0:S,0:S]
nx=(xx-S/2)/(S/2); ny=-(yy-S/2)/(S/2)   # 屏幕 → [-1,1], y 向上
rr=nx*nx+ny*ny; m=rr<=1.0
nz=np.sqrt(np.clip(1-rr,0,1))
# 视角: 绕 y 轴转 lon0 看不同经度 (这里 lon0=20° 看非洲/印度洋, 跟用户截图一致)
lon0=math.radians(20)
# 球面点 (nx,ny,nz) 已是相机系; 世界系绕 y 反转 lon0
wx= nx*math.cos(lon0)+nz*math.sin(lon0)
wz=-nx*math.sin(lon0)+nz*math.cos(lon0)
wy=ny
lat=np.arcsin(np.clip(wy,-1,1)); lon=np.arctan2(wz,wx)
u=(((lon+math.pi)/(2*math.pi))*(W-1)).astype(int)%W
v=np.clip((((math.pi/2-lat)/math.pi)*(H-1)).astype(int),0,H-1)
col=tex[v,u]
shade=(0.35+0.65*nz)[...,None]   # 轻微漫反射, 体现球体感, 无高光
out=(col*shade).astype(np.uint8)
img[m]=out[m]
Image.fromarray(img).save(os.path.join(TOOLS,'_globe_render.png'))
print('wrote _globe_render.png')
