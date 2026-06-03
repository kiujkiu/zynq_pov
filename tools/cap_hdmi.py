"""Capture HDMI via USB capture card (C1-1 USB3 Video)."""
import imageio_ffmpeg, subprocess
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
out = r"D:\claude_workspace\pov3d\zynq_pov\hdmi_capture.jpg"
cmd = [
    ffmpeg, "-hide_banner", "-y",
    "-f", "dshow",
    "-vcodec", "mjpeg",
    "-video_size", "1280x720",
    "-i", "video=C1-1 USB3 Video",
    "-frames:v", "1",
    "-q:v", "2",
    out,
]
r = subprocess.run(cmd, capture_output=True, text=True, timeout=15, encoding="utf-8", errors="ignore")
if r.returncode != 0:
    print("FAIL:", r.stderr[-400:])
else:
    from PIL import Image
    im = Image.open(out)
    g = im.convert('L')
    data = list(g.getdata())
    print(f"OK {im.size} mean={sum(data)/len(data):.1f} min={min(data)} max={max(data)} -> {out}")
