import cv2, numpy as np
a=cv2.imread('tools/_rot_a.jpg').astype(int); b=cv2.imread('tools/_rot_b.jpg').astype(int)
print('frame diff:', round(np.abs(a-b).mean(),2), '(>5 = 在动)')
