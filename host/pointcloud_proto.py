"""Minimal POV3D point-cloud streaming protocol (prototype).

Wire format, little-endian:
  offset  size  field
  0       4     magic = 0x50 0x50 0x43 0x4C  ('PPCL')
  4       4     frame_id (uint32)
  8       2     num_points (uint16)
  10      2     flags (uint16) - reserved, set 0
  12      4     reserved (uint32, set 0)
  16      16*N  point array (each: int16 x, y, z, pad;  u8 r, g, b, pad;  int32 pad)

Total frame size = 16 + 16 * num_points bytes.
"""
import struct

MAGIC = 0x4C435050  # 'PPCL' little-endian = 0x50 0x50 0x43 0x4C

HDR_FMT = "<IIHHI"   # magic, frame_id, num_points, flags, reserved
HDR_LEN = struct.calcsize(HDR_FMT)
assert HDR_LEN == 16

POINT_FMT = "<hhhh BBBb i"   # x y z pad0(i16) r g b pad1(b) pad2(i32)
POINT_LEN = struct.calcsize(POINT_FMT)
assert POINT_LEN == 16, f"point size {POINT_LEN}"

def pack_frame(frame_id, points):
    """points is list of (x, y, z, r, g, b). Returns bytes."""
    n = len(points)
    buf = struct.pack(HDR_FMT, MAGIC, frame_id & 0xFFFFFFFF, n, 0, 0)
    for x, y, z, r, g, b in points:
        buf += struct.pack(POINT_FMT, x, y, z, 0, r, g, b, 0, 0)
    return buf
