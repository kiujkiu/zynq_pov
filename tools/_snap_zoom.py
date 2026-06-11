"""Snap Insta360 + crop to panel area + upscale."""
import cv2, time, os
import numpy as np
OUT_DIR = r'D:\claude_workspace\pov3d\zynq_pov\tools'
cap = cv2.VideoCapture(1, cv2.CAP_MSMF)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
for _ in range(20):
    cap.read(); time.sleep(0.04)
ret, frame = cap.read()
cap.release()
if ret and frame is not None:
    # save raw
    cv2.imwrite(os.path.join(OUT_DIR, 'panel_raw.jpg'), frame)
    # find brightest region (panel) and crop
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    # threshold + find bounding box of bright pixels
    _, mask = cv2.threshold(gray, 80, 255, cv2.THRESH_BINARY)
    coords = cv2.findNonZero(mask)
    if coords is not None:
        x, y, w, h = cv2.boundingRect(coords)
        crop = frame[y:y+h, x:x+w]
        # upscale 2x
        ch, cw = crop.shape[:2]
        out = cv2.resize(crop, (cw*2, ch*2), interpolation=cv2.INTER_NEAREST)
        path = os.path.join(OUT_DIR, 'panel_low_exp.jpg')
        cv2.imwrite(path, out)
        print(f"cropped panel area {w}x{h}, upscaled to {cw*2}x{ch*2} -> {path}")
    else:
        cv2.imwrite(os.path.join(OUT_DIR, 'panel_low_exp.jpg'), frame)
        print("no bright region found, saved raw")
