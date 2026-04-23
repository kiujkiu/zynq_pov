import cv2, os
vid = r"D:\workspace\zynq_pov\610bb3bbc3c4a45b99c313d28669a104.mp4"
out = r"D:\workspace\zynq_pov\vid_frames_db"
os.makedirs(out, exist_ok=True)
cap = cv2.VideoCapture(vid)
total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
fps = cap.get(cv2.CAP_PROP_FPS)
print(f"total frames: {total}, fps: {fps}")
# Capture many close frames to see flicker pattern
for i, t_frac in enumerate([0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]):
    fno = int(total * t_frac)
    cap.set(cv2.CAP_PROP_POS_FRAMES, fno)
    ret, frame = cap.read()
    if ret:
        path = os.path.join(out, f"f{i}.jpg")
        cv2.imwrite(path, frame)
        print(f"saved {path}")
cap.release()
