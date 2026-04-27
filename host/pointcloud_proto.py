"""POV3D point-cloud streaming protocol.

Wire format, little-endian:
  offset  size  field
  0       4     magic = 0x50 0x50 0x43 0x4C  ('PPCL')
  4       4     frame_id
  8       4     num_points  (u32: supports >65535 for high-detail one-shots)
  12      2     flags — bit 0: 1=compressed(5B), 0=raw(16B); others reserved
  14      2     reserved
  16      N*pt  points

Raw point (16B): int16 x, y, z, pad0;  u8 r,g,b, pad1;  int32 pad2
Compressed point (5B):
  int8 x, y, z (range ±127, fine for our ±40 typical scale)
  u16 rgb565  (R:5 bits, G:6, B:5 — standard 16-bit color)
"""
import struct

MAGIC = 0x4C435050

HDR_FMT = "<IIIHH"   # magic, fid, num_points (u32), flags (u16), reserved (u16)
HDR_LEN = struct.calcsize(HDR_FMT)
assert HDR_LEN == 16

POINT_FMT_RAW = "<hhhh BBBb i"
POINT_LEN_RAW = struct.calcsize(POINT_FMT_RAW)
assert POINT_LEN_RAW == 16

POINT_FMT_COMPRESSED = "<bbbH"   # x y z rgb565
POINT_LEN_COMPRESSED = struct.calcsize(POINT_FMT_COMPRESSED)
assert POINT_LEN_COMPRESSED == 5

FLAG_COMPRESSED = 0x0001


def _rgb565(r, g, b):
    r = max(0, min(255, int(r))); g = max(0, min(255, int(g))); b = max(0, min(255, int(b)))
    return ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3)


def pack_frame(frame_id, points, compressed=False):
    """points: list of (x, y, z, r, g, b). Returns bytes."""
    n = len(points)
    flags = FLAG_COMPRESSED if compressed else 0
    buf = struct.pack(HDR_FMT, MAGIC, frame_id & 0xFFFFFFFF, n & 0xFFFFFFFF, flags, 0)
    if compressed:
        for x, y, z, r, g, b in points:
            xi = max(-128, min(127, int(x)))
            yi = max(-128, min(127, int(y)))
            zi = max(-128, min(127, int(z)))
            buf += struct.pack(POINT_FMT_COMPRESSED, xi, yi, zi, _rgb565(r, g, b))
    else:
        for x, y, z, r, g, b in points:
            buf += struct.pack(POINT_FMT_RAW, x, y, z, 0, r, g, b, 0, 0)
    return buf
