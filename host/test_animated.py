"""Verify animated stream path: send N frames at given FPS, check board stays alive.

Mimics GUI's "Start animated stream" — uses build_animator() to get
per-frame point lists with rotation, then sends sequentially.
"""
import os, sys, time, math
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import serial
from anim_loader import build_animator
from pointcloud_proto import pack_frame

GLB = os.path.join(HERE, "anime_62459.glb")
PORT, BAUD = "COM10", 921600
N_FRAMES = 10
FPS = 0.5      # 1 frame per 2 sec — gives wire time at 30K pts

print(f"building animator from {os.path.basename(GLB)} (10K pts for fast wire)...")
animator = build_animator(GLB, n_points=10000, target_scale=40,
                          color_mode="keep", brighten=1.0, gamma=1.0,
                          lighting="studio", ambient=0.3,
                          z_stretch=1.5,
                          fallback_period_y=10.0)

print(f"opening {PORT}@{BAUD}...")
ser = serial.Serial(PORT, BAUD, timeout=0)

print(f"sending {N_FRAMES} frames @ {FPS} FPS...")
period = 1.0 / FPS
ack_count = 0
t_start = time.time()

for fid in range(1, N_FRAMES + 1):
    t_frame = t_start + (fid - 1) * period
    # wait until t_frame
    while time.time() < t_frame:
        # drain RX so OS buffer doesn't choke
        ser.read(4096)
        time.sleep(0.02)

    pts = animator(fid * 0.5)   # different t each frame for animation
    buf = pack_frame(fid, pts, compressed=True)
    t0 = time.time()
    ser.write(buf)
    ser.flush()
    write_dt = time.time() - t0

    # read board echo briefly
    chunk = ser.read(8192)
    if b"stream_frame=" in chunk or b"[rx-dump]" in chunk or b"[rx]" in chunk:
        ack_count += 1

    print(f"  frame {fid:2d}: {len(pts)} pts, write={write_dt:.2f}s, ack={'Y' if ack_count else '?'}")

# Final drain
deadline = time.time() + 3
while time.time() < deadline:
    ser.read(8192)
    time.sleep(0.05)

# Verify board still alive
print("\nverifying board alive after stream...")
ser.read(8192)  # clear
time.sleep(2)   # wait for telemetry
data = b""
deadline = time.time() + 5
while time.time() < deadline:
    chunk = ser.read(8192)
    if chunk: data += chunk
    else: time.sleep(0.05)

ser.close()
text = data.decode("ascii", errors="replace")
fps_lines = [ln for ln in text.split("\n") if "FPS" in ln]
if fps_lines:
    print(f"  OK board alive, last telemetry: {fps_lines[-1].strip()[:80]}")
else:
    print(f"  FAIL no FPS telemetry in last 5s -- board may have crashed")
    print(f"    last 200 bytes: {data[-200:]}")
