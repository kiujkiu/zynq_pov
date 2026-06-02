"""Capture icspring via ffmpeg dshow with explicit short exposure."""
import imageio_ffmpeg, subprocess, sys
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
out = r"D:\claude_workspace\pov3d\zynq_pov\panel_cap.jpg"
# discard first 30 frames to let auto-exposure converge on dark scene
cmd = [
    ffmpeg, "-hide_banner", "-y",
    "-f", "dshow",
    "-rtbufsize", "100M",
    "-i", "video=icspring camera",
    "-vf", "select=gte(n\\,30)",
    "-vframes", "1",
    "-q:v", "2",
    out,
]
r = subprocess.run(cmd, capture_output=True, text=True, timeout=20, encoding="utf-8", errors="ignore")
if r.returncode != 0:
    print("FAIL:", r.stderr[-400:])
    sys.exit(1)
from PIL import Image
im = Image.open(out)
g = im.convert('L')
data = list(g.getdata())
print(f"OK {im.size} mean={sum(data)/len(data):.1f} min={min(data)} max={max(data)} -> {out}")
