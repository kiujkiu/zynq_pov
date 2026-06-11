"""Try OBS Virtual Camera as fallback if icspring is locked."""
import imageio_ffmpeg, subprocess
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
out = r"D:\workspace\zynq_pov\tools\probe_obs.jpg"
r = subprocess.run([
    ffmpeg, "-hide_banner", "-y",
    "-f", "dshow",
    "-i", "video=OBS Virtual Camera",
    "-frames:v", "1",
    "-q:v", "2",
    out,
], capture_output=True, text=True, timeout=15, encoding="utf-8", errors="ignore")
print("RC:", r.returncode)
print("STDERR:", r.stderr[-500:])
