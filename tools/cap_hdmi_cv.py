"""cv2 capture from DSHOW idx 0 (C1-1 USB3 Video)."""
import cv2, time
cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
for _ in range(20):
    cap.read(); time.sleep(0.05)
ok, f = cap.read()
cap.release()
if ok and f is not None:
    out = r"D:\claude_workspace\pov3d\zynq_pov\hdmi_capture.jpg"
    cv2.imwrite(out, f)
    print(f"OK {f.shape} mean={f.mean():.1f} -> {out}")
else:
    print("FAIL")
