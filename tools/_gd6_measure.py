import cv2, numpy as np
def panels(img):
    g=img[:,:,1].astype(float)  # G channel
    mask=g>50
    ys,xs=np.where(mask)
    if len(xs)<1000: return None
    x0,x1=int(np.percentile(xs,2)),int(np.percentile(xs,98))
    y0,y1=int(np.percentile(ys,2)),int(np.percentile(ys,98))
    mid=(x0+x1)//2
    L=g[y0:y1,x0:mid][mask[y0:y1,x0:mid]].mean()
    R=g[y0:y1,mid:x1][mask[y0:y1,mid:x1]].mean()
    return L,R,x0,x1
for name,fn in (('G FULL 63','_gd6_full.jpg'),('G LOW   8','_gd6_low.jpg')):
    img=cv2.imread('tools/'+fn)
    r=panels(img)
    if r is None: print(f'{name}: panel not detected'); continue
    L,R,x0,x1=r
    print(f'{name}: L={L:5.1f} R={R:5.1f} L/R={L/R:.2f}  bbox[{x0}:{x1}]')
