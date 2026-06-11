import cv2, numpy as np
LB=(slice(150,850),slice(780,1140)); RB=(slice(150,850),slice(1320,1680))
for name,fn in (('G FULL (63/63)','_g_full.jpg'),('G LOW  ( 8/63)','_g_low.jpg')):
    img=cv2.imread('tools/'+fn).astype(float)
    lg=img[LB][:,:,1].mean(); rg=img[RB][:,:,1].mean()
    print(f'{name}: L_g={lg:5.1f} R_g={rg:5.1f}  L/R={lg/rg:.2f}')
