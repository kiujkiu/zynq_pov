"""Generate a 1280×720×3 test pattern: top half red, bot half blue."""
import struct
out = r"D:\claude_workspace\pov3d\zynq_pov\tools\fb_red.bin"
buf = bytearray()
# HDMI fb byte order per memory: G B R (3 bytes per pixel)
# Top half: red (G=0 B=0 R=255)
for y in range(360):
    for x in range(1280):
        buf += bytes([0, 0, 255])
# Bot half: blue (G=0 B=255 R=0)
for y in range(360):
    for x in range(1280):
        buf += bytes([0, 255, 0])
with open(out, "wb") as f:
    f.write(buf)
print(f"wrote {len(buf)} bytes to {out}")
