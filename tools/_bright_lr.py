import cv2, numpy as np
img = cv2.imread("tools/_chess_final.jpg")
g = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY).astype(float)
h,w = g.shape
# panel area roughly: find bright columns
colmean = g.mean(axis=0)
bright_cols = np.where(colmean > colmean.max()*0.4)[0]
x0,x1 = bright_cols.min(), bright_cols.max()
mid = (x0+x1)//2
# restrict vertical to panel (bright rows)
rowmean = g[:, x0:x1].mean(axis=1)
bright_rows = np.where(rowmean > rowmean.max()*0.4)[0]
y0,y1 = bright_rows.min(), bright_rows.max()
left = g[y0:y1, x0:mid]
right = g[y0:y1, mid:x1]
print(f"panel bbox x[{x0}:{x1}] y[{y0}:{y1}] mid={mid}")
print(f"LEFT  mean={left.mean():.1f}")
print(f"RIGHT mean={right.mean():.1f}")
print(f"ratio L/R = {left.mean()/right.mean():.2f}")
