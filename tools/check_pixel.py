"""Sample pixels from hdmi_obs.jpg LEFT margin to verify bg color."""
from PIL import Image
img = Image.open(r"D:\workspace\zynq_pov\hdmi_obs.jpg")
print(f"size = {img.size}, mode = {img.mode}")
# LEFT panel is 0..960 (16:9 jpg of 1280-px panel scaled to 1920).
# Let's sample (50, 100) which should be far from any voxel - LEFT bg margin.
for (x, y) in [(50, 50), (50, 360), (200, 600), (900, 360)]:
    px = img.getpixel((x, y))
    print(f"  ({x}, {y}) -> RGB {px}")
