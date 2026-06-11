import cv2, sys
out = r'D:\claude_workspace\pov3d\zynq_pov\tools\panel_low_exp.jpg'
for backend in (cv2.CAP_MSMF, cv2.CAP_DSHOW):
    for idx in (3, 2, 1, 0):
        cap = cv2.VideoCapture(idx, backend)
        if not cap.isOpened(): continue
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
        for _ in range(8): cap.read()
        ok, frame = cap.read()
        cap.release()
        if not ok or frame is None: continue
        h, w = frame.shape[:2]
        mean = frame.mean()
        print(f'backend={backend} idx={idx} {w}x{h} mean={mean:.1f}')
        if mean > 80 and (w, h) == (1920, 1080):
            cv2.imwrite(out, frame)
            print(f'SAVED idx={idx} backend={backend} -> {out}')
            sys.exit(0)
print('no good camera found')
