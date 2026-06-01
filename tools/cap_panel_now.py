"""Single grab of icspring (MSMF idx1)."""
import cv2, sys, time
out = r"D:\workspace\zynq_pov\tools\panel_now.jpg"
cap = cv2.VideoCapture(1, cv2.CAP_MSMF)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
for _ in range(15): cap.read(); time.sleep(0.05)
ok, frame = cap.retrieve()
if ok:
    cv2.imwrite(out, frame)
    print(f"mean={frame.mean():.1f}  max={frame.max()}  saved {out}")
else:
    print("capture failed")
cap.release()
