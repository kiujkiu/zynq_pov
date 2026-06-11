import cv2, numpy as np
a = cv2.imread("tools/_chess_check2.jpg").astype(int)
b = cv2.imread("tools/_chess_vflip.jpg").astype(int)
print("diff vs prev(check2):", round(np.abs(a-b).mean(),2))
