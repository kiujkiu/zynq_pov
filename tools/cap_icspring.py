"""Capture one frame from 'icspring camera' via dshow."""
import imageio_ffmpeg, subprocess, sys
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()

# list devices to confirm name
print("=== devices ===")
out = subprocess.run(
    [ffmpeg, "-hide_banner", "-f", "dshow", "-list_devices", "true", "-i", "dummy"],
    capture_output=True, text=True, timeout=10, encoding="utf-8", errors="ignore"
)
print(out.stderr[:2000])

# try common names: "icspring camera", "icspring Camera", "ICspring camera"
for name in ["icspring camera", "icspring Camera", "ICspring camera", "ICspring Camera"]:
    out_path = rf"D:\claude_workspace\pov3d\zynq_pov\panel_cap_{name.replace(' ','_')}.jpg"
    print(f"\n=== try capture {name} -> {out_path} ===")
    r = subprocess.run([
        ffmpeg, "-hide_banner", "-y",
        "-f", "dshow",
        "-i", f"video={name}",
        "-frames:v", "1",
        "-q:v", "2",
        out_path,
    ], capture_output=True, text=True, timeout=15, encoding="utf-8", errors="ignore")
    print(r.stderr[-800:])
    if r.returncode == 0:
        print(f"SUCCESS -> {out_path}")
        break
