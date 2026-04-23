import cv2, os
vid_new = r"D:\workspace\zynq_pov\105410cf59dd1af72248d0a7395aa1fe.mp4"
vid_old = r"D:\workspace\zynq_pov\6da140b23b16d09957804317d68a5f37.mp4"
out = r"D:\workspace\zynq_pov\vid_frames_cmp"
os.makedirs(out, exist_ok=True)
for tag, vid in [("new", vid_new), ("old", vid_old)]:
    cap = cv2.VideoCapture(vid)
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS)
    print(f"{tag}: {total} frames, {fps} fps")
    for i, t_frac in enumerate([0.1, 0.3, 0.5, 0.7, 0.9]):
        fno = int(total * t_frac)
        cap.set(cv2.CAP_PROP_POS_FRAMES, fno)
        ret, frame = cap.read()
        if ret:
            path = os.path.join(out, f"{tag}_f{i}.jpg")
            cv2.imwrite(path, frame)
            print(f"  saved {path}")
    cap.release()
