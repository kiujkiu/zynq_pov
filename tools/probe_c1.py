"""Probe C1-1 USB3 Video formats."""
import imageio_ffmpeg, subprocess
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
r = subprocess.run([ffmpeg, "-hide_banner", "-f", "dshow", "-list_options", "true",
                    "-i", "video=C1-1 USB3 Video"],
                   capture_output=True, text=True, timeout=15, encoding="utf-8", errors="ignore")
print(r.stderr[-3000:])
