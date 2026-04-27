"""Capture latest frame from OBS Virtual Camera.

OBS Virtual Camera passes through old buffered frames at the start of a
ffmpeg session — `-ss 1` was not enough to skip them. Strategy:
read N=60 frames and overwrite the same file each time (`-update 1`).
The N-th write = freshest frame on disk."""
import imageio_ffmpeg
import subprocess
import os
import sys

ff = imageio_ffmpeg.get_ffmpeg_exe()
out = r"D:\workspace\zynq_pov\hdmi_obs.jpg"
device = "OBS Virtual Camera"

cmd = [
    ff, "-hide_banner", "-y",
    "-fflags", "nobuffer",
    "-flags", "low_delay",
    "-rtbufsize", "32M",
    "-f", "dshow",
    "-video_size", "1280x720",
    "-framerate", "30",
    "-i", f"video={device}",
    "-frames:v", "60",     # ~2 sec stream — drains stale buffered frames
    "-update", "1",         # overwrite same file each frame
    out,
]
print(f"running: {' '.join(cmd)}")
r = subprocess.run(cmd, capture_output=True, text=True, timeout=20,
                   encoding="utf-8", errors="ignore")
print(r.stderr[-1500:])
print(f"exit={r.returncode}")
print(f"size={os.path.getsize(out) if os.path.exists(out) else 'missing'}")
