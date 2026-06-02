"""Capture icspring with locked low exposure via ffmpeg."""
import imageio_ffmpeg, subprocess, sys
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
out = r"D:\claude_workspace\pov3d\zynq_pov\panel_cap.jpg"

# ffmpeg dshow no direct exposure control. Try cv2 DSHOW with explicit settings.
import cv2, time
cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)
# icspring is dshow idx 0 (first DirectShow video device by enum order)
if not cap.isOpened():
    print("FAIL open"); sys.exit(1)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
# manual exposure: 0.25 = manual, value in 2^x seconds (-7 = 1/128s, -10 = 1/1024s)
cap.set(cv2.CAP_PROP_AUTO_EXPOSURE, 0.25)
exp = float(sys.argv[1]) if len(sys.argv) > 1 else -8.0
cap.set(cv2.CAP_PROP_EXPOSURE, exp)
# settle
for _ in range(20):
    cap.read(); time.sleep(0.05)
ok, frame = cap.read()
if ok and frame is not None:
    cv2.imwrite(out, frame)
    h, w = frame.shape[:2]
    print(f"OK {w}x{h} exp={exp} mean={frame.mean():.1f} max={frame.max()} -> {out}")
else:
    print("FAIL read")
cap.release()
