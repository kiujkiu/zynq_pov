import cv2
for be in (cv2.CAP_MSMF, cv2.CAP_DSHOW):
    for i in range(6):
        c = cv2.VideoCapture(i, be)
        ok = c.isOpened() and c.grab()
        if ok:
            ret, f = c.read()
            mean = f.mean() if f is not None else -1
            print(f'be={be} idx={i} OK mean={mean:.0f}')
        else:
            print(f'be={be} idx={i} fail')
        c.release()
