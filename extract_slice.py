import cv2, os
vid = r"C:\Users\Administrator\Documents\xwechat_files\wxid_ebm7chfacn7c21_e95f\msg\video\2026-04\2f11b3f411a1b08be6ef19a6b5b7c05d.mp4"
out = r"D:\workspace\zynq_pov\vid_frames_slice"
os.makedirs(out, exist_ok=True)
cap = cv2.VideoCapture(vid)
total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
print(f"total {total}")
for i, t in enumerate([0.2, 0.5, 0.8]):
    fno = int(total * t)
    cap.set(cv2.CAP_PROP_POS_FRAMES, fno)
    ret, frame = cap.read()
    if ret:
        cv2.imwrite(os.path.join(out, f"f{i}.jpg"), frame)
        print(f"f{i} @ {fno}")
cap.release()
