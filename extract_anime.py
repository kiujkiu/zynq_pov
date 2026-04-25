import cv2, os
vid = r"C:\Users\Administrator\Documents\xwechat_files\wxid_ebm7chfacn7c21_e95f\msg\video\2026-04\2d869ee8bf78d90226fcfd5eaa87233e.mp4"
out = r"D:\workspace\zynq_pov\vid_frames_anime"
os.makedirs(out, exist_ok=True)
cap = cv2.VideoCapture(vid)
total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
fps = cap.get(cv2.CAP_PROP_FPS)
print(f"total {total}, fps {fps}")
for i, t in enumerate([0.1, 0.3, 0.5, 0.7, 0.9]):
    fno = int(total * t)
    cap.set(cv2.CAP_PROP_POS_FRAMES, fno)
    ret, frame = cap.read()
    if ret:
        p = os.path.join(out, f"f{i}.jpg")
        cv2.imwrite(p, frame)
        print(f"saved {p}")
cap.release()
