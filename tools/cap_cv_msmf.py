import cv2, os, time, sys
out_dir = r"D:\workspace\zynq_pov\tools"
for idx in range(6):
    cap = cv2.VideoCapture(idx, cv2.CAP_MSMF)
    print(f"idx{idx} MSMF: isOpened={cap.isOpened()}", flush=True)
    if cap.isOpened():
        for _ in range(10): cap.read(); time.sleep(0.05)
        ok, frame = cap.read()
        if ok:
            print(f"  idx{idx}: {frame.shape} mean={frame.mean():.1f}", flush=True)
    cap.release()
    time.sleep(0.3)
