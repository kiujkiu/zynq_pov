import cv2, numpy as np, sys
img=cv2.imread(sys.argv[1]).astype(float)
LB=(slice(150,850),slice(780,1140)); RB=(slice(150,850),slice(1320,1680))
l,r=img[LB],img[RB]
lb,lg,lr=[l[:,:,i].mean() for i in range(3)]
rb,rg,rr=[r[:,:,i].mean() for i in range(3)]
print(f'L BGR=({lb:.0f},{lg:.0f},{lr:.0f})  R BGR=({rb:.0f},{rg:.0f},{rr:.0f})  L/R(gray)={l.mean()/r.mean():.2f}  L/R(G)={lg/rg:.2f}')
