"""Capture panel via cv2 DSHOW idx=1 (icspring external cam)."""
import cv2, time, os
out = r"D:\claude_workspace\pov3d\zynq_pov\cap_panel.jpg"
cap = cv2.VideoCapture(1, cv2.CAP_DSHOW)
if not cap.isOpened():
    print("FAIL: cannot open DSHOW idx 1")
    raise SystemExit(1)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
# warm-up + auto-exposure settle
for _ in range(20):
    cap.read(); time.sleep(0.05)
ok, frame = cap.read()
if ok and frame is not None:
    cv2.imwrite(out, frame)
    h, w = frame.shape[:2]
    print(f"OK {w}x{h} mean={frame.mean():.1f} max={frame.max()} -> {out}")
else:
    print("FAIL: read")
cap.release()
