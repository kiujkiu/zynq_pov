"""Test if cv2 exposure control works on this webcam by sweeping exp."""
import cv2, time, os
out_dir = r"D:\claude_workspace\pov3d\zynq_pov"
for exp in [-4, -6, -8, -10, -12, -14]:
    cap = cv2.VideoCapture(0, cv2.CAP_ANY)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
    cap.set(cv2.CAP_PROP_AUTO_EXPOSURE, 0.25)
    cap.set(cv2.CAP_PROP_EXPOSURE, exp)
    for _ in range(25): cap.read(); time.sleep(0.04)
    ok, frame = cap.read()
    if ok:
        cv2.imwrite(os.path.join(out_dir, f"cap_exp_{exp}.jpg"), frame)
        # check panel region
        roi = frame[100:400, 100:500]
        print(f"exp={exp} mean_full={frame.mean():.1f} mean_panel={roi.mean():.1f}")
    cap.release()
    time.sleep(0.5)
