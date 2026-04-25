"""Stream anime figure point cloud animation to the board.

Sampling is re-done every frame so we can animate in Host:
- rotation around Y axis (phase advance)
- subtle bobbing (Y offset sine)
- idle-breathing effect (XZ scale sine)

Usage:
  python anime_stream.py                 # builtin figure
  python anime_stream.py path/to.obj     # your own mesh
  python anime_stream.py obj 300 4       # obj with 300 pts @ 4 FPS
"""
import serial
import math
import time
import sys
import argparse

from pointcloud_proto import pack_frame
from mesh_to_points import sample_mesh
from glb_to_points import sample_glb


def animate(pts, t, y_rotate_period=4.0, rotate=True):
    """Apply per-frame animation. If rotate=False skip Y rotation."""
    if rotate:
        ang = t * 2.0 * math.pi / y_rotate_period
        ca = math.cos(ang); sa = math.sin(ang)
    else:
        ca = 1.0; sa = 0.0
    scale = 1.0 + 0.05 * math.sin(t * 2.0 * math.pi / 3.0)
    y_offset = 3.0 * math.sin(t * 2.0 * math.pi / 2.0)

    out = []
    for (x, y, z, r, g, b) in pts:
        rx = x * ca - z * sa
        rz = x * sa + z * ca
        nx = int(rx * scale)
        ny = int(y + y_offset)
        nz = int(rz * scale)
        nx = max(-127, min(127, nx))
        ny = max(-127, min(127, ny))
        nz = max(-127, min(127, nz))
        out.append((nx, ny, nz, r, g, b))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mesh_path", nargs="?", default=None,
                    help="Path to .obj (omit for builtin figure)")
    ap.add_argument("--port", default="COM7")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--points", type=int, default=300,
                    help="Number of points to sample (more = slower stream)")
    ap.add_argument("--fps", type=float, default=3.0,
                    help="Target send rate. UART 115200 caps ~2 FPS at 300 pts.")
    ap.add_argument("--scale", type=int, default=40,
                    help="Target half-extent of model in int16 units")
    ap.add_argument("--count", type=int, default=0,
                    help="Frames to send (0=forever)")
    ap.add_argument("--color", default="height",
                    choices=["height", "uniform", "random", "keep"],
                    help="Color mode for glb sampling")
    ap.add_argument("--no-rotate", action="store_true",
                    help="Disable host-side Y rotation (board does phase rotation)")
    ap.add_argument("--brighten", type=float, default=2.0,
                    help="Color brightness multiplier (1.0=raw, 2.0=double, clipped to 255)")
    ap.add_argument("--compressed", action="store_true",
                    help="Use 5-byte/point compressed format (3.2x smaller)")
    ap.add_argument("--gamma", type=float, default=0.6,
                    help="Gamma correction (<1 brightens dark midtones)")
    args = ap.parse_args()

    print(f"[anime] sampling {args.points} points from {args.mesh_path or 'builtin'}")
    if args.mesh_path and args.mesh_path.lower().endswith((".glb", ".gltf")):
        base_pts = sample_glb(args.mesh_path, n_points=args.points,
                              target_scale=args.scale, color_mode=args.color,
                              brighten=args.brighten, gamma=args.gamma)
    else:
        base_pts = sample_mesh(args.mesh_path, n_points=args.points, target_scale=args.scale)
    if not base_pts:
        print("no points — aborting")
        return
    print(f"[anime] sampled {len(base_pts)} points")

    ser = serial.Serial(args.port, args.baud, timeout=0)
    print(f"[anime] opened {args.port}@{args.baud}")
    t0 = time.time()
    fid = 0
    period = 1.0 / args.fps
    rx_buf = b""

    def drain_rx():
        nonlocal rx_buf
        data = ser.read(4096)
        if data:
            rx_buf += data
            while b"\n" in rx_buf:
                line, rx_buf = rx_buf.split(b"\n", 1)
                try:
                    print("[board] " + line.decode("ascii", errors="replace").rstrip())
                except:
                    pass

    try:
        while True:
            t = time.time() - t0
            pts = animate(base_pts, t, rotate=not args.no_rotate)
            if fid == 0:
                p0 = pts[0]
                print(f"[DEBUG] first point: x={p0[0]} y={p0[1]} z={p0[2]} "
                      f"r={p0[3]} g={p0[4]} b={p0[5]}")
            buf = pack_frame(fid, pts, compressed=args.compressed)
            ser.write(buf)
            if fid % 5 == 0:
                print(f"[anime] frame {fid}  {len(pts)} pts  {len(buf)} B  t={t:.1f}s")
            fid += 1
            drain_rx()
            if args.count and fid >= args.count:
                break
            # pace
            target = fid * period
            sleep_for = target - (time.time() - t0)
            if sleep_for > 0:
                end = time.time() + sleep_for
                while time.time() < end:
                    drain_rx()
                    time.sleep(0.02)
    except KeyboardInterrupt:
        print("\n[anime] stopped")
    drain_rx()
    ser.close()


if __name__ == "__main__":
    main()
