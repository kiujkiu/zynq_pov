import cv2, numpy as np
img=cv2.imread('tools/_blue_b.jpg')
B,G,R=img[:,:,0].astype(int),img[:,:,1].astype(int),img[:,:,2].astype(int)
mask=(G>70)&(G>R+20)&(G>B+10)   # green-dominant = LED panel
ys,xs=np.where(mask)
# robust bbox: use percentiles to avoid stray pixels
x0,x1=int(np.percentile(xs,1)),int(np.percentile(xs,99))
y0,y1=int(np.percentile(ys,1)),int(np.percentile(ys,99))
mid=(x0+x1)//2
print(f'panel bbox x[{x0}:{x1}] y[{y0}:{y1}] mid={mid} maskpix={mask.sum()}')
val=G
def region(xa,xb):
    m=mask[y0:y1,xa:xb]; v=val[y0:y1,xa:xb][m]; return v.mean(),m.sum()
Lm,Ln=region(x0,mid); Rm,Rn=region(mid,x1)
print(f'LEFT  green mean={Lm:.1f} (n={Ln})')
print(f'RIGHT green mean={Rm:.1f} (n={Rn})')
print(f'ratio L/R={Lm/Rm:.3f}')
xs5=np.linspace(x0,x1,11).astype(int); prof=[]
for i in range(10):
    seg=val[y0:y1,xs5[i]:xs5[i+1]]; mseg=mask[y0:y1,xs5[i]:xs5[i+1]]
    prof.append(int(seg[mseg].mean()) if mseg.sum()>50 else 0)
print('green profile L->R (10 bins):',prof)
