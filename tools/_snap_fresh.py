"""Snap from Insta360 Link 2 Pro (MSMF idx=1, 1920x1080)."""
import cv2, time, os, sys
OUT_DIR = r'D:\claude_workspace\pov3d\zynq_pov\tools'
cap = cv2.VideoCapture(1, cv2.CAP_MSMF)
if not cap.isOpened():
    print("Insta360 not at MSMF idx=1; trying DSHOW idx=0");
    cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
for _ in range(20):
    cap.read(); time.sleep(0.04)
ret, frame = cap.read()
cap.release()
if ret and frame is not None:
    h, w = frame.shape[:2]; m = float(frame.mean())
    path = os.path.join(OUT_DIR, 'panel_low_exp.jpg')
    cv2.imwrite(path, frame)
    print(f"{w}x{h} mean={m:.1f} -> {path}")
else:
    print("read failed")
