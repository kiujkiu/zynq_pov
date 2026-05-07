"""Mesh wire protocol — 三角面 + 顶点色 (int16 coords for sub-pixel precision).

Header (20 B, all little-endian):
    magic       u32   = b'PMSH' = 0x48534D50
    frame_id    u32
    n_verts     u32
    n_tris      u32
    flags       u16   (0 = no special)
    reserved    u16   (0)

Body:
    verts:  n_verts × (xs:i16, ys:i16, zs:i16, r:u8, g:u8, b:u8)  = 9 B/vert
    tris:   n_tris × (i0:u16, i1:u16, i2:u16)                     = 6 B/tri

int16 坐标用 Q8.4 fixed-point: int16 = round(model_coord * 16). 板端 >>4 还原
整数 model coord, 或者 Q8.4 直接送进 rasterizer 提供 sub-pixel 精度.
模型坐标允许 ±2047 unit, 当前 anime model ±100 unit 足够.
"""
import struct

MESH_MAGIC = struct.unpack("<I", b"PMSH")[0]
HDR_FMT = "<IIIIHH"
HDR_SIZE = struct.calcsize(HDR_FMT)
VERT_FMT = "<hhhBBB"
VERT_SIZE = struct.calcsize(VERT_FMT)   # 9
TRI_FMT  = "<HHH"
TRI_SIZE = struct.calcsize(TRI_FMT)     # 6


def pack_mesh(frame_id, vertices, faces, flags=0, q4_scale=16):
    """vertices: list of (x,y,z,r,g,b) — x/y/z 是 model unit float/int, r/g/b u8.
    Q8.4 fix-point: 内部 *16 转 int16. 板端可以 16 还原 model unit, 或者
    保留 Q8.4 做 sub-pixel rasterizer (推荐).
    """
    n_verts = len(vertices)
    n_tris  = len(faces)
    out = bytearray(HDR_SIZE + n_verts * VERT_SIZE + n_tris * TRI_SIZE)
    struct.pack_into(HDR_FMT, out, 0, MESH_MAGIC, frame_id & 0xFFFFFFFF,
                     n_verts, n_tris, flags & 0xFFFF, 0)
    off = HDR_SIZE
    for (x, y, z, r, g, b) in vertices:
        xq = max(-32768, min(32767, int(round(x * q4_scale))))
        yq = max(-32768, min(32767, int(round(y * q4_scale))))
        zq = max(-32768, min(32767, int(round(z * q4_scale))))
        struct.pack_into(VERT_FMT, out, off,
                         xq, yq, zq,
                         max(0, min(255, int(r))),
                         max(0, min(255, int(g))),
                         max(0, min(255, int(b))))
        off += VERT_SIZE
    for (i0, i1, i2) in faces:
        struct.pack_into(TRI_FMT, out, off, i0, i1, i2)
        off += TRI_SIZE
    return bytes(out)
