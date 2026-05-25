"""Dump per-frame pattern. Boot init only happens once now (won't be in capture),
so look for periodic VSYNC (LE=3) + LATCH burst pattern."""
import zipfile, sys, numpy as np
from collections import Counter

DSL = sys.argv[1] if len(sys.argv) > 1 else r'C:\Users\kiujkiu\Desktop\DSLogic U2Pro16-la-260522-174731.dsl'
SR = 25_000_000

def load_ch(zf, ch):
    parts = []
    for blk in range(4):
        try: parts.append(zf.read(f'L-{ch}/{blk}'))
        except KeyError: break
    if not parts: return None
    return np.unpackbits(np.frombuffer(b''.join(parts), dtype=np.uint8), bitorder='little')

zf = zipfile.ZipFile(DSL)
dclk = load_ch(zf, 0)
le   = load_ch(zf, 1)

dclk_rises = np.where(np.diff(dclk.astype(np.int8)) == 1)[0]
le_d = np.diff(le.astype(np.int8))
le_r = np.where(le_d == 1)[0]
le_f = np.where(le_d == -1)[0]
if le_f[0] < le_r[0]: le_f = le_f[1:]
n = min(len(le_r), len(le_f))

# True DCLK count inside each LE high window
true_cnt = []
for i in range(n):
    c = np.searchsorted(dclk_rises, le_f[i]) - np.searchsorted(dclk_rises, le_r[i])
    true_cnt.append(int(c))

# Find first VSYNC (LE=3) - this marks start of each frame
first_vsync = next((i for i, c in enumerate(true_cnt) if c == 3), None)
print(f"First VSYNC @ idx {first_vsync}, t={le_r[first_vsync]/SR*1e6:.2f}us")

# Histogram
ct = Counter(true_cnt)
print()
print(f"=== LE pulse command histogram (total {n}) ===")
cmds = {1:'LATCH', 3:'VSYNC', 5:'WR_CFG', 7:'RD_CFG', 11:'EN_OP', 12:'DIS_OP', 14:'PRE_ACT'}
for w in sorted(ct.keys()):
    print(f"  {w:>3} DCLK: {ct[w]:>7}x   {cmds.get(w, '??')}")

# Dump 50 LE pulses starting from first VSYNC
print()
print(f"=== 50 LE pulses from first VSYNC ===")
print(f"{'idx':>4} {'t_us':>10} {'width':>6} {'dt_us':>8} {'gap_DCLK':>9} {'cmd':<10}")
prev_t = None
prev_f = None
for k in range(first_vsync, min(first_vsync + 50, n)):
    t_us = le_r[k] / SR * 1e6
    w = true_cnt[k]
    dt = (t_us - prev_t) if prev_t else 0
    gap = (np.searchsorted(dclk_rises, le_r[k]) - np.searchsorted(dclk_rises, prev_f)) if prev_f is not None else 0
    print(f"{k:>4} {t_us:>10.2f} {w:>6} {dt:>8.2f} {gap:>9} {cmds.get(w, '??')}")
    prev_t = t_us
    prev_f = le_f[k]

# Find frame period = distance between consecutive VSYNCs
vsync_idx = [i for i, c in enumerate(true_cnt) if c == 3]
if len(vsync_idx) >= 2:
    gaps = np.diff([le_r[i] for i in vsync_idx])
    print(f"\n=== Frame period stats ({len(vsync_idx)} VSYNCs found) ===")
    print(f"  median frame period: {np.median(gaps)/SR*1e6:.1f}us = {SR/np.median(gaps):.1f} fps")
    print(f"  min/max: {gaps.min()/SR*1e6:.1f} / {gaps.max()/SR*1e6:.1f} us")

# Count LATCH per frame
if len(vsync_idx) >= 2:
    latch_per_frame = []
    for fi in range(len(vsync_idx)-1):
        s, e = vsync_idx[fi], vsync_idx[fi+1]
        cnt = sum(1 for k in range(s, e) if true_cnt[k] == 1)
        latch_per_frame.append(cnt)
    lpc = Counter(latch_per_frame)
    print(f"\n  LATCH count per frame: most common = {lpc.most_common(3)}")

# Look for ROW: channel 2, any sustained high pulse ~1.4us (12 DCLK) per frame?
print()
print(f"=== Check CH2 (presumed ROW) for ~12 DCLK high pulses ===")
ch2 = load_ch(zf, 2)
ch2_d = np.diff(ch2.astype(np.int8))
ch2_r = np.where(ch2_d == 1)[0]
ch2_f = np.where(ch2_d == -1)[0]
if len(ch2_f) and len(ch2_r) and ch2_f[0] < ch2_r[0]: ch2_f = ch2_f[1:]
n2 = min(len(ch2_r), len(ch2_f))
ch2_widths = []
for i in range(n2):
    c = np.searchsorted(dclk_rises, ch2_f[i]) - np.searchsorted(dclk_rises, ch2_r[i])
    ch2_widths.append(int(c))
wh = Counter(ch2_widths)
print(f"  total CH2 pulses: {n2}")
print(f"  width histogram (DCLK rises inside high):")
for w in sorted(wh.keys())[:15]:
    print(f"    {w:>3} DCLK: {wh[w]:>6}x")

# Look at CH2 around each VSYNC: is there a high pulse shortly after?
print()
print(f"=== CH2 activity in 5us after each of first 5 VSYNCs ===")
for vi in vsync_idx[:5]:
    vsync_fall = le_f[vi]
    # look 5us = 125 samples after
    win = ch2[vsync_fall:vsync_fall+200]
    high_samples = int(win.sum())
    rises_in_win = sum(1 for r in ch2_r if vsync_fall <= r < vsync_fall + 200)
    falls_in_win = sum(1 for f in ch2_f if vsync_fall <= f < vsync_fall + 200)
    print(f"  VSYNC @ {vsync_fall/SR*1e6:.1f}us: CH2 high_samples={high_samples}/200, rises={rises_in_win}, falls={falls_in_win}")
