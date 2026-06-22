import zipfile, numpy as np
z=zipfile.ZipFile(r'D:\claude_workspace\pov3d\zynq_pov_icnd2047\la2.dsl')
NS=2.0
def chbits(ch):
    raw=b''
    for b in range(2):
        try: raw+=z.read(f'L-{ch}/{b}')
        except: pass
    return np.unpackbits(np.frombuffer(raw,dtype=np.uint8),bitorder='little')
oe=chbits(6); clk=chbits(7); lat=chbits(8)
n=min(len(oe),len(clk),len(lat))
oe,clk,lat=oe[:n],clk[:n],lat[:n]
# 找一个换行事件: LAT 上升沿
lr=np.where(np.diff(lat.astype(np.int8))==1)[0]
print(f"LAT pulses={len(lr)}, total {n*NS/1e6:.2f}ms")
# 看第5个 LAT 周围 OE/CLK 时序
ev=lr[5]
w0,w1=ev-200,ev+400
seg_oe,seg_clk,seg_lat=oe[w0:w1],clk[w0:w1],lat[w0:w1]
# OE 边沿
oe_f=np.where(np.diff(seg_oe.astype(np.int8))==-1)[0]  # OE 下降(显示开始)
oe_r=np.where(np.diff(seg_oe.astype(np.int8))==1)[0]   # OE 上升(消隐)
lat_r=np.where(np.diff(seg_lat.astype(np.int8))==1)[0]
lat_f=np.where(np.diff(seg_lat.astype(np.int8))==-1)[0]
clk_e=np.where(np.diff(seg_clk.astype(np.int8))!=0)[0]
print(f"窗口内 (rel sample, *2ns):")
print(f"  OE 上升(消隐) @ {oe_r.tolist()}")
print(f"  LAT 高 @ {lat_r.tolist()}-{lat_f.tolist()}")
print(f"  OE 下降(显示) @ {oe_f.tolist()}")
# OE下降 到 之后第一个 CLK 边沿的间隔
for f in oe_f:
    nxt=clk_e[clk_e>f]
    if len(nxt): print(f"  OE↓@{f} -> 下一个CLK边沿@{nxt[0]} = {(nxt[0]-f)*NS:.0f}ns")
# OE上升前最后一个CLK边沿
for r in oe_r:
    prv=clk_e[clk_e<r]
    if len(prv): print(f"  OE↑@{r} <- 前一个CLK边沿@{prv[-1]} = {(r-prv[-1])*NS:.0f}ns")
# ASCII
def asc(s,step=4): return ''.join('#' if s[i:i+step].mean()>0.5 else '.' for i in range(0,len(s),step))
print("OE :",asc(seg_oe))
print("CLK:",asc(seg_clk))
print("LAT:",asc(seg_lat))
