import cv2, numpy as np
# 固定 ROI: 相机没动, 从照片直接读出两屏中心区 (1920x1080)
LB = (slice(150,850), slice(780,1140))    # left panel center
RB = (slice(150,850), slice(1320,1680))   # right panel center
tests = [
 ('B fill 0x00003F','_chan_0x00003F.jpg'),
 ('R fill 0x003F00','_chan_0x003F00.jpg'),
 ('G fill 0x3F0000','_chan_0x3F0000.jpg'),
 ('W 0x561 overlap','_white_561.jpg'),
 ('W 0x521 serial ','_white_521.jpg'),
]
print(f"{'test':18s} {'L BGR':>15s} {'R BGR':>15s}  L/R(gray)")
for name,fn in tests:
    img=cv2.imread('tools/'+fn).astype(float)
    l=img[LB]; r=img[RB]
    lb,lg,lr=[l[:,:,i].mean() for i in range(3)]
    rb,rg,rr=[r[:,:,i].mean() for i in range(3)]
    lgray=l.mean(); rgray=r.mean()
    print(f"{name:18s} ({lb:3.0f},{lg:3.0f},{lr:3.0f}) ({rb:3.0f},{rg:3.0f},{rr:3.0f})   {lgray/rgray:.2f}")
