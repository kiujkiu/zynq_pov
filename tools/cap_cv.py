"""Grab 16 frames at 0.5s spacing from icspring (MSMF idx1).
chip_sweep cycles 12 chips every 60 frame, full cycle ~6s."""
import cv2, os, time, sys
out_dir = r"D:\workspace\zynq_pov\tools"
prefix = sys.argv[1] if len(sys.argv) > 1 else "chip"

cap = cv2.VideoCapture(1, cv2.CAP_MSMF)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
for _ in range(10): cap.read(); time.sleep(0.05)
for i in range(16):
    for _ in range(3): cap.grab()
    ok, frame = cap.retrieve()
    if ok:
        p = os.path.join(out_dir, f"{prefix}_{i+1:02d}.jpg")
        cv2.imwrite(p, frame)
        print(f"[{i+1:02d}] mean={frame.mean():.1f} -> {p}", flush=True)
    time.sleep(0.5)
cap.release()
