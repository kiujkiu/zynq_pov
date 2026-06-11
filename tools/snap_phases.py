"""Capture 6s yuyv422 clip from icspring (covers ~12 probe phase cycles),
then extract 12 frames at 0.5s spacing."""
import imageio_ffmpeg, subprocess, os
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
out_dir = r"D:\workspace\zynq_pov\tools"
clip = os.path.join(out_dir, "probe_clip.mkv")
# yuyv422 / 30fps native format of icspring
r = subprocess.run([
    ffmpeg, "-hide_banner", "-y",
    "-f", "dshow",
    "-pixel_format", "yuyv422",
    "-video_size", "640x480",
    "-framerate", "30",
    "-i", "video=icspring camera",
    "-t", "6",
    "-c:v", "mjpeg", "-q:v", "3",
    clip,
], capture_output=True, text=True, timeout=20, encoding="utf-8", errors="ignore")
if r.returncode != 0:
    print("CLIP_FAIL:", r.stderr[-400:])
    raise SystemExit(1)
sz = os.path.getsize(clip)
print(f"clip OK: {clip} ({sz} bytes)")
for i in range(12):
    t = 0.3 + i * 0.5
    out_jpg = os.path.join(out_dir, f"probe_{i+1}.jpg")
    r = subprocess.run([
        ffmpeg, "-hide_banner", "-y",
        "-ss", str(t), "-i", clip,
        "-frames:v", "1", "-q:v", "2",
        out_jpg,
    ], capture_output=True, text=True, timeout=10, encoding="utf-8", errors="ignore")
    if r.returncode != 0:
        print(f"[{i+1}] EXTRACT_FAIL t={t}: {r.stderr[-200:]}")
        continue
    try:
        from PIL import Image
        im = Image.open(out_jpg).convert('L')
        pixels = list(im.getdata())
        mean = sum(pixels) / len(pixels)
        print(f"[{i+1}] t={t:.1f}s mean={mean:.1f}")
    except Exception as e:
        print(f"[{i+1}] PIL fail: {e}")
