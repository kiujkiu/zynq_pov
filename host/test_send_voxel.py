"""Pre-voxelize host-side and send sparse voxel cells (~3× wire speedup
for dense models compared to point cloud).

Wire format: PPCL header (flags=0x0002 SPARSE_VOXEL) + (idx24+rgb16)*N.
Board parses, writes directly to voxel_grid + occupied_list, bypassing
device-side voxelize_model.

Usage:
    python test_send_voxel.py [z_stretch=1.5] [n_pts=100000]
"""
import os, sys, time, numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import serial
from glb_to_points import sample_glb
from pointcloud_proto import pack_voxel_frame

# Board config (must match helloworld.c VOXEL_RES + WORLD_HALF)
VRES = 256
WORLD_HALF = 128

def host_voxelize(points):
    """Quantize points → set of (idx24, rgb565). idx = vz*256² + vy*256 + vx."""
    if not points:
        return []
    arr = np.array(points, dtype=np.int32)
    xs, ys, zs = arr[:, 0], arr[:, 1], arr[:, 2]
    rs, gs, bs = arr[:, 3], arr[:, 4], arr[:, 5]
    # Map model coord [-WORLD_HALF, WORLD_HALF) → voxel index [0, VRES)
    vx = xs + WORLD_HALF
    vy = ys + WORLD_HALF
    vz = zs + WORLD_HALF
    in_range = (vx >= 0) & (vx < VRES) & (vy >= 0) & (vy < VRES) & (vz >= 0) & (vz < VRES)
    vx, vy, vz = vx[in_range], vy[in_range], vz[in_range]
    rs, gs, bs = rs[in_range], gs[in_range], bs[in_range]
    # Pack RGB565
    r5 = (rs.astype(np.uint16) >> 3) & 0x1F
    g6 = (gs.astype(np.uint16) >> 2) & 0x3F
    b5 = (bs.astype(np.uint16) >> 3) & 0x1F
    rgb565 = (r5 << 11) | (g6 << 5) | b5
    # Linear voxel index
    idx = (vz.astype(np.uint32) * VRES + vy.astype(np.uint32)) * VRES + vx.astype(np.uint32)
    # Dedup: last-write-wins by sorting + taking last duplicate's color.
    # Simplest: dict idx→rgb (last wins implicitly if iterate in order).
    cells = {}
    for i in range(len(idx)):
        cells[int(idx[i])] = int(rgb565[i])
    return list(cells.items())


def main():
    zs = float(sys.argv[1]) if len(sys.argv) > 1 else 1.5
    n = int(sys.argv[2])   if len(sys.argv) > 2 else 100000
    glb = os.path.join(HERE, "anime_34.glb")
    port, baud = "COM10", 921600

    print(f"sampling {n} pts from {os.path.basename(glb)} (z_stretch={zs})...")
    np.random.seed(42)
    pts = sample_glb(glb, n_points=n, target_scale=40,
                     color_mode="keep", brighten=1.0, gamma=1.0,
                     lighting="studio", ambient=0.3,
                     z_stretch=zs, verbose=False)
    print(f"  sampled {len(pts)} points")

    print("host-side voxelizing...")
    t0 = time.time()
    cells = host_voxelize(pts)
    print(f"  → {len(cells)} unique voxel cells ({100*len(cells)/n:.1f}% of pts)  "
          f"in {time.time()-t0:.2f}s")

    print("packing sparse voxel frame...")
    buf = pack_voxel_frame(0, cells)
    print(f"  wire size: {len(buf)} bytes (vs point-cloud {16 + 5*n} = "
          f"{(1 - len(buf)/(16+5*n))*100:.0f}% saved)")

    print(f"opening {port}@{baud}...")
    ser = serial.Serial(port, baud, timeout=0)
    t0 = time.time()
    written = 0
    CHUNK = 32768
    while written < len(buf):
        end = min(written + CHUNK, len(buf))
        written += ser.write(buf[written:end])
        ser.read(8192)  # drain
    ser.flush()
    dt = time.time() - t0
    print(f"  send done in {dt:.2f}s  (effective {len(buf)/dt/1024:.1f} KB/s)")

    # Drain board ack
    print("waiting board ack (8s)...")
    deadline = time.time() + 8.0
    acc = b""
    while time.time() < deadline:
        chunk = ser.read(8192)
        if chunk: acc += chunk
        else: time.sleep(0.05)
    text = acc.decode("ascii", errors="replace")
    for line in text.split("\n"):
        line = line.strip()
        if not line: continue
        low = line.lower()
        if low.startswith(("slot ", "frame=", "vdma ")) or "park" in low:
            continue
        clean = "".join(ch if 32 <= ord(ch) < 127 else "?" for ch in line)
        print(f"  [board] {clean}")
    ser.close()
    print("done.")


if __name__ == "__main__":
    main()
