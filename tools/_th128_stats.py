import cv2, numpy as np
for i in (1,2,3):
    img=cv2.imread(f'tools/_th128_{i}.jpg')
    g=cv2.cvtColor(img,cv2.COLOR_BGR2GRAY)
    # panel区域: 中央
    roi=g[150:850, 700:1700]
    lit=(roi>60).sum()
    print(f'frame {i}: lit_pixels={lit}')
