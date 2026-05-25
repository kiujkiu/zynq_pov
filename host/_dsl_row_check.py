"""Check exact ROW pulse position relative to VSYNC + LATCH burst."""
import zipfile, sys, numpy as np
DSL = sys.argv[1]
SR = 25_000_000
def load_ch(zf, ch):
    parts = []
    for blk in range(4):
        try: parts.append(zf.read(f'L-{ch}/{blk}'))
        except KeyError: break
    return np.unpackbits(np.frombuffer(b''.join(parts), dtype=np.uint8), bitorder='little') if parts else None
zf = zipfile.ZipFile(DSL)
dclk = load_ch(zf, 0); le = load_ch(zf, 1); row = load_ch(zf, 2)
dclk_r = np.where(np.diff(dclk.astype(np.int8))==1)[0]
le_d = np.diff(le.astype(np.int8))
le_r = np.where(le_d==1)[0]; le_f = np.where(le_d==-1)[0]
if le_f[0]<le_r[0]: le_f = le_f[1:]
n = min(len(le_r), len(le_f))
true_cnt = [int(np.searchsorted(dclk_r, le_f[i]) - np.searchsorted(dclk_r, le_r[i])) for i in range(n)]
row_d = np.diff(row.astype(np.int8))
row_r = np.where(row_d==1)[0]; row_f = np.where(row_d==-1)[0]
if row_f[0]<row_r[0]: row_f = row_f[1:]
# Filter ROW pulses to only "real" ones (width > 5 DCLK rises inside)
real_row = []
for i in range(min(len(row_r), len(row_f))):
    c = np.searchsorted(dclk_r, row_f[i]) - np.searchsorted(dclk_r, row_r[i])
    if c >= 5:
        real_row.append((row_r[i], row_f[i], int(c)))

# For first 3 frames: print VSYNC, ROW, first 3 LATCH timestamps in DCLK rises
vsync_idx = [i for i,c in enumerate(true_cnt) if c == 3]
latch_idx = [i for i,c in enumerate(true_cnt) if c == 1]
print(f"Found {len(vsync_idx)} VSYNCs, {len(real_row)} real ROW pulses (>=5 DCLK), {len(latch_idx)} LATCH")
print()
for f in range(min(3, len(vsync_idx)-1)):
    vs = le_r[vsync_idx[f]]; vf = le_f[vsync_idx[f]]
    next_vs = le_r[vsync_idx[f+1]]
    # Find ROW pulse in this frame
    rows_in = [r for r in real_row if vs <= r[0] < next_vs]
    # Find first LATCH in this frame
    latches_in = [le_r[k] for k in latch_idx if vs <= le_r[k] < next_vs]
    print(f"Frame {f}: VSYNC rise@{vs} t={vs/SR*1e6:.2f}us")
    print(f"  VSYNC fall@{vf} t={vf/SR*1e6:.2f}us (width={true_cnt[vsync_idx[f]]} DCLK)")
    for (r, fall, w) in rows_in:
        dt_from_vs_fall = (r - vf) / SR * 1e6
        n_dclk_between = np.searchsorted(dclk_r, r) - np.searchsorted(dclk_r, vf)
        print(f"  ROW rise@{r} t={r/SR*1e6:.2f}us  (+{dt_from_vs_fall:.2f}us from VSYNC fall, {n_dclk_between} DCLK between)")
        print(f"  ROW fall@{fall} t={fall/SR*1e6:.2f}us  (width = {w} DCLK rises inside)")
        if latches_in:
            first_latch = latches_in[0]
            dt = (first_latch - fall) / SR * 1e6
            n_d = np.searchsorted(dclk_r, first_latch) - np.searchsorted(dclk_r, fall)
            print(f"  First LATCH after ROW fall: +{dt:.2f}us, {n_d} DCLK gap")
    print(f"  Total LATCH in frame: {len(latches_in)}")
    print()
