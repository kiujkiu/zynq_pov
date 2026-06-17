import zipfile, numpy as np
z = zipfile.ZipFile(r'D:\claude_workspace\pov3d\zynq_pov_icnd2047\la.dsl')
def chbits(ch):
    return np.unpackbits(np.frombuffer(z.read(f'L-{ch}/0'),dtype=np.uint8),bitorder='little')
dclk=chbits(7); lat=chbits(8)
dr=np.where(np.diff(dclk.astype(np.int8))==1)[0]   # DCLK rising edges
lr=np.where(np.diff(lat.astype(np.int8))==1)[0]    # LAT rising
lf=np.where(np.diff(lat.astype(np.int8))==-1)[0]
print(f"DCLK rises total={len(dr)}, LAT pulses={len(lr)}")
# DCLK rising edges per LAT interval (between successive LAT rises) = per-row shift+cmd
cnts=[]
for i in range(3,13):
    a,b=lr[i],lr[i+1]
    n=int(np.count_nonzero((dr>=a)&(dr<b)))
    cnts.append(n)
print(f"DCLK rises per LAT-to-LAT interval (10 rows): {cnts}")
# rising edges during each LAT-high
dur=[]
for i in range(3,13):
    a=lr[i]; b=lf[lf>a][0]
    dur.append(int(np.count_nonzero((dr>=a)&(dr<=b))))
print(f"DCLK rises during LAT-high: {dur}")
# total DCLK rises in one full frame? estimate via LAT count: 6 planes*32 rows=192 latch/frame
print(f"\n推断: 屏 128 列, 若每行移位=128 列, 期望每 LAT 间隔 DCLK 上升沿≈128; 实测见上")
