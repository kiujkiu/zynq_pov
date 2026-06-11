import cv2, time
for idx in range(4):
    for backend, name in [(cv2.CAP_MSMF, "MSMF"), (cv2.CAP_DSHOW, "DSHOW")]:
        cap = cv2.VideoCapture(idx, backend)
        if not cap.isOpened():
            cap.release(); continue
        for _ in range(3):
            cap.read(); time.sleep(0.05)
        ok, f = cap.read()
        if ok:
            print(f"idx={idx} {name}: opened, shape={f.shape}, mean={f.mean():.1f}")
        else:
            print(f"idx={idx} {name}: opened but read FAIL")
        cap.release()
