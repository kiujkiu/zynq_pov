"""Capture from OBS Virtual Camera without forcing size/framerate."""
import imageio_ffmpeg, subprocess, os
ff = imageio_ffmpeg.get_ffmpeg_exe()
out = r"D:\workspace\zynq_pov\hdmi_obs.jpg"

# First list device options
print("=== device options ===")
r1 = subprocess.run([
    ff, "-hide_banner", "-f", "dshow",
    "-list_options", "true",
    "-i", "video=OBS Virtual Camera",
], capture_output=True, text=True, timeout=10, encoding="utf-8", errors="ignore")
print(r1.stderr[-1500:])

# Then capture
print("\n=== capture ===")
r = subprocess.run([
    ff, "-hide_banner", "-y",
    "-fflags", "nobuffer",
    "-flags", "low_delay",
    "-rtbufsize", "32M",
    "-f", "dshow",
    "-i", "video=OBS Virtual Camera",
    "-frames:v", "90",
    "-update", "1",
    out,
], capture_output=True, text=True, timeout=20, encoding="utf-8", errors="ignore")
print(r.stderr[-800:])
print(f"exit={r.returncode}, size={os.path.getsize(out) if os.path.exists(out) else 'missing'}")
