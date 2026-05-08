"""One-shot: load anime, simplify to ~1K triangles, send via mesh wire to board.

Usage:
    python test_send_mesh.py [target_tris=1024] [glb=anime_62459.glb]
"""
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import serial
from glb_to_mesh import build_simplified_mesh_textured
from mesh_proto import pack_mesh_v3

target_tris = int(sys.argv[1]) if len(sys.argv) > 1 else 6000
glb_default = os.path.join(HERE, "anime_62459.glb")
glb = sys.argv[2] if len(sys.argv) > 2 else glb_default
tex_size = int(sys.argv[3]) if len(sys.argv) > 3 else 256
port = "COM4"
baud = 921600

print(f"build textured {os.path.basename(glb)} tris={target_tris} tex={tex_size}...")
verts_xyz_uv, tris, tex_bytes, tex_w, tex_h = build_simplified_mesh_textured(
    glb, target_tris=target_tris, target_scale=40, z_stretch=1.5,
    tex_size=tex_size, verbose=True)
print(f"  → {len(verts_xyz_uv)} verts, {len(tris)} tris, tex {tex_w}×{tex_h}")
print(f"  v0={verts_xyz_uv[0]}  tri0={tris[0]}")

buf = pack_mesh_v3(0, verts_xyz_uv, tris, tex_bytes, tex_w, tex_h)
print(f"opening {port}@{baud}...")
ser = serial.Serial(port, baud, timeout=0)
print(f"sending {len(buf)} bytes (mesh wire)...")
t0 = time.time()
CHUNK = 32768
written = 0
while written < len(buf):
    end = min(written + CHUNK, len(buf))
    written += ser.write(buf[written:end])
    ser.read(8192)   # drain RX
ser.flush()
dt = time.time() - t0
print(f"  write+flush {dt:.2f}s")

# Drain board log
ack_wait = max(2.0, dt * 0.2 + 3.0)
print(f"waiting {ack_wait:.1f} sec for board ack...")
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
    if low.startswith(("frame=",)):
        continue
    print(f"  [board] {line}")

ser.close()
print("done.")
