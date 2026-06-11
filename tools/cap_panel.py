"""Capture one frame from icspring camera, return mean brightness + path."""
import imageio_ffmpeg, subprocess, sys, os
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
out_path = r"D:\claude_workspace\pov3d\zynq_pov\panel_cap.jpg"
r = subprocess.run([
    ffmpeg, "-hide_banner", "-y",
    "-f", "dshow",
    "-i", "video=icspring camera",
    "-frames:v", "1",
    "-q:v", "2",
    out_path,
], capture_output=True, text=True, timeout=15, encoding="utf-8", errors="ignore")
if r.returncode != 0:
    print("CAP_FAIL:", r.stderr[-400:])
    sys.exit(1)
# brightness via Pillow
try:
    from PIL import Image
    im = Image.open(out_path).convert('L')
    pixels = list(im.getdata())
    mean = sum(pixels) / len(pixels)
    mn = min(pixels); mx = max(pixels)
    print(f"OK {out_path}  brightness mean={mean:.1f} min={mn} max={mx}")
except Exception as e:
    print(f"PIL fail: {e}; cap OK at {out_path}")
