"""Mesh wire protocol — 三角面 + 顶点色, 替代 voxel point cloud.

Header (20 B, all little-endian):
    magic       u32   = b'PMSH' = 0x48534D50
    frame_id    u32
    n_verts     u32
    n_tris      u32
    flags       u16   (0 = no special)
    reserved    u16   (0)

Body:
    verts:  n_verts × (xs:i8, ys:i8, zs:i8, r:u8, g:u8, b:u8)  = 6 B/vert
    tris:   n_tris × (i0:u16, i1:u16, i2:u16)                  = 6 B/tri

Coords: int8 ±127 → 模型坐标 ±target_scale (≤127).
板端: rotate verts each frame, raster 三角形 with z-buffer + 重心插值.
"""
import struct

MESH_MAGIC = struct.unpack("<I", b"PMSH")[0]
HDR_FMT = "<IIIIHH"
HDR_SIZE = struct.calcsize(HDR_FMT)
VERT_FMT = "<bbbBBB"
VERT_SIZE = struct.calcsize(VERT_FMT)   # 6
TRI_FMT  = "<HHH"
TRI_SIZE = struct.calcsize(TRI_FMT)     # 6


def pack_mesh(frame_id, vertices, faces, flags=0):
    """vertices: list of (x,y,z,r,g,b) ints; faces: list of (i0,i1,i2). Returns bytes."""
    n_verts = len(vertices)
    n_tris  = len(faces)
    out = bytearray(HDR_SIZE + n_verts * VERT_SIZE + n_tris * TRI_SIZE)
    struct.pack_into(HDR_FMT, out, 0, MESH_MAGIC, frame_id & 0xFFFFFFFF,
                     n_verts, n_tris, flags & 0xFFFF, 0)
    off = HDR_SIZE
    for (x, y, z, r, g, b) in vertices:
        struct.pack_into(VERT_FMT, out, off,
                         max(-128, min(127, int(x))),
                         max(-128, min(127, int(y))),
                         max(-128, min(127, int(z))),
                         max(0, min(255, int(r))),
                         max(0, min(255, int(g))),
                         max(0, min(255, int(b))))
        off += VERT_SIZE
    for (i0, i1, i2) in faces:
        struct.pack_into(TRI_FMT, out, off, i0, i1, i2)
        off += TRI_SIZE
    return bytes(out)
