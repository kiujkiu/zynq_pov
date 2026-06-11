import cv2, numpy as np
a=cv2.imread('tools/_split_check_a.jpg').astype(int)
b=cv2.imread('tools/_split_check_b.jpg').astype(int)
print('freshness:', round(np.abs(a-b).mean(),2))
img=cv2.imread('tools/_split_check_b.jpg')
g=cv2.cvtColor(img,cv2.COLOR_BGR2GRAY).astype(float)
h,w=g.shape
# find panel area = brighter-than-background region
mask=g>50
ys,xs=np.where(mask)
x0,x1=int(np.percentile(xs,1)),int(np.percentile(xs,99))
y0,y1=int(np.percentile(ys,1)),int(np.percentile(ys,99))
mid=(x0+x1)//2
print(f'screen bbox x[{x0}:{x1}] y[{y0}:{y1}]')
for name,xa,xb in (('LEFT panel',x0,mid),('RIGHT panel',mid,x1)):
    sub=g[y0:y1,xa:xb]
    sh,sw=sub.shape
    T=sub[:sh//2,:].mean(); B=sub[sh//2:,:].mean()
    L=sub[:,:sw//2].mean(); R=sub[:,sw//2:].mean()
    clip=(sub>248).mean()*100
    print(f'{name}: mean={sub.mean():.0f} T={T:.0f} B={B:.0f} | L={L:.0f} R={R:.0f} | clipped(>248)={clip:.0f}%')
# color per panel
im=img.astype(float)
for name,xa,xb in (('LEFT',x0,mid),('RIGHT',mid,x1)):
    roi=im[y0:y1,xa:xb]
    print(f'{name} BGR=({roi[:,:,0].mean():.0f},{roi[:,:,1].mean():.0f},{roi[:,:,2].mean():.0f})')
