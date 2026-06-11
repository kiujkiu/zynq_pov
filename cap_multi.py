"""Capture 3 frames spaced 2.5 sec apart."""
import imageio_ffmpeg, subprocess, os, time
ff = imageio_ffmpeg.get_ffmpeg_exe()
for i in range(3):
    out = rf"D:\workspace\zynq_pov\hdmi_seq_{i}.jpg"
    subprocess.run([
        ff, "-hide_banner", "-y",
        "-fflags", "nobuffer", "-flags", "low_delay",
        "-rtbufsize", "32M",
        "-f", "dshow", "-i", "video=OBS Virtual Camera",
        "-frames:v", "90", "-update", "1", out,
    ], capture_output=True, timeout=15)
    print(f"#{i}: {out} size={os.path.getsize(out) if os.path.exists(out) else 'miss'}", flush=True)
    if i < 2: time.sleep(2.5)
