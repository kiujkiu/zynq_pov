import cv2, time, hashlib

for backend, name in [(cv2.CAP_MSMF, "MSMF"), (cv2.CAP_DSHOW, "DSHOW")]:
    print(f"\n=== {name} idx=0 ===")
    cap = cv2.VideoCapture(0, backend)
    if not cap.isOpened():
        print("  failed to open"); continue
    cap.set(cv2.CAP_PROP_FRAME_WIDTH,  1920)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
    # warm up
    for _ in range(5):
        cap.read(); time.sleep(0.05)
    hashes = []
    for i in range(5):
        # Try aggressive flush
        for _ in range(5):
            cap.grab()
        ok, f = cap.retrieve()
        if not ok:
            print(f"  [{i}] retrieve fail"); continue
        h = hashlib.md5(f.tobytes()).hexdigest()[:8]
        hashes.append(h)
        print(f"  [{i}] shape={f.shape} mean={f.mean():.1f} md5={h}")
        time.sleep(1.0)  # 1s between to make sure panel state changes
    unique = len(set(hashes))
    print(f"  {unique}/{len(hashes)} unique frames")
    cap.release()
