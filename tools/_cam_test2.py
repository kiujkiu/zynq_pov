import cv2, time, hashlib
# Test idx=1 MSMF at full res with proper grab
cap = cv2.VideoCapture(1, cv2.CAP_MSMF)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
for _ in range(10):
    cap.read(); time.sleep(0.05)
print("warmed up")
for i in range(5):
    for _ in range(5):
        cap.grab()
    ok, f = cap.retrieve()
    if ok:
        h = hashlib.md5(f.tobytes()).hexdigest()[:8]
        print(f"  [{i}] {f.shape} mean={f.mean():.1f} md5={h}")
        cv2.imwrite(rf"D:\workspace\zynq_pov\tools\calib_out\_test_{i}.jpg", f)
    time.sleep(0.5)
cap.release()
print("saved _test_*.jpg")
