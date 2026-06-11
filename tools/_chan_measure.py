import cv2, numpy as np, sys
fn = sys.argv[1]
img=cv2.imread(fn)
im=img.astype(float)
B,G,R=im[:,:,0],im[:,:,1],im[:,:,2]
gray=cv2.cvtColor(img,cv2.COLOR_BGR2GRAY).astype(float)
# lit panel mask: bright + saturated vs dark office bg
hsv=cv2.cvtColor(img,cv2.COLOR_BGR2HSV)
mask=(gray>45)&(hsv[:,:,1]>40)
if mask.sum()<5000: mask=gray>60
ys,xs=np.where(mask)
x0,x1=int(np.percentile(xs,2)),int(np.percentile(xs,98))
y0,y1=int(np.percentile(ys,2)),int(np.percentile(ys,98))
mid=(x0+x1)//2
out={}
for name,xa,xb in (('L',x0,mid),('R',mid,x1)):
    m=mask[y0:y1,xa:xb]
    bb,gg,rr=[c[y0:y1,xa:xb][m].mean() for c in (B,G,R)]
    out[name]=(bb,gg,rr)
    dom=max([('B',bb),('G',gg),('R',rr)],key=lambda t:t[1])
    clip=(gray[y0:y1,xa:xb][m]>248).mean()*100
    print(f'{name}: BGR=({bb:.0f},{gg:.0f},{rr:.0f}) dom={dom[0]} clip={clip:.0f}%')
lb,lg,lr=out['L']; rb,rg,rr_=out['R']
# ratio on dominant channel of the brighter side
vals={'B':(lb,rb),'G':(lg,rg),'R':(lr,rr_)}
dom=max(vals,key=lambda k:max(vals[k]))
l,r=vals[dom]
print(f'dominant={dom}  L/R = {l/r:.2f}   bbox x[{x0}:{x1}]')
