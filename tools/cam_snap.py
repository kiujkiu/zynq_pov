import cv2, sys, time, os
out_dir = r'D:\workspace\zynq_pov\tools'
for idx in range(8):
    cap = cv2.VideoCapture(idx, cv2.CAP_DSHOW)
    if not cap.isOpened():
        continue
    # Try max resolution
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
    for _ in range(10):
        ret, frame = cap.read()
        time.sleep(0.08)
    ret, frame = cap.read()
    cap.release()
    if ret and frame is not None:
        h, w = frame.shape[:2]
        mean = frame.mean()
        path = os.path.join(out_dir, f'cam_{idx}.jpg')
        cv2.imwrite(path, frame)
        print(f"cam {idx}: {w}x{h} mean_brightness={mean:.1f} saved={path}")
    else:
        print(f"cam {idx}: read failed")
