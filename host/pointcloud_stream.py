"""Stream a rotating + morphing cube point cloud to the Zynq board.

Each frame:
 - Generate ~200 points forming a wire-cube whose size oscillates over time.
 - Color hue cycles through 0..359 degrees so you can visually see stream alive.
 - Pack into our minimal POV3D point-cloud protocol and write to COM7 @ baud.

The board ARM reads these frames and hands the model to the pov_project HLS IP.
"""
import serial
import struct
import time
import math
import argparse
from pointcloud_proto import pack_frame

def hsv_to_rgb(h, s, v):
    """h in [0,360), s,v in [0,1]. Returns (r,g,b) ints 0..255."""
    c = v * s
    x = c * (1 - abs(((h / 60.0) % 2) - 1))
    m = v - c
    if   h < 60:   r, g, b = c, x, 0
    elif h < 120:  r, g, b = x, c, 0
    elif h < 180:  r, g, b = 0, c, x
    elif h < 240:  r, g, b = 0, x, c
    elif h < 300:  r, g, b = x, 0, c
    else:          r, g, b = c, 0, x
    return (int((r + m) * 255), int((g + m) * 255), int((b + m) * 255))

def add_line(pts, x0, y0, z0, x1, y1, z1, n, color):
    r, g, b = color
    for i in range(n + 1):
        t = i / n
        x = int(x0 + (x1 - x0) * t)
        y = int(y0 + (y1 - y0) * t)
        z = int(z0 + (z1 - z0) * t)
        pts.append((x, y, z, r, g, b))

def build_cube_frame(t):
    """Return a list of (x,y,z,r,g,b) points for time t seconds."""
    pts = []
    # size oscillates 20..40
    S = int(30 + 10 * math.sin(t * 2.0))
    # hue rotates once per 5s
    hue = (t * 72.0) % 360.0

    # Axes
    red = hsv_to_rgb(0, 1, 1)
    green = hsv_to_rgb(120, 1, 1)
    blue = hsv_to_rgb(240, 1, 1)
    add_line(pts, -50, 0, 0,  50, 0, 0, 40, red)
    add_line(pts,   0,-50, 0,   0,50, 0, 40, green)
    add_line(pts,   0, 0,-50,   0, 0,50, 40, blue)

    # Cube wire at size S, color cycles hue
    cube_color = hsv_to_rgb(hue, 1, 1)
    add_line(pts, -S,-S,-S,  S,-S,-S, 12, cube_color)
    add_line(pts,  S,-S,-S,  S,-S, S, 12, cube_color)
    add_line(pts,  S,-S, S, -S,-S, S, 12, cube_color)
    add_line(pts, -S,-S, S, -S,-S,-S, 12, cube_color)
    add_line(pts, -S, S,-S,  S, S,-S, 12, cube_color)
    add_line(pts,  S, S,-S,  S, S, S, 12, cube_color)
    add_line(pts,  S, S, S, -S, S, S, 12, cube_color)
    add_line(pts, -S, S, S, -S, S,-S, 12, cube_color)
    cube_color2 = hsv_to_rgb((hue + 180) % 360, 1, 1)
    add_line(pts, -S,-S,-S, -S, S,-S, 12, cube_color2)
    add_line(pts,  S,-S,-S,  S, S,-S, 12, cube_color2)
    add_line(pts,  S,-S, S,  S, S, S, 12, cube_color2)
    add_line(pts, -S,-S, S, -S, S, S, 12, cube_color2)
    return pts

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default="COM7")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--fps", type=float, default=5.0,
                    help="Frames per second to send (UART 115200 caps ~2 with 300 points)")
    ap.add_argument("--count", type=int, default=0,
                    help="How many frames to send (0 = infinite until Ctrl-C)")
    args = ap.parse_args()

    ser = serial.Serial(args.port, args.baud, timeout=0)
    print(f"[stream] opened {args.port}@{args.baud}")
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
            pts = build_cube_frame(t)
            buf = pack_frame(fid, pts)
            ser.write(buf)
            print(f"[stream] frame {fid}  {len(pts)} points  {len(buf)} bytes")
            fid += 1
            drain_rx()
            if args.count and fid >= args.count:
                break
            t_sleep = period - ((time.time() - t0) - fid * period)
            if t_sleep > 0:
                end = time.time() + t_sleep
                while time.time() < end:
                    drain_rx()
                    time.sleep(0.02)
    except KeyboardInterrupt:
        print("[stream] stopped")
    drain_rx()
    ser.close()

if __name__ == "__main__":
    main()
