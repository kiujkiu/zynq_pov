"""Capture 5 frames spaced 1 sec apart to verify HDMI signal is changing."""
import imageio_ffmpeg, subprocess, os, time
ff = imageio_ffmpeg.get_ffmpeg_exe()
# Capture 5 frames to separate files
out_dir = r"D:\workspace\zynq_pov"
r = subprocess.run([
    ff, "-hide_banner", "-y",
    "-f", "dshow",
    "-video_size", "1280x720",
    "-framerate", "60",
    "-i", "video=C1-1 USB3 Video",
    "-vf", "fps=2",          # 2 fps = 0.5s between frames
    "-frames:v", "5",
    os.path.join(out_dir, "hdmi_seq_%02d.jpg")
], capture_output=True, text=True, timeout=20, encoding="utf-8", errors="ignore")
print(r.stderr[-500:])
for i in range(1, 6):
    p = os.path.join(out_dir, f"hdmi_seq_{i:02d}.jpg")
    print(f"  {p}: {os.path.getsize(p) if os.path.exists(p) else 'missing'}")
