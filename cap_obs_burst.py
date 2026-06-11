"""Capture from OBS Virtual Camera, last-write-wins to skip stale frames."""
import imageio_ffmpeg, subprocess, os
ff = imageio_ffmpeg.get_ffmpeg_exe()
out = r"D:\workspace\zynq_pov\hdmi_obs.jpg"
r = subprocess.run([
    ff, "-hide_banner", "-y",
    "-fflags", "nobuffer",
    "-flags", "low_delay",
    "-rtbufsize", "32M",
    "-f", "dshow",
    "-video_size", "1280x720",
    "-framerate", "30",
    "-i", "video=OBS Virtual Camera",
    "-frames:v", "90",
    "-update", "1",
    out,
], capture_output=True, text=True, timeout=20, encoding="utf-8", errors="ignore")
print(r.stderr[-600:])
print(f"exit={r.returncode}, size={os.path.getsize(out) if os.path.exists(out) else 'missing'}")
