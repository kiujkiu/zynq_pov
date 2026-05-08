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
from glb_to_mesh import build_simplified_mesh_per_tri
from mesh_proto import pack_mesh_v2

target_tris = int(sys.argv[1]) if len(sys.argv) > 1 else 6000
glb_default = os.path.join(HERE, "anime_62459.glb")
glb = sys.argv[2] if len(sys.argv) > 2 else glb_default
port = "COM4"
baud = 921600

print(f"build_simplified_mesh_per_tri {os.path.basename(glb)} target_tris={target_tris}...")
verts_xyz, tris_with_color = build_simplified_mesh_per_tri(
    glb, target_tris=target_tris, target_scale=40,
    z_stretch=1.5, brighten=1.5, gamma=0.9, saturation=1.4,
    lighting=False, verbose=True)

# Export 一份 PLY 到本地, 用户可用 Windows 3D Viewer / MeshLab 打开对比 3D viewer
ply_path = os.path.join(HERE, "sent_mesh_preview.ply")
with open(ply_path, "w") as f:
    f.write("ply\nformat ascii 1.0\n")
    f.write(f"element vertex {len(verts_xyz)}\n")
    f.write("property float x\nproperty float y\nproperty float z\n")
    f.write(f"element face {len(tris_with_color)}\n")
    f.write("property list uchar int vertex_indices\n")
    f.write("property uchar red\nproperty uchar green\nproperty uchar blue\n")
    f.write("end_header\n")
    for (x, y, z) in verts_xyz:
        f.write(f"{x:.4f} {y:.4f} {z:.4f}\n")
    for (i0, i1, i2, r, g, b) in tris_with_color:
        f.write(f"3 {i0} {i1} {i2} {r} {g} {b}\n")
print(f"  PLY exported -> {ply_path} (MeshLab)")

# 同时输出 GLB (Windows 3D Viewer 可直接双击打开). per-tri color 转
# per-vertex avg 是 GLB 通用约定.
try:
    import trimesh
    import numpy as np
    verts_np = np.array(verts_xyz, dtype=np.float32)
    faces_np = np.array([(t[0], t[1], t[2]) for t in tris_with_color], dtype=np.uint32)
    face_colors = np.array([(t[3], t[4], t[5], 255) for t in tris_with_color], dtype=np.uint8)
    # vertex color = avg of incident face colors
    vcol = np.zeros((len(verts_xyz), 4), dtype=np.float32)
    vcnt = np.zeros(len(verts_xyz), dtype=np.float32)
    for fi, (i0, i1, i2) in enumerate(faces_np):
        for vi in (i0, i1, i2):
            vcol[vi] += face_colors[fi].astype(np.float32)
            vcnt[vi] += 1
    vcol = vcol / np.maximum(vcnt[:, None], 1)
    vcol_u8 = vcol.astype(np.uint8)
    mesh_obj = trimesh.Trimesh(vertices=verts_np, faces=faces_np,
                                vertex_colors=vcol_u8, process=False)
    glb_path = os.path.join(HERE, "sent_mesh_preview.glb")
    mesh_obj.export(glb_path)
    print(f"  GLB exported -> {glb_path} (Windows 3D Viewer)")
except Exception as e:
    print(f"  GLB export skipped: {e}")
print(f"  → {len(verts_xyz)} verts, {len(tris_with_color)} tris (per-tri color)")
print(f"  v0={verts_xyz[0]}  tri0={tris_with_color[0]}")

buf = pack_mesh_v2(0, verts_xyz, tris_with_color)
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
