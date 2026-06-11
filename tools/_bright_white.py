import cv2, numpy as np
img = cv2.imread("tools/_white_test.jpg")
g = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY).astype(float)
# panel = bright region. threshold high
mask = g > 90
ys,xs = np.where(mask)
x0,x1,y0,y1 = xs.min(),xs.max(),ys.min(),ys.max()
mid=(x0+x1)//2
sub = g[y0:y1, x0:x1]
# per-column mean profile to see gradient across width
prof = g[y0:y1, x0:x1].mean(axis=0)
L = g[y0:y1, x0:mid][mask[y0:y1, x0:mid]]
R = g[y0:y1, mid:x1][mask[y0:y1, mid:x1]]
print(f"bbox x[{x0}:{x1}] y[{y0}:{y1}] mid={mid}")
print(f"LEFT  white mean={L.mean():.1f}")
print(f"RIGHT white mean={R.mean():.1f}")
print(f"ratio L/R = {L.mean()/R.mean():.2f}")
# sample 5 points across width
n=len(prof)
pts=[prof[int(n*f)] for f in (0.1,0.3,0.5,0.7,0.9)]
print("profile @10/30/50/70/90%:", [round(p,0) for p in pts])
