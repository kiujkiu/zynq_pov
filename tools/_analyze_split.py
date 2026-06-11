import cv2, numpy as np
img=cv2.imread('tools/_panel1_halfsplit.jpg')
g=cv2.cvtColor(img,cv2.COLOR_BGR2GRAY).astype(float)
# right panel (panel1, lit) = bright region. find it
mask=g>80
ys,xs=np.where(mask)
x0,x1=int(np.percentile(xs,2)),int(np.percentile(xs,98))
y0,y1=int(np.percentile(ys,2)),int(np.percentile(ys,98))
# the lit panel is the right portion; restrict to columns where colmean high
colmean=g.mean(axis=0)
lit=np.where(colmean>colmean.max()*0.55)[0]
rx0,rx1=lit.min(),lit.max()
ry0,ry1=y0,y1
sub=g[ry0:ry1,rx0:rx1]
h,w=sub.shape
print(f'lit panel bbox x[{rx0}:{rx1}] y[{ry0}:{ry1}]  ({w}x{h})')
# quadrant means
L=sub[:,:w//2].mean(); R=sub[:,w//2:].mean()
T=sub[:h//2,:].mean(); B=sub[h//2:,:].mean()
print(f'within lit panel:  LEFT={L:.0f}  RIGHT={R:.0f}  (L/R={L/R:.2f})')
print(f'                    TOP ={T:.0f}  BOT  ={B:.0f}  (T/B={T/B:.2f})')
