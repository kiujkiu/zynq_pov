"""Cap via ANY backend idx 0 with low exposure."""
import cv2, time, sys
out = r"D:\claude_workspace\pov3d\zynq_pov\panel_now.jpg"
exp = float(sys.argv[1]) if len(sys.argv) > 1 else -10.0
cap = cv2.VideoCapture(0, cv2.CAP_ANY)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
cap.set(cv2.CAP_PROP_AUTO_EXPOSURE, 0.25)
cap.set(cv2.CAP_PROP_EXPOSURE, exp)
for _ in range(25):
    cap.read(); time.sleep(0.04)
ok, frame = cap.read()
cap.release()
if ok and frame is not None:
    cv2.imwrite(out, frame)
    print(f"OK exp={exp} mean={frame.mean():.1f} -> {out}")
else:
    print("FAIL")
