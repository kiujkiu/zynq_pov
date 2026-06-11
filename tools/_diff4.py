import cv2, numpy as np
a = cv2.imread("tools/_chess_vflip.jpg").astype(int)
b = cv2.imread("tools/_chess_final.jpg").astype(int)
print("diff vs prev(vflip):", round(np.abs(a-b).mean(),2))
