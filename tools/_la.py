import zipfile, numpy as np, sys
z = zipfile.ZipFile(r'D:\claude_workspace\pov3d\zynq_pov_icnd2047\la.dsl')
SR=500e6
def chbits(ch, nblocks=1):
    raw=b''
    for b in range(nblocks):
        raw += z.read(f'L-{ch}/{b}')
    return np.unpackbits(np.frombuffer(raw,dtype=np.uint8), bitorder='little')
# window: first block only (~16.7M samples = 33ms)
print(f"{'ch':>3} {'edges':>9} {'duty%':>6} {'minHigh_ns':>10} {'minLow_ns':>9}")
for ch in range(16):
    bits=chbits(ch,1)
    d=np.diff(bits.astype(np.int8))
    rises=np.where(d==1)[0]; falls=np.where(d==-1)[0]
    edges=int(len(rises)+len(falls))
    duty=bits.mean()*100
    # min high width
    mh=ml=0
    if len(rises)>2 and len(falls)>2:
        # pair rises->next fall
        widths_h=[]; widths_l=[]
        # high runs
        rr=rises; ff=falls
        # compute via consecutive edges
        alle=np.sort(np.concatenate([rises,falls]))
        if len(alle)>3:
            difs=np.diff(alle)
            mh=int(difs.min())
    print(f"{ch:>3} {edges:>9} {duty:>6.1f} {mh*2:>10}")
