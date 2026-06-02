"""List all DirectShow video devices."""
import imageio_ffmpeg, subprocess
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
r = subprocess.run([
    ffmpeg, "-hide_banner",
    "-f", "dshow",
    "-list_devices", "true",
    "-i", "dummy",
], capture_output=True, text=True, timeout=15, encoding="utf-8", errors="ignore")
print(r.stderr)
