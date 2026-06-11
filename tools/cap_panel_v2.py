"""Try to capture panel via icspring with explicit pixel_format hint."""
import imageio_ffmpeg, subprocess, os, sys
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
out_path = r"D:\workspace\zynq_pov\tools\probe_diag.jpg"

# Try mjpeg pixel format which icspring usually supports
cmd = [
    ffmpeg, "-hide_banner", "-y",
    "-f", "dshow",
    "-vcodec", "mjpeg",
    "-i", "video=icspring camera",
    "-frames:v", "1",
    "-q:v", "2",
    out_path,
]
r = subprocess.run(cmd, capture_output=True, text=True, timeout=15, encoding="utf-8", errors="ignore")
print("RC:", r.rc if hasattr(r,'rc') else r.returncode)
print("STDERR:", r.stderr[-800:])
