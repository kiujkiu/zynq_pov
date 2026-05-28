"""Snap 24 frames at 0.2s spacing to cover all 6 phases (3s/cycle) twice."""
import cv2, os, time
out_dir = r"D:\workspace\zynq_pov\tools"
cap = cv2.VideoCapture(1, cv2.CAP_MSMF)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
for _ in range(10): cap.read(); time.sleep(0.05)
for i in range(24):
    for _ in range(3): cap.grab()
    ok, frame = cap.retrieve()
    if ok:
        p = os.path.join(out_dir, f"verify_{i+1:02d}.jpg")
        cv2.imwrite(p, frame)
        print(f"[{i+1:02d}] mean={frame.mean():.1f} -> {p}", flush=True)
    time.sleep(0.2)
cap.release()
