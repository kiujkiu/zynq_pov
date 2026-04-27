"""One-shot test: sample anime glb, send one PPCL frame to COM10.

Usage:
    python test_send_one.py [z_stretch=5.0] [points=5000] [glb=anime_34.glb]
"""
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import serial
from glb_to_points import sample_glb
from pointcloud_proto import pack_frame

# Args
zs = float(sys.argv[1]) if len(sys.argv) > 1 else 5.0
n  = int(sys.argv[2])   if len(sys.argv) > 2 else 5000
glb = sys.argv[3]       if len(sys.argv) > 3 else os.path.join(HERE, "anime_34.glb")
port = "COM10"
baud = 921600

print(f"sampling {n} pts from {os.path.basename(glb)}, z_stretch={zs}...")
pts = sample_glb(glb, n_points=n, target_scale=40,
                 color_mode="random", brighten=1.5, gamma=0.9,
                 lighting="none",
                 z_stretch=zs, verbose=False)
print(f"  sampled {len(pts)} pts; sample p0={pts[0]}")

z_vals = [p[2] for p in pts]
print(f"  z range: [{min(z_vals)}..{max(z_vals)}]")

print(f"opening {port}@{baud}...")
ser = serial.Serial(port, baud, timeout=0)
buf = pack_frame(0, pts, compressed=True)
print(f"sending {len(buf)} bytes (header + 5×{len(pts)} pts compressed)...")
t0 = time.time()
ser.write(buf)
ser.flush()
dt = time.time() - t0
print(f"  write+flush took {dt:.2f}s")

# Drain board log briefly to catch [rx-dump] confirmation
print("waiting 4 sec for board to ack...")
deadline = time.time() + 4.0
acc = b""
while time.time() < deadline:
    chunk = ser.read(2048)
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
