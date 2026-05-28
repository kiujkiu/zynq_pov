"""Grab 12 frames at 0.4s spacing from icspring (DSHOW idx1)."""
import cv2, os, time
out_dir = r"D:\workspace\zynq_pov\tools"

cap = cv2.VideoCapture(1, cv2.CAP_DSHOW)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
for _ in range(10): cap.read(); time.sleep(0.05)
for i in range(12):
    for _ in range(3): cap.grab()
    ok, frame = cap.retrieve()
    if ok:
        p = os.path.join(out_dir, f"probe_{i+1}.jpg")
        cv2.imwrite(p, frame)
        print(f"[{i+1}] mean={frame.mean():.1f} -> {p}")
    time.sleep(0.4)
cap.release()
