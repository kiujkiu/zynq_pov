"""End-to-end test: voxelize anime GLB and send via WiFi → ESP32 → SDIO → Zynq.

Pipeline: PC (this script) → TCP 10.168.168.103:8888 → ESP32 forwards via SDIO →
Zynq board sdio_esp_recv() feeds PMSH/PPCL parser → renders to HDMI.

Replaces UART (COM4 921600) path of test_send_one.py for the WiFi+SDIO bridge.
"""
import os
import sys
import time
import socket

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from glb_to_points import voxelize_mesh
from pointcloud_proto import pack_frame

HOST = "10.168.168.103"   # ESP32 IP (mDNS pov-bridge.local also works)
PORT = 8888

zs = float(sys.argv[1]) if len(sys.argv) > 1 else 1.5
n_target = int(sys.argv[2]) if len(sys.argv) > 2 else 30000
glb = sys.argv[3] if len(sys.argv) > 3 else os.path.join(HERE, "anime_62459_baked_warm.glb")

print(f"[1/4] voxelize_mesh {os.path.basename(glb)} z_stretch={zs}...")
pts = voxelize_mesh(glb, target_scale=40, z_stretch=zs, voxel_size=1.0, verbose=False,
                    brighten=1.4, gamma=0.95, saturation=1.4,
                    lighting="none", ambient=1.0)
print(f"  → {len(pts)} voxel cells, p0={pts[0]}")

print(f"[2/4] pack_frame...")
buf = pack_frame(0, pts, compressed=True)
print(f"  → {len(buf)} bytes")

print(f"[3/4] TCP connect {HOST}:{PORT}...")
s = socket.create_connection((HOST, PORT), timeout=10)
s.settimeout(15)

print(f"[4/4] sending {len(buf)} bytes...")
t0 = time.time()
sent = 0
CHUNK = 8192
while sent < len(buf):
    end = min(sent + CHUNK, len(buf))
    n = s.send(buf[sent:end])
    if n == 0:
        print(f"  socket send returned 0 at {sent}/{len(buf)}")
        break
    sent += n
dt = time.time() - t0
print(f"  sent {sent} bytes in {dt:.2f}s = {sent/dt/1024:.1f} KB/s = {sent*8/dt/1e6:.2f} Mbps")

s.close()
print("done. Check Zynq UART (COM4 921600) for [rxdone] log + HDMI for anime.")
