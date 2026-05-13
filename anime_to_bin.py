"""Voxelize anime GLB and write raw PovPoint binary for JTAG injection.

PovPoint struct (matches helloworld.c, 16 bytes aligned):
  int16_t x, y, z, _pad0;
  uint8_t  r, g, b, _pad1;
  int32_t  _pad2;
"""
import sys, struct
sys.path.insert(0, r"D:\workspace\zynq_pov\host")
from glb_to_points import voxelize_mesh

GLB = r"D:\workspace\zynq_pov\host\anime_62459_baked_warm.glb"
OUT = r"D:\workspace\zynq_pov\anime_points.bin"

print(f"voxelizing {GLB}...", flush=True)
pts = voxelize_mesh(GLB, target_scale=40, z_stretch=1.5, voxel_size=1.0, verbose=False,
                    brighten=1.4, gamma=0.95, saturation=1.4, lighting="none", ambient=1.0)
print(f"  {len(pts)} voxels", flush=True)

# Pack each as 16-byte PovPoint
with open(OUT, "wb") as f:
    for (x, y, z, r, g, b) in pts:
        # Clip int16 range
        x = max(-32768, min(32767, int(x)))
        y = max(-32768, min(32767, int(y)))
        z = max(-32768, min(32767, int(z)))
        r = max(0, min(255, int(r)))
        g = max(0, min(255, int(g)))
        b = max(0, min(255, int(b)))
        # < = little-endian, hhhh = 4× int16, BBBB = 4× uint8, i = int32
        f.write(struct.pack("<4h4Bi", x, y, z, 0, r, g, b, 0, 0))

print(f"wrote {OUT}: {len(pts)*16} bytes ({len(pts)} points)", flush=True)
