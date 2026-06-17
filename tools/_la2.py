import zipfile, numpy as np
z = zipfile.ZipFile(r'D:\claude_workspace\pov3d\zynq_pov_icnd2047\la.dsl')
SR=500e6; NS=2.0  # ns per sample
def chbits(ch):
    return np.unpackbits(np.frombuffer(z.read(f'L-{ch}/0'),dtype=np.uint8),bitorder='little')
dclk=chbits(7); lat=chbits(8); oe=chbits(6)
# find first LAT rising edge
lr=np.where(np.diff(lat.astype(np.int8))==1)[0]
lf=np.where(np.diff(lat.astype(np.int8))==-1)[0]
print(f"LAT pulses in block0: {len(lr)}")
# examine 2nd latch event (skip first partial)
ev=lr[2]
w0=ev-120; w1=lf[lf>ev][0]+60
seg_d=dclk[w0:w1]; seg_l=lat[w0:w1]
# DCLK edges in window
dd=np.where(np.diff(seg_d.astype(np.int8))!=0)[0]
# LAT high region within window
lat_hi=np.where(seg_l==1)[0]
lh0,lh1=lat_hi[0],lat_hi[-1]
print(f"window {w0}..{w1} ({(w1-w0)*NS:.0f}ns). LAT high: sample {lh0}..{lh1} rel ({ (lh1-lh0)*NS:.0f}ns wide)")
# DCLK edges before LAT-high, during, after
before=dd[dd<lh0]; during=dd[(dd>=lh0)&(dd<=lh1)]; after=dd[dd>lh1]
print(f"DCLK edges: before-LAT={len(before)}, DURING-LAT={len(during)}, after-LAT={len(after)}")
# last DCLK edge before LAT rises, and gap
if len(before): 
    gap=(lh0-before[-1])*NS
    print(f"last shift DCLK edge -> LAT rise gap = {gap:.0f} ns")
# during-LAT DCLK edge spacing
if len(during)>1:
    print(f"during-LAT DCLK edges at rel-samples {during.tolist()} (spacing {np.diff(during)*NS} ns)")
elif len(during)==1:
    print(f"during-LAT single DCLK edge at {during[0]}")
else:
    print("NO DCLK edges during LAT high  <-- LE 不在 clk 上!")
# ASCII around LAT
print("\n=== ASCII (每字符=4样=8ns) DCLK / LAT / OE ===")
def ascii_sig(seg,step=4):
    return ''.join('#' if seg[i:i+step].mean()>0.5 else '.' for i in range(0,len(seg),step))
print("DCLK:",ascii_sig(seg_d))
print("LAT :",ascii_sig(seg_l))
print("OE  :",ascii_sig(oe[w0:w1]))
