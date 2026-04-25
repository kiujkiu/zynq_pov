import cv2, os
vid = r"C:\Users\Administrator\Documents\xwechat_files\wxid_ebm7chfacn7c21_e95f\msg\video\2026-04\da16305ecb4e26739c16c00a66b81e55.mp4"
out = r"D:\workspace\zynq_pov\vid_frames_v6"
os.makedirs(out, exist_ok=True)
cap = cv2.VideoCapture(vid)
total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
print(f"total {total}")
for i, t in enumerate([0.15, 0.5, 0.85]):
    fno = int(total * t)
    cap.set(cv2.CAP_PROP_POS_FRAMES, fno)
    ret, frame = cap.read()
    if ret:
        cv2.imwrite(os.path.join(out, f"f{i}.jpg"), frame)
cap.release()
