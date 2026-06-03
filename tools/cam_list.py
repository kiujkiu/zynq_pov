"""List available cv2 cameras by trying idx 0..5 with each backend."""
import cv2
for backend_name, backend in [("DSHOW", cv2.CAP_DSHOW), ("MSMF", cv2.CAP_MSMF), ("ANY", cv2.CAP_ANY)]:
    print(f"=== {backend_name} ===")
    for idx in range(6):
        cap = cv2.VideoCapture(idx, backend)
        if cap.isOpened():
            cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
            cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
            for _ in range(5): cap.read()
            ok, f = cap.read()
            w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
            h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
            backend_actual = cap.getBackendName()
            cap.release()
            if ok and f is not None:
                print(f"  idx={idx}: {w}x{h}  backend={backend_actual}  mean={f.mean():.1f}")
            else:
                print(f"  idx={idx}: opened but no frame  backend={backend_actual}")
        else:
            print(f"  idx={idx}: not available")
