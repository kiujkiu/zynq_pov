"""Capture 60 frames into single file (last write wins = freshest)."""
import imageio_ffmpeg
import subprocess
import os

ff = imageio_ffmpeg.get_ffmpeg_exe()
out = r"D:\workspace\zynq_pov\hdmi_ff.jpg"
r = subprocess.run([
    ff, "-hide_banner", "-y",
    "-fflags", "nobuffer",
    "-flags", "low_delay",
    "-f", "dshow",
    "-video_size", "1280x720",
    "-framerate", "60",
    "-i", "video=C1-1 USB3 Video",
    "-frames:v", "60",
    "-update", "1",
    out,
], capture_output=True, text=True, timeout=20, encoding="utf-8", errors="ignore")
print(r.stderr[-800:])
print(f"exit={r.returncode}, size={os.path.getsize(out) if os.path.exists(out) else 'missing'}")
