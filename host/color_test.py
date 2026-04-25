"""Send 3 solid-color test point clouds: all red, all green, all blue.
Watch HDMI to see what colors actually appear. Diagnoses R/G/B channel mapping.
"""
import serial
import time
import sys
from pointcloud_proto import pack_frame

PORT = "COM7"
BAUD = 115200

def solid_color_cloud(r, g, b, n=300):
    """Generate n random points inside ±40, all with given color."""
    import random
    pts = []
    for _ in range(n):
        x = random.randint(-40, 40)
        y = random.randint(-40, 40)
        z = random.randint(-40, 40)
        pts.append((x, y, z, r, g, b))
    return pts


def main():
    ser = serial.Serial(PORT, BAUD, timeout=0.1)
    print(f"opened {PORT}@{BAUD}")

    for name, rgb in [("RED", (255, 0, 0)),
                      ("GREEN", (0, 255, 0)),
                      ("BLUE", (0, 0, 255)),
                      ("WHITE", (255, 255, 255))]:
        r, g, b = rgb
        print(f"sending {name} r={r} g={g} b={b}")
        pts = solid_color_cloud(r, g, b, 300)
        buf = pack_frame(0, pts, compressed=False)
        ser.write(buf)
        ser.flush()
        # wait so host can visually note screen color
        for _ in range(30):
            data = ser.read(512)
            if data:
                print("[board] " + data.decode('ascii', errors='replace'), end="")
            time.sleep(0.1)
    ser.close()
    print("\ndone")


if __name__ == "__main__":
    main()
