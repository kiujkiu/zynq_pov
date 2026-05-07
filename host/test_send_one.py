"""One-shot test: sample anime glb, send one PPCL frame to COM10.

Usage:
    python test_send_one.py [z_stretch=5.0] [points=5000] [glb=anime_62459.glb]
"""
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import serial, numpy as np
from glb_to_points import sample_glb, voxelize_mesh
from pointcloud_proto import pack_frame

# Args — defaults match pov_gui.py so HDMI matches the 3D viewer.
zs = float(sys.argv[1]) if len(sys.argv) > 1 else 1.5
n  = int(sys.argv[2])   if len(sys.argv) > 2 else 30000
# Option B: raw glb + voxelize 内置 lambert + multi-dir IBL, 暖光让金发显眼.
# Option A baked 版本 baked 时偏冷色 IBL, anime 金发被压成浅白. 改用 raw + lambert.
glb_default = os.path.join(HERE, "anime_62459.glb")
glb = sys.argv[3] if len(sys.argv) > 3 else glb_default
port = "COM4"
baud = 921600

print(f"voxelize_mesh (Option A: 3D triangle rasterization) {os.path.basename(glb)}, z_stretch={zs}...")
new_pts = voxelize_mesh(glb, target_scale=40, z_stretch=zs, voxel_size=1.0, verbose=True,
                        brighten=1.5, gamma=0.9, saturation=2.0,
                        lighting="lambert", ambient=0.7)
print(f"  → {len(new_pts)} mesh-aware voxel cells; sample p0={new_pts[0]}")
z_vals = [p[2] for p in new_pts]
print(f"  z range: [{min(z_vals)}..{max(z_vals)}]")

print(f"opening {port}@{baud}...")
ser = serial.Serial(port, baud, timeout=0)
buf = pack_frame(0, new_pts, compressed=True)
print(f"sending {len(buf)} bytes (cloud format, host-averaged)...")
# Drain RX during long send to keep PC USB buffer alive
t0 = time.time()
CHUNK = 32768
written = 0
while written < len(buf):
    end = min(written + CHUNK, len(buf))
    written += ser.write(buf[written:end])
    # opportunistic read to keep PC RX buffer drained
    ser.read(8192)
ser.flush()
dt = time.time() - t0
print(f"  write+flush took {dt:.2f}s")

# Drain board log to catch ack (proportional to send time)
ack_wait = max(4.0, dt * 0.2 + 6.0)
print(f"waiting {ack_wait:.1f} sec for board to ack...")
deadline = time.time() + ack_wait
acc = b""
while time.time() < deadline:
    chunk = ser.read(8192)
    if chunk:
        acc += chunk
    else:
        time.sleep(0.05)

print("--- board echo ---")
text = acc.decode("ascii", errors="replace")
for line in text.split("\n"):
    line = line.strip()
    if not line:
        continue
    low = line.lower()
    if low.startswith(("slot ", "frame=", "vdma ", "r=")) or ("park" in low and "curr" in low):
        continue
    print(f"  [board] {line}")

ser.close()
print("done.")
