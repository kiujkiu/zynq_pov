"""Probe + capture from the USB HDMI capture device.
Tries indices 0..5 with both DSHOW and MSMF backends, logs resolution + sample.
"""
import cv2
import sys
import os

OUT_DIR = r"D:\workspace\zynq_pov\hdmi_probe"
os.makedirs(OUT_DIR, exist_ok=True)

backends = [(cv2.CAP_DSHOW, "DSHOW"), (cv2.CAP_MSMF, "MSMF")]

for backend, name in backends:
    for idx in range(0, 5):
        cap = cv2.VideoCapture(idx, backend)
        if not cap.isOpened():
            cap.release()
            continue
        # try to set 1280x720
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
        # warm up
        for _ in range(5):
            cap.read()
        w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        ret, frame = cap.read()
        if ret and frame is not None:
            mean = frame.mean()
            tag = f"{name}_idx{idx}_{w}x{h}_mean{mean:.0f}"
            path = os.path.join(OUT_DIR, f"{tag}.jpg")
            cv2.imwrite(path, frame)
            print(f"[{name}] #{idx}: {w}x{h} mean={mean:.0f}  -> {tag}.jpg")
        else:
            print(f"[{name}] #{idx}: opened but read failed")
        cap.release()
