import cv2, sys
out = r'D:\claude_workspace\pov3d\zynq_pov\tools\panel_low_exp.jpg'
frame = None
# 2026-06-11: DSHOW idx=2 实测稳定可用, 放最前跳过 MSMF ~5s 失败探测 (减少设备占用防驱动挂)
for be, idxs in ((cv2.CAP_DSHOW, (2, 1, 0, 3)), (cv2.CAP_MSMF, (1, 0, 2, 3))):
    for idx in idxs:
        try:
            cap = cv2.VideoCapture(idx, be)
            if not cap.isOpened(): cap.release(); continue
            cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
            cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
            for _ in range(8): cap.read()
            ok, f = cap.read()
            cap.release()
            if ok and f is not None and f.shape[0] >= 720 and f.mean() > 60:
                frame = f
                print(f'cam be={be} idx={idx} {f.shape[1]}x{f.shape[0]}')
                break
        except Exception as e:
            print(f'err be={be} idx={idx}: {e}')
    if frame is not None: break
if frame is None:
    print('CAMERA FAILED'); sys.exit(1)
h, w = frame.shape[:2]
h, w = frame.shape[:2]
cv2.imwrite(out, frame)
# panel detection: HSV center 400x400 saturation
hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
cx, cy = w//2, h//2
roi = hsv[cy-200:cy+200, cx-200:cx+200]
sat_mean = roi[:,:,1].mean()
val_mean = roi[:,:,2].mean()
print(f'saved {w}x{h} center_sat={sat_mean:.1f} center_val={val_mean:.1f}')
if sat_mean < 50:
    print('WARNING: low saturation in center, camera may have shifted off panel')
