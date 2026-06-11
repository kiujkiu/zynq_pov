import cv2, numpy as np
a = cv2.imread("tools/_chess_rot180.jpg").astype(int)
b = cv2.imread("tools/_chess_check2.jpg").astype(int)
print("diff vs prev snap:", np.abs(a-b).mean())
