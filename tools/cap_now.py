"""Try every backend to capture icspring."""
import cv2, time, os, sys
out = r"D:\claude_workspace\pov3d\zynq_pov\panel_cap.jpg"
for be_name, be in [("MSMF", cv2.CAP_MSMF), ("DSHOW", cv2.CAP_DSHOW), ("ANY", cv2.CAP_ANY)]:
    for idx in [0, 1, 2]:
        cap = cv2.VideoCapture(idx, be)
        if not cap.isOpened():
            cap.release(); continue
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
        if be == cv2.CAP_DSHOW:
            cap.set(cv2.CAP_PROP_AUTO_EXPOSURE, 0.25)
            cap.set(cv2.CAP_PROP_EXPOSURE, -8)
        for _ in range(15): cap.read(); time.sleep(0.04)
        ok, frame = cap.read()
        if ok and frame is not None:
            h, w = frame.shape[:2]
            tag = f"{be_name}_{idx}_{w}x{h}_m{frame.mean():.0f}"
            cv2.imwrite(out.replace(".jpg", f"_{tag}.jpg"), frame)
            print(f"{be_name} idx={idx} OK {w}x{h} mean={frame.mean():.1f}")
        cap.release()
        time.sleep(0.5)
