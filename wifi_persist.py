"""Send anime frame to ESP32. Aggressive retry over ~90s to catch any stable window."""
import os, sys, time, socket
sys.path.insert(0, r"D:\workspace\zynq_pov\host")
from glb_to_points import voxelize_mesh
from pointcloud_proto import pack_frame

HOST = "10.168.168.103"
PORT = 8888

print("voxelizing anime GLB...", flush=True)
pts = voxelize_mesh(r"D:\workspace\zynq_pov\host\anime_62459_baked_warm.glb",
                    target_scale=40, z_stretch=1.5, voxel_size=1.0, verbose=False,
                    brighten=1.4, gamma=0.95, saturation=1.4,
                    lighting="none", ambient=1.0)
print(f"voxels: {len(pts)}", flush=True)
buf = pack_frame(0, pts, compressed=True)
print(f"pack: {len(buf)} bytes", flush=True)

t_start = time.time()
for attempt in range(120):
    elapsed = time.time() - t_start
    if elapsed > 90: break
    try:
        s = socket.create_connection((HOST, PORT), timeout=1)
        s.settimeout(8)
        t0 = time.time()
        s.sendall(buf)
        dt = time.time() - t0
        print(f"[{elapsed:.1f}s] #{attempt}: SUCCESS sent {len(buf)} bytes in {dt:.2f}s = {len(buf)*8/dt/1e6:.2f} Mbps", flush=True)
        s.close()
        break
    except Exception as e:
        if attempt % 10 == 0:
            print(f"[{elapsed:.1f}s] #{attempt}: {e}", flush=True)
    time.sleep(0.3)
else:
    print("All attempts exhausted")
