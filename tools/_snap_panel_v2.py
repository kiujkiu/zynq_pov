import cv2, time, os

OUT_DIR = r'D:\claude_workspace\pov3d\zynq_pov\tools'

cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)  # force icspring
if not cap.isOpened():
    print("cam 0 open failed"); raise SystemExit(1)

cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
# Manual exposure (very low for bright LED panel)
cap.set(cv2.CAP_PROP_AUTO_EXPOSURE, 0.25)  # DSHOW: 0.25=manual
# auto exposure on (icspring camera), no manual locks

# warm up many frames
for _ in range(50):
    cap.read()
    time.sleep(0.05)
ret, frame = cap.read()
cap.release()

if ret and frame is not None:
    import numpy as np
    h, w = frame.shape[:2]
    # post-process: gamma + clip highlights
    # no post-process; raw camera output
    mean = float(frame.mean())
    b = float(frame[:,:,0].mean())
    g = float(frame[:,:,1].mean())
    r = float(frame[:,:,2].mean())
    path = os.path.join(OUT_DIR, 'panel_low_exp.jpg')
    cv2.imwrite(path, frame)
    print(f"{w}x{h} mean={mean:.1f}  R={r:.1f} G={g:.1f} B={b:.1f}  -> {path}")
else:
    print("read failed")
