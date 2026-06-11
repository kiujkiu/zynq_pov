import cv2, numpy as np
for cmd,fn in [("RED cmd (byte0)","_test_RED.jpg"),("GREEN cmd (byte1)","_test_GREEN.jpg"),("BLUE cmd (byte2)","_test_BLUE.jpg")]:
    img = cv2.imread("tools/"+fn)
    h,w = img.shape[:2]
    # find brightest region: threshold then bbox, sample its mean
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    mask = gray > 60
    ys,xs = np.where(mask)
    if len(xs)<50:
        print(f"{cmd}: panel not found"); continue
    y0,y1,x0,x1 = ys.min(),ys.max(),xs.min(),xs.max()
    roi = img[y0:y1,x0:x1]
    m = roi[gray[y0:y1,x0:x1]>60]
    b,g,r = m[:,0].mean(), m[:,1].mean(), m[:,2].mean()
    dom = max([("R",r),("G",g),("B",b)], key=lambda t:t[1])[0]
    print(f"{cmd:18s} -> lit BGR=({b:5.0f},{g:5.0f},{r:5.0f})  dominant={dom}  bbox={x1-x0}x{y1-y0}")
