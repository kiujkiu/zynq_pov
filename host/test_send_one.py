"""One-shot test: sample anime glb, send one PPCL frame to COM10.

Usage:
    python test_send_one.py [z_stretch=5.0] [points=5000] [glb=anime_62459.glb]
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
glb = sys.argv[3]       if len(sys.argv) > 3 else os.path.join(HERE, "anime_62459.glb")
port = "COM10"
baud = 921600

print(f"sampling {n} pts from {os.path.basename(glb)}, z_stretch={zs}...")
pts = sample_glb(glb, n_points=n, target_scale=40,
                 color_mode="keep", brighten=1.0, gamma=1.0,
                 lighting="studio", ambient=0.3,
                 z_stretch=zs, verbose=False,
                 crop_top_frac=0.0)
print(f"  sampled {len(pts)} pts; sample p0={pts[0]}")

z_vals = [p[2] for p in pts]
print(f"  z range: [{min(z_vals)}..{max(z_vals)}]")

print(f"opening {port}@{baud}...")
ser = serial.Serial(port, baud, timeout=0)
buf = pack_frame(0, pts, compressed=True)
print(f"sending {len(buf)} bytes (header + 5×{len(pts)} pts compressed)...")
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
