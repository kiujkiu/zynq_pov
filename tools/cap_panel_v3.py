"""List icspring formats then try first one."""
import imageio_ffmpeg, subprocess
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()

# query device formats
r = subprocess.run([
    ffmpeg, "-hide_banner",
    "-f", "dshow",
    "-list_options", "true",
    "-i", "video=icspring camera",
], capture_output=True, text=True, timeout=15, encoding="utf-8", errors="ignore")
print("== device options ==")
print(r.stderr[-2000:])
