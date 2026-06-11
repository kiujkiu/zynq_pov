import cv2, sys, time
# Try MSMF backend instead of DSHOW (DSHOW often locks)
for idx in range(8):
    cap = cv2.VideoCapture(idx, cv2.CAP_MSMF)
    if cap.isOpened():
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
        for _ in range(5):
            cap.read()
            time.sleep(0.05)
        ret, frame = cap.read()
        cap.release()
        if ret and frame is not None:
            h, w = frame.shape[:2]
            mean = frame.mean()
            path = f"D:\\workspace\\zynq_pov\\tools\\cam_msmf_{idx}.jpg"
            cv2.imwrite(path, frame)
            print(f"cam_msmf {idx}: {w}x{h} mean={mean:.1f} saved={path}")
