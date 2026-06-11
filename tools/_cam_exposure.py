"""Scan camera exposure to find a value that makes panel LEDs visible."""
import cv2, time, os
cap = cv2.VideoCapture(1, cv2.CAP_MSMF)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
for _ in range(5):
    cap.read(); time.sleep(0.05)

# Disable auto exposure first
cap.set(cv2.CAP_PROP_AUTO_EXPOSURE, 0.25)  # 0.25 = manual on Logitech/MSMF
out = r"D:\workspace\zynq_pov\tools\calib_out"
# MSMF exposure values: typically negative log2 seconds. -7 = 1/128s, -4 = 1/16s, -1 = 0.5s
for ev in [-1, -2, -3, -4, -5, -6, -7, -8]:
    cap.set(cv2.CAP_PROP_EXPOSURE, ev)
    for _ in range(5):
        cap.grab()
    ok, f = cap.retrieve()
    if ok:
        actual = cap.get(cv2.CAP_PROP_EXPOSURE)
        m = f.mean()
        cv2.imwrite(os.path.join(out, f"_exp_{ev}.jpg"), f)
        print(f"  EV={ev} actual={actual:.3f} shape={f.shape} mean={m:.1f}")
cap.release()
