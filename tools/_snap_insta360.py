"""Snap from Insta360 Link 2 Pro (or whichever cam returns highest mean)."""
import cv2, time, os, sys

OUT_DIR = r'D:\claude_workspace\pov3d\zynq_pov\tools'

best = None
for backend in [cv2.CAP_MSMF, cv2.CAP_DSHOW]:
    for idx in range(4):
        cap = cv2.VideoCapture(idx, backend)
        if not cap.isOpened():
            continue
        # Try high res for Insta360 4K
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
        for _ in range(20):
            cap.read(); time.sleep(0.04)
        ret, f = cap.read()
        h, w = (f.shape[:2] if (ret and f is not None) else (0, 0))
        m = float(f.mean()) if (ret and f is not None) else 0.0
        print(f"backend={backend} idx={idx} {w}x{h} mean={m:.1f}")
        if ret and f is not None and m > 5.0:
            if best is None or w*h > best[3]*best[4]:
                best = (backend, idx, f.copy(), w, h, m)
        cap.release()

if best:
    backend, idx, frame, w, h, mean = best
    path = os.path.join(OUT_DIR, 'panel_low_exp.jpg')
    cv2.imwrite(path, frame)
    print(f"BEST: backend={backend} idx={idx} {w}x{h} mean={mean:.1f} -> {path}")
else:
    print("no working camera")
