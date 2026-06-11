"""PC-side server: listens on :9999, when ESP32 dials in, sends anime DFLT frame."""
import os, sys, time, socket
sys.path.insert(0, r"D:\workspace\zynq_pov\host")
from glb_to_points import voxelize_mesh
from pointcloud_proto import pack_frame

LISTEN_PORT = 9999
GLB_PATH = r"D:\workspace\zynq_pov\host\anime_62459_baked_warm.glb"

print("voxelizing...", flush=True)
pts = voxelize_mesh(GLB_PATH, target_scale=40, z_stretch=1.5, voxel_size=1.0, verbose=False,
                    brighten=1.4, gamma=0.95, saturation=1.4, lighting="none", ambient=1.0)
buf = pack_frame(0, pts, compressed=True)
print(f"frame ready: {len(buf)} bytes ({len(pts)} voxels)", flush=True)

srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("0.0.0.0", LISTEN_PORT))
srv.listen(4)
print(f"PC server listening on :{LISTEN_PORT}, waiting for ESP32 dial-in...", flush=True)

while True:
    try:
        conn, addr = srv.accept()
        print(f"ESP32 dialed in from {addr}", flush=True)
        conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        t0 = time.time()
        conn.sendall(buf)
        dt = time.time() - t0
        print(f"  sent {len(buf)} bytes in {dt:.2f}s ({len(buf)*8/max(dt,0.001)/1e6:.1f} Mbps)", flush=True)
        # Keep connection open briefly so ESP32 can drain
        time.sleep(2)
        conn.close()
        print("  closed", flush=True)
    except KeyboardInterrupt:
        break
    except Exception as e:
        print(f"  err: {e}", flush=True)
