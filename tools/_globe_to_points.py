"""globe voxel_t 网格 (tb_globe_voxel.bin, 128³×4B r,g,b,pad) → 点云 point_t (raw, 无头).
每个非零 voxel → 一个点 (x=vx-64,y=vy-64,z=vz-64, r,g,b自带). 供 B1 测试用地球仪."""
import numpy as np, struct
G=128
v=np.fromfile(r'D:\claude_workspace\pov3d\zynq_pov\02_hello_zynq\hls_pov\tb_globe_voxel.bin',dtype=np.uint8).reshape(G,G,G,4)
occ=np.argwhere((v[...,0]|v[...,1]|v[...,2])>0)   # 非零 voxel 坐标 [vx,vy,vz]
print(f'{len(occ)} occupied voxels')
out=bytearray()
for (vx,vy,vz) in occ:
    r,g,b=int(v[vx,vy,vz,0]),int(v[vx,vy,vz,1]),int(v[vx,vy,vz,2])
    out+=struct.pack('<4h4Bi', vx-64, vy-64, vz-64, 0, r,g,b,0, 0)
open(r'D:\claude_workspace\pov3d\zynq_pov\globe_points.bin','wb').write(bytes(out))
print(f'globe_points.bin: {len(out)} bytes = {len(out)//16} points')
