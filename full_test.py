"""Send anime + watch ESP32 logs + check Zynq model_n."""
import os, sys, time, socket, threading, serial, subprocess
sys.path.insert(0, r"D:\workspace\zynq_pov\host")
from glb_to_points import voxelize_mesh
from pointcloud_proto import pack_frame

HOST = "10.168.168.103"
PORT = 8888

print("voxelizing...", flush=True)
pts = voxelize_mesh(r"D:\workspace\zynq_pov\host\anime_62459_baked_warm.glb",
                    target_scale=40, z_stretch=1.5, voxel_size=1.0, verbose=False,
                    brighten=1.4, gamma=0.95, saturation=1.4,
                    lighting="none", ambient=1.0)
buf = pack_frame(0, pts, compressed=True)
print(f"pack: {len(buf)} bytes ({len(pts)} voxels)", flush=True)

stop = [False]
log_collected = []
def watch_log():
    s = serial.Serial("COM6", 115200, timeout=0.2)
    while not stop[0]:
        d = s.read(2048)
        if d:
            try:
                txt = d.decode('ascii', errors='replace')
                log_collected.append(txt)
                for ln in txt.split('\n'):
                    ln = ln.strip()
                    if any(k in ln for k in ['client', 'DFLT', 'SDIO RX', 'SDIO TX', 'sdio_tx',
                                              'pov_bridge', 'sent total', 'inflate', 'total']):
                        print(f"  [ESP] {ln}", flush=True)
            except: pass
    s.close()

threading.Thread(target=watch_log, daemon=True).start()
time.sleep(1)

# Try ~30 attempts; each successful send hold connection 5s
success_attempts = 0
for attempt in range(40):
    elapsed = time.time()
    try:
        s = socket.create_connection((HOST, PORT), timeout=2)
        s.settimeout(15)
        s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        # Don't fast-blast — slow drip to match ESP32 SDIO throughput
        sent = 0
        chunk_sz = 4096
        t0 = time.time()
        while sent < len(buf):
            chunk = buf[sent:sent + chunk_sz]
            s.sendall(chunk)
            sent += len(chunk)
        dt = time.time() - t0
        print(f"\n>> Attempt {attempt}: sent {sent} in {dt:.2f}s ({sent*8/max(dt,0.001)/1e6:.1f} Mbps)", flush=True)
        # Stay connected for SDIO drain
        time.sleep(4)
        s.close()
        success_attempts += 1
        if success_attempts >= 1:
            break
    except Exception as e:
        if attempt % 5 == 0:
            print(f">> Attempt {attempt}: {e}", flush=True)
    time.sleep(0.5)

time.sleep(3)
stop[0] = True
time.sleep(0.5)
print(f"\n=== Sent {success_attempts} time(s) ===")
