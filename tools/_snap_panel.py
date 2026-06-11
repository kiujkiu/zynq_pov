import cv2, time, os, sys

OUT_DIR = r'D:\claude_workspace\pov3d\zynq_pov\tools'

# icspring is usually idx 1 or 2 (idx 0 is the HDMI capture often)
results = []
for idx in range(6):
    cap = cv2.VideoCapture(idx, cv2.CAP_DSHOW)
    if not cap.isOpened():
        continue
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
    # warm up - panel LED needs longer integration
    for _ in range(15):
        cap.read()
        time.sleep(0.05)
    ret, frame = cap.read()
    cap.release()
    if ret and frame is not None:
        h, w = frame.shape[:2]
        mean = float(frame.mean())
        # rough color stats
        b_mean = float(frame[:,:,0].mean())
        g_mean = float(frame[:,:,1].mean())
        r_mean = float(frame[:,:,2].mean())
        path = os.path.join(OUT_DIR, f'panel_cam_{idx}.jpg')
        cv2.imwrite(path, frame)
        results.append((idx, w, h, mean, r_mean, g_mean, b_mean, path))
        print(f"cam {idx}: {w}x{h} mean={mean:.1f}  R={r_mean:.1f} G={g_mean:.1f} B={b_mean:.1f}  -> {path}")
    else:
        print(f"cam {idx}: read failed")

print(f"\n{len(results)} camera(s) captured")
