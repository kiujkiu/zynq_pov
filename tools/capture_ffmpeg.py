"""Capture HDMI via dshow using imageio's bundled ffmpeg.
Lists devices then captures one frame from C1-1 USB3 Video."""
import imageio.v2 as imageio
import imageio_ffmpeg
import subprocess
import sys
import os

ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
print(f"using ffmpeg: {ffmpeg}")

# 1) list dshow devices
print("\n=== dshow devices ===")
try:
    out = subprocess.run(
        [ffmpeg, "-hide_banner", "-f", "dshow", "-list_devices", "true", "-i", "dummy"],
        capture_output=True, text=True, timeout=10, encoding="utf-8", errors="ignore"
    )
    print(out.stderr)
except Exception as e:
    print(f"err: {e}")

# 2) capture one frame from C1-1 USB3 Video
out_path = r"D:\workspace\zynq_pov\hdmi_ff.jpg"
print(f"\n=== capture to {out_path} ===")
result = subprocess.run([
    ffmpeg, "-hide_banner", "-y",
    "-f", "dshow",
    "-video_size", "1280x720",
    "-framerate", "60",
    "-i", "video=C1-1 USB3 Video",
    "-ss", "2",        # skip first 2 seconds (warmup)
    "-frames:v", "1",
    "-update", "1",
    out_path
], capture_output=True, text=True, timeout=15, encoding="utf-8", errors="ignore")
print(result.stderr[-1500:])
print(f"exit={result.returncode}")
print(f"file size: {os.path.getsize(out_path) if os.path.exists(out_path) else 'missing'}")
