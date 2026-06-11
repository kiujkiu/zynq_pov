"""Send anime + monitor ESP32 logs in parallel."""
import os, sys, time, socket, threading, serial
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
print(f"voxels: {len(pts)}, packing...", flush=True)
buf = pack_frame(0, pts, compressed=True)
print(f"pack: {len(buf)} bytes", flush=True)

stop = [False]
def watch_log():
    s = serial.Serial("COM6", 115200, timeout=0.3)
    while not stop[0]:
        d = s.read(2048)
        if d:
            try:
                txt = d.decode('ascii', errors='replace')
                for ln in txt.split('\n'):
                    if 'pov_bridge' in ln or 'DFLT' in ln or 'client' in ln.lower():
                        print(f"  [LOG] {ln.strip()}", flush=True)
            except: pass
    s.close()

threading.Thread(target=watch_log, daemon=True).start()
time.sleep(1)

# Try send up to 5 times for full send to complete (without conn reset)
for attempt in range(15):
    print(f"\n>> Attempt {attempt}...", flush=True)
    try:
        s = socket.create_connection((HOST, PORT), timeout=3)
        s.settimeout(10)
        t0 = time.time()
        s.sendall(buf)
        dt = time.time() - t0
        print(f"  sendall returned in {dt:.2f}s ({len(buf)*8/max(dt,0.001)/1e6:.1f} Mbps)", flush=True)
        # Stay connected for a bit so ESP32 can drain into SDIO
        time.sleep(3)
        s.close()
        print("  closed", flush=True)
        time.sleep(2)
        break
    except Exception as e:
        print(f"  fail: {e}", flush=True)
        time.sleep(1)

time.sleep(2)
stop[0] = True
time.sleep(0.3)
