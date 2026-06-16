"""生成地球仪 glb (带贴图 UV 球体) 供 3D viewer 预览.
贴图可选: natural (Blue Marble 自然图) 或 political (大洲糖果色).
用法: python _make_globe_glb.py [natural|political]   默认 natural"""
import os, sys, math
import numpy as np
from PIL import Image
import trimesh

MODE = sys.argv[1] if len(sys.argv) > 1 else 'natural'
TOOLS = r'D:\claude_workspace\pov3d\zynq_pov\tools'
R = 60.0
NLAT, NLON = 180, 360   # 球体网格密度

# ---- 贴图 ----
if MODE == 'political':
    import scipy.ndimage as ndi
    earth = np.asarray(Image.open(os.path.join(TOOLS,'earth_equirect.jpg')).convert('RGB')).astype(np.int32)
    H, W = earth.shape[:2]
    r0,g0,b0 = earth[...,0],earth[...,1],earth[...,2]
    ocean = (b0>r0+8)&(b0>g0+8); land=~ocean
    lbl,nreg = ndi.label(land); sizes=np.bincount(lbl.ravel())
    order=np.argsort(-sizes[1:])+1
    PAL=[(0,200,60),(240,220,40),(220,60,200),(40,200,220),(240,240,240),(230,60,60)]
    cm=np.zeros((H,W,3),np.uint8); cm[ocean]=(20,90,220)
    for i,rid in enumerate(order): cm[lbl==rid]=PAL[i%len(PAL)]
    tex=Image.fromarray(cm); print(f'political tex {W}x{H}, {nreg} regions')
else:
    tex=Image.open(os.path.join(TOOLS,'earth_clean.jpg')).convert('RGB')
    print(f'natural tex {tex.size}')

# ---- UV 球体 (equirect UV, y 极轴) ----
lats=np.linspace(math.pi/2,-math.pi/2,NLAT)
lons=np.linspace(-math.pi,math.pi,NLON)
verts=[]; uvs=[]
for lat in lats:
    cl,sl=math.cos(lat),math.sin(lat)
    for lon in lons:
        verts.append([cl*math.cos(lon)*R, sl*R, cl*math.sin(lon)*R])
        uvs.append([(lon+math.pi)/(2*math.pi), (math.pi/2-lat)/math.pi])
verts=np.array(verts,np.float32); uvs=np.array(uvs,np.float32)
faces=[]
for i in range(NLAT-1):
    for j in range(NLON-1):
        a=i*NLON+j; b=a+1; c=a+NLON; d=c+1
        faces.append([a,c,b]); faces.append([b,c,d])
faces=np.array(faces,np.int64)

# unlit 材质: baseColor 黑 + emissive=贴图 → 纯平显示纹理, 无高光无反光无环境反射.
# (PBR metallic=0/rough=1 在有些 viewer 仍被 IBL 环境反射, emissive 彻底无光照)
from trimesh.visual.material import PBRMaterial
mat=PBRMaterial(baseColorFactor=[0,0,0,255], emissiveTexture=tex, emissiveFactor=[1.0,1.0,1.0],
                doubleSided=False, alphaMode='OPAQUE', metallicFactor=0.0, roughnessFactor=1.0)
vis=trimesh.visual.TextureVisuals(uv=uvs, material=mat)
mesh=trimesh.Trimesh(vertices=verts, faces=faces, visual=vis, process=False)
# 强制法线朝外 (面法线·质心 应 > 0; <0 说明绕序反 → invert)
outward=(mesh.triangles_center * mesh.face_normals).sum(axis=1)
if outward.mean() < 0:
    mesh.invert(); print('flipped winding -> normals outward')
mesh.vertex_normals  # 触发重算
OUT=os.path.join(TOOLS, f'globe_{MODE}.glb')
mesh.export(OUT)
print(f'wrote {OUT}: {len(verts)} verts, {len(faces)} faces')
# 也拷一份到 codexflow assets 方便预览
import shutil
dst=r'C:\Users\kiujkiu\AppData\Roaming\codexflow\assets\pov3d\globe_'+MODE+'.glb'
try: shutil.copy(OUT,dst); print(f'copied -> {dst}')
except Exception as e: print('copy skip:',e)
