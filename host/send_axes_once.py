"""Send ONE frame containing only the 3 axes (123 points). Static. Slow."""
import serial, time
from pointcloud_proto import pack_frame

def add_line(pts, x0,y0,z0, x1,y1,z1, n, r,g,b):
    for i in range(n + 1):
        t = i / n
        pts.append((int(x0 + (x1-x0)*t), int(y0 + (y1-y0)*t), int(z0 + (z1-z0)*t), r, g, b))

pts = []
add_line(pts, -50,0,0, 50,0,0, 40, 255, 0, 0)    # X = red
add_line(pts,  0,-50,0, 0,50,0, 40, 0, 255, 0)   # Y = green
add_line(pts,  0,0,-50, 0,0,50, 40, 0, 0, 255)   # Z = blue

buf = pack_frame(0, pts)
print(f"axes-only frame: {len(pts)} points, {len(buf)} bytes")

ser = serial.Serial("COM7", 115200, timeout=0.1)
ser.write(buf)
ser.flush()
time.sleep(0.5)  # let board drain + render a couple times
# read any board response
data = ser.read(2048)
if data:
    print("[board] " + data.decode('ascii', errors='replace'))
ser.close()
