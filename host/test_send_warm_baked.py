"""跑 agent E warm-bake GLB (anime_62459_baked_warm.glb), lighting=none.

Bake 已含 sun + IBL light 信息 (sunrise.exr + 3-sun warm). 重打 lambert 会过亮发白.
对比基线: test_send_one.py (raw GLB + lambert lighting=Option B).

Usage:
    cd D:\\workspace\\zynq_pov\\host
    python test_send_warm_baked.py [z_stretch=1.5] [points=30000]
"""
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import serial
from glb_to_points import voxelize_mesh
from pointcloud_proto import pack_frame

zs = float(sys.argv[1]) if len(sys.argv) > 1 else 1.5
n  = int(sys.argv[2])   if len(sys.argv) > 2 else 30000
glb = os.path.join(HERE, "anime_62459_baked_warm.glb")
port = "COM4"
baud = 921600

print(f"voxelize_mesh (Option A baked, no relight) {os.path.basename(glb)}, z_stretch={zs}...")
new_pts = voxelize_mesh(glb, target_scale=40, z_stretch=zs, voxel_size=1.0, verbose=True,
                        brighten=1.4, gamma=0.95, saturation=1.4,
                        lighting="none", ambient=1.0)
print(f"  → {len(new_pts)} cells; sample p0={new_pts[0]}")
z_vals = [p[2] for p in new_pts]
print(f"  z range: [{min(z_vals)}..{max(z_vals)}]")

print(f"opening {port}@{baud}...")
ser = serial.Serial(port, baud, timeout=0)
buf = pack_frame(0, new_pts, compressed=True)
print(f"sending {len(buf)} bytes...")
t0 = time.time()
CHUNK = 32768
written = 0
while written < len(buf):
    end = min(written + CHUNK, len(buf))
    written += ser.write(buf[written:end])
    ser.read(8192)
ser.flush()
dt = time.time() - t0
print(f"  write+flush took {dt:.2f}s")

ack_wait = max(4.0, dt * 0.2 + 6.0)
print(f"waiting {ack_wait:.1f} sec for ack...")
deadline = time.time() + ack_wait
acc = b""
while time.time() < deadline:
    chunk = ser.read(8192)
    if chunk:
        acc += chunk
print(acc.decode(errors='replace'))
ser.close()
print("done")
