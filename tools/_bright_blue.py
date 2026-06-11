import cv2, numpy as np
a=cv2.imread('tools/_blue_a.jpg').astype(int); b=cv2.imread('tools/_blue_b.jpg').astype(int)
print('freshness diff a/b:', round(np.abs(a-b).mean(),2))
img=cv2.imread('tools/_blue_b.jpg')
hsv=cv2.cvtColor(img,cv2.COLOR_BGR2HSV)
# blue panel: high blue channel + saturated. mask by blue dominance
B,G,R=img[:,:,0].astype(int),img[:,:,1].astype(int),img[:,:,2].astype(int)
mask=(B>60)&(B>R+15)&(B>G+10)
ys,xs=np.where(mask)
x0,x1,y0,y1=xs.min(),xs.max(),ys.min(),ys.max()
mid=(x0+x1)//2
print(f'panel bbox x[{x0}:{x1}] y[{y0}:{y1}] mid={mid} maskpix={mask.sum()}')
val=B  # blue brightness
def region(xa,xb):
    m=mask[y0:y1,xa:xb]; v=val[y0:y1,xa:xb][m]; return v.mean(),m.sum()
Lm,Ln=region(x0,mid); Rm,Rn=region(mid,x1)
print(f'LEFT  blue mean={Lm:.1f} (n={Ln})')
print(f'RIGHT blue mean={Rm:.1f} (n={Rn})')
print(f'ratio L/R={Lm/Rm:.2f}')
# width profile of blue within panel rows
prof=[]
xs5=np.linspace(x0,x1,11).astype(int)
for i in range(10):
    seg=val[y0:y1,xs5[i]:xs5[i+1]]; mseg=mask[y0:y1,xs5[i]:xs5[i+1]]
    prof.append(round(seg[mseg].mean(),0) if mseg.sum()>50 else 0)
print('blue profile L->R (10 bins):',prof)
