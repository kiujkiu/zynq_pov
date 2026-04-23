import cv2, os
vid = r"D:\workspace\zynq_pov\6da140b23b16d09957804317d68a5f37.mp4"
out = r"D:\workspace\zynq_pov\vid_frames"
os.makedirs(out, exist_ok=True)
cap = cv2.VideoCapture(vid)
total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
fps = cap.get(cv2.CAP_PROP_FPS)
print(f"total frames: {total}, fps: {fps}")
# Extract 6 evenly spaced frames
for i, t_frac in enumerate([0.0, 0.2, 0.4, 0.6, 0.8, 0.95]):
    fno = int(total * t_frac)
    cap.set(cv2.CAP_PROP_POS_FRAMES, fno)
    ret, frame = cap.read()
    if ret:
        path = os.path.join(out, f"f{i}_frame{fno}.jpg")
        cv2.imwrite(path, frame)
        print(f"saved {path}")
cap.release()
