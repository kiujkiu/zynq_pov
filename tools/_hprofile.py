import cv2, numpy as np
img=cv2.imread('tools/_both_halfsplit.jpg')
g=cv2.cvtColor(img,cv2.COLOR_BGR2GRAY).astype(float)
h,w=g.shape
# 12 vertical bins across width, mean brightness (panel rows only: middle 60%)
band=g[int(h*0.2):int(h*0.8),:]
xs=np.linspace(0,w,13).astype(int)
prof=[int(band[:,xs[i]:xs[i+1]].mean()) for i in range(12)]
print(f'image {w}x{h}')
print('horizontal brightness profile (L->R, 12 bins):')
print(prof)
