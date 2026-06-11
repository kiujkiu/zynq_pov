import cv2, numpy as np
a = cv2.imread("tools/_chess_now.jpg").astype(int)
b = cv2.imread("tools/_chess_rot180.jpg").astype(int)
if a.shape != b.shape:
    print("shape differ", a.shape, b.shape)
d = np.abs(a-b)
print("mean abs diff full:", d.mean())
# center panel region approx
h,w = a.shape[:2]
roi = d[int(h*0.05):int(h*0.95), int(w*0.30):int(w*0.66)]
print("mean abs diff panel ROI:", roi.mean(), "max:", roi.max())
