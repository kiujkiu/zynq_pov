"""Mesh wire protocol v2 — per-tri color (flat shading).

Header (20 B, all little-endian):
    magic       u32   = b'PMSH' = 0x48534D50
    frame_id    u32
    n_verts     u32
    n_tris      u32
    flags       u16   bit 0 = PER_TRI_COLOR (v2)
    reserved    u16

Body:
    flags & 1 == 0 (v1, vert color):
        verts:  n_verts × (xs:i16, ys:i16, zs:i16, r:u8, g:u8, b:u8)  = 9 B
        tris:   n_tris × (i0:u16, i1:u16, i2:u16)                     = 6 B
    flags & 1 == 1 (v2, per-tri color, flat shading):
        verts:  n_verts × (xs:i16, ys:i16, zs:i16)                    = 6 B
        tris:   n_tris × (i0:u16, i1:u16, i2:u16, r:u8, g:u8, b:u8)   = 9 B

v2 颜色质量更高 (per-tri 直接 sample texture, 不被邻居 dominant 抢),
wire 增加约 15%. 板端 rasterizer 用 flat shading.
"""
import struct

MESH_MAGIC = struct.unpack("<I", b"PMSH")[0]
HDR_FMT = "<IIIIHH"
HDR_SIZE = struct.calcsize(HDR_FMT)

# v1 (vert color)
VERT_FMT_V1 = "<hhhBBB"
VERT_SIZE_V1 = struct.calcsize(VERT_FMT_V1)   # 9
TRI_FMT_V1  = "<HHH"
TRI_SIZE_V1 = struct.calcsize(TRI_FMT_V1)     # 6

# v2 (per-tri color)
VERT_FMT_V2 = "<hhh"
VERT_SIZE_V2 = struct.calcsize(VERT_FMT_V2)   # 6
TRI_FMT_V2  = "<HHHBBB"
TRI_SIZE_V2 = struct.calcsize(TRI_FMT_V2)     # 9

FLAG_PER_TRI_COLOR = 0x0001

# Backward-compat aliases (existing board/host code expects these).
VERT_FMT  = VERT_FMT_V1
VERT_SIZE = VERT_SIZE_V1
TRI_FMT   = TRI_FMT_V1
TRI_SIZE  = TRI_SIZE_V1


def pack_mesh(frame_id, vertices, faces, flags=0, q4_scale=16):
    """v1 (vert-color) packing. vertices: (x,y,z,r,g,b), faces: (i0,i1,i2)."""
    n_verts = len(vertices)
    n_tris  = len(faces)
    out = bytearray(HDR_SIZE + n_verts * VERT_SIZE_V1 + n_tris * TRI_SIZE_V1)
    struct.pack_into(HDR_FMT, out, 0, MESH_MAGIC, frame_id & 0xFFFFFFFF,
                     n_verts, n_tris, flags & 0xFFFF, 0)
    off = HDR_SIZE
    for (x, y, z, r, g, b) in vertices:
        xq = max(-32768, min(32767, int(round(x * q4_scale))))
        yq = max(-32768, min(32767, int(round(y * q4_scale))))
        zq = max(-32768, min(32767, int(round(z * q4_scale))))
        struct.pack_into(VERT_FMT_V1, out, off, xq, yq, zq,
                         max(0, min(255, int(r))),
                         max(0, min(255, int(g))),
                         max(0, min(255, int(b))))
        off += VERT_SIZE_V1
    for (i0, i1, i2) in faces:
        struct.pack_into(TRI_FMT_V1, out, off, i0, i1, i2)
        off += TRI_SIZE_V1
    return bytes(out)


def pack_mesh_v2(frame_id, vertices_xyz, faces_with_color, q4_scale=16):
    """v2 per-tri color packing.
    vertices_xyz: list of (x, y, z) float
    faces_with_color: list of (i0, i1, i2, r, g, b)
    """
    n_verts = len(vertices_xyz)
    n_tris  = len(faces_with_color)
    flags = FLAG_PER_TRI_COLOR
    out = bytearray(HDR_SIZE + n_verts * VERT_SIZE_V2 + n_tris * TRI_SIZE_V2)
    struct.pack_into(HDR_FMT, out, 0, MESH_MAGIC, frame_id & 0xFFFFFFFF,
                     n_verts, n_tris, flags & 0xFFFF, 0)
    off = HDR_SIZE
    for (x, y, z) in vertices_xyz:
        xq = max(-32768, min(32767, int(round(x * q4_scale))))
        yq = max(-32768, min(32767, int(round(y * q4_scale))))
        zq = max(-32768, min(32767, int(round(z * q4_scale))))
        struct.pack_into(VERT_FMT_V2, out, off, xq, yq, zq)
        off += VERT_SIZE_V2
    for (i0, i1, i2, r, g, b) in faces_with_color:
        struct.pack_into(TRI_FMT_V2, out, off, i0, i1, i2,
                         max(0, min(255, int(r))),
                         max(0, min(255, int(g))),
                         max(0, min(255, int(b))))
        off += TRI_SIZE_V2
    return bytes(out)
