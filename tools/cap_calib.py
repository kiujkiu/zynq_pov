"""Snap 50 frames at 0.5s spacing — 24 phase × 1s = 24s, snap covers 2 full cycles."""
import cv2, os, time
out_dir = r"D:\workspace\zynq_pov\tools"
cap = cv2.VideoCapture(1, cv2.CAP_MSMF)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
for _ in range(10): cap.read(); time.sleep(0.05)
for i in range(50):
    for _ in range(3): cap.grab()
    ok, frame = cap.retrieve()
    if ok:
        p = os.path.join(out_dir, f"calib_{i+1:02d}.jpg")
        cv2.imwrite(p, frame)
        print(f"[{i+1:02d}] mean={frame.mean():.1f}", flush=True)
    time.sleep(0.5)
cap.release()
