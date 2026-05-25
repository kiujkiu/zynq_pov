"""Parse DSView .dsl capture and analyze ICND1069 panel signals."""
import zipfile, sys, numpy as np

DSL = sys.argv[1] if len(sys.argv) > 1 else r'C:\Users\kiujkiu\Desktop\DSLogic U2Pro16-la-260522-162808.dsl'
SR  = 25_000_000  # 25 MHz (verify in session)

# 2026-05-22 PL IP test:
LABELS = {0:'DCLK', 1:'LE', 2:'?', 3:'?', 4:'?', 5:'?', 6:'?', 7:'?'}

zf = zipfile.ZipFile(DSL)

def load_channel(ch):
    parts = []
    for blk in (0, 1, 2, 3):
        name = f'L-{ch}/{blk}'
        try:
            parts.append(zf.read(name))
        except KeyError:
            break
    if not parts:
        return None
    raw = b''.join(parts)
    arr = np.frombuffer(raw, dtype=np.uint8)
    bits = np.unpackbits(arr, bitorder='little')
    return bits

from collections import Counter

# 16 channels classification with labels
print(f"{'CH':>3} {'label':<7} {'edges':>9} {'hi%':>6} {'minTw_us':>10} {'maxTw_us':>10}")
chan_bits = {}
for ch in range(16):
    bits = load_channel(ch)
    if bits is None:
        chan_bits[ch] = None
        continue
    chan_bits[ch] = bits
    edges = int(np.abs(np.diff(bits.astype(np.int8))).sum())
    hi_pct = 100 * bits.mean()
    if edges > 1:
        diff = np.diff(bits.astype(np.int8))
        edge_idx = np.where(diff != 0)[0]
        intervals = np.diff(edge_idx)
        min_us = intervals.min() / SR * 1e6
        max_us = intervals.max() / SR * 1e6
    else:
        min_us = max_us = 0
    label = LABELS.get(ch, '')
    print(f"{ch:>3} {label:<7} {edges:>9} {hi_pct:>6.2f} {min_us:>10.3f} {max_us:>10.3f}")

print()
print("=== Pulse width histograms ===")
for ch in range(8):
    bits = chan_bits[ch]
    if bits is None:
        continue
    diff = np.diff(bits.astype(np.int8))
    edges = np.where(diff != 0)[0]
    if len(edges) < 2:
        continue
    intervals = np.diff(edges).tolist()
    cnt = Counter(intervals)
    top = cnt.most_common(6)
    label = LABELS.get(ch, '')
    print(f"CH{ch} ({label}): {len(edges)} edges")
    for v, c in top:
        print(f"   {v:>5} samp ({v/SR*1e6:>7.2f}us): {c:>6}x")

# Focus on LATIN pulses: measure LE high pulse widths to decode ICND1069 commands.
# ICND1069 V1.2: command encoded by # of DCLK cycles LE is held high.
print()
print("=== LE (CH1 LATIN) high-pulse widths in DCLK periods ===")
bits = chan_bits[1]
diff = np.diff(bits.astype(np.int8))
le_rise = np.where(diff == 1)[0]   # LE 0->1
le_fall = np.where(diff == -1)[0]  # LE 1->0
# align
if le_fall[0] < le_rise[0]:
    le_fall = le_fall[1:]
n = min(len(le_rise), len(le_fall))
le_high_samples = le_fall[:n] - le_rise[:n]

# DCLK is 1MHz-ish → period ~1us = 20 samples. Compute LE width / DCLK period.
dclk_bits = chan_bits[0]
ddiff = np.diff(dclk_bits.astype(np.int8))
dclk_rise = np.where(ddiff == 1)[0]
# avg DCLK period
dclk_periods = np.diff(dclk_rise)
dclk_period_samples = float(np.median(dclk_periods))
print(f"DCLK median period: {dclk_period_samples} samples = {dclk_period_samples/SR*1e6:.3f}us = {SR/dclk_period_samples/1e3:.1f} kHz")

# Count how many DCLK periods each LE pulse covers
le_dclk_widths = (le_high_samples / dclk_period_samples).round().astype(int)
cnt = Counter(le_dclk_widths.tolist())
print(f"LE pulse widths (DCLK periods): n={len(le_high_samples)}")
for w in sorted(cnt.keys()):
    c = cnt[w]
    cmd = {1:'DATA_LATCH', 3:'VSYNC', 5:'WR_CFG', 7:'RD_CFG', 11:'EN_OP', 12:'DIS_OP', 14:'PRE_ACT'}.get(w, '')
    print(f"   {w:>4} DCLK: {c:>6}x   {cmd}")

# Where in time do the 5-DCLK LE pulses occur?
mask5 = (le_dclk_widths == 5)
le5_times = le_rise[:len(mask5)][mask5]
print()
print(f"LE=5 pulse timing distribution (sample indices, total samples={20_000_768}):")
if len(le5_times):
    buckets = np.histogram(le5_times, bins=20, range=(0, 20_000_768))[0]
    print(f"   per 50ms bucket: {' '.join(str(b) for b in buckets)}")
    print(f"   first 5 LE=5 at samples: {le5_times[:5].tolist()}")
    print(f"   first 5 in ms: {(le5_times[:5] / SR * 1000).round(2).tolist()}")
    # Detect bursts
    gaps = np.diff(le5_times)
    print(f"   inter-pulse gap median: {int(np.median(gaps))} samples ({np.median(gaps)/SR*1000:.2f}ms)")
    print(f"   inter-pulse gap min: {int(gaps.min())} samples ({gaps.min()/SR*1000:.3f}ms)")
    print(f"   inter-pulse gap max: {int(gaps.max())} samples ({gaps.max()/SR*1000:.2f}ms)")

# Also dump raw LE high pulse widths in samples, max value
print()
print(f"LE high pulse max samples: {le_high_samples.max()}  ({le_high_samples.max()/SR*1e6:.2f}us = {le_high_samples.max()/dclk_period_samples:.1f} DCLK)")
print(f"LE high pulse 95%ile: {int(np.percentile(le_high_samples, 95))} samples")
print(f"LE high pulse 99%ile: {int(np.percentile(le_high_samples, 99))} samples")
print(f"LE high pulse 99.9%ile: {int(np.percentile(le_high_samples, 99.9))} samples")
print(f"# LE pulses > 100 samples: {(le_high_samples > 100).sum()}")
print(f"# LE pulses > 200 samples: {(le_high_samples > 200).sum()}")
print(f"# LE pulses > 300 samples: {(le_high_samples > 300).sum()}")
print(f"# LE pulses > 400 samples: {(le_high_samples > 400).sum()}")

# Look around the first LE=5 cluster — should be a PRE_ACT right BEFORE it
first_le5 = le5_times[0] if len(le5_times) else None
print()
print(f"=== Context: 200us around first LE=5 at sample {first_le5} ===")
if first_le5:
    start = max(0, first_le5 - 4000)  # 4000 samp = 200us back
    stop = min(20_000_768, first_le5 + 1000)
    le_seg = chan_bits[1][start:stop]
    dclk_seg = chan_bits[0][start:stop]
    # Find LE rising/falling in this window
    le_d = np.diff(le_seg.astype(np.int8))
    rises = np.where(le_d == 1)[0]
    falls = np.where(le_d == -1)[0]
    # Pair them: each rise → next fall
    n = min(len(rises), len(falls))
    if len(falls) and len(rises) and falls[0] < rises[0]:
        falls = falls[1:]
        n = min(len(rises), len(falls))
    print(f"  found {n} LE pulses in window [{start},{stop}]")
    for i in range(min(n, 20)):
        w_samp = falls[i] - rises[i]
        w_dclk = w_samp / dclk_period_samples
        t_us = (start + rises[i]) / SR * 1e6
        print(f"  LE rise @ {start+rises[i]:>10} (t={t_us:.3f}us), high {w_samp:>4} samp = {w_dclk:.2f} DCLK")

# Count actual DCLK rising edges INSIDE EVERY LE high window
print()
print(f"=== DCLK rising edges inside ALL LE high windows (true command width) ===")
dclk_bits3 = chan_bits[0]
ddiff3 = np.diff(dclk_bits3.astype(np.int8))
dclk_rise_all = np.where(ddiff3 == 1)[0]

le_d3 = np.diff(chan_bits[1].astype(np.int8))
le_r3 = np.where(le_d3 == 1)[0]
le_f3 = np.where(le_d3 == -1)[0]
if len(le_f3) and len(le_r3) and le_f3[0] < le_r3[0]:
    le_f3 = le_f3[1:]
n3 = min(len(le_r3), len(le_f3))

# Use searchsorted for fast counting
from collections import Counter
true_dclk_widths = []
for j in range(n3):
    s = le_r3[j]; e = le_f3[j]
    cnt_in = np.searchsorted(dclk_rise_all, e) - np.searchsorted(dclk_rise_all, s)
    true_dclk_widths.append(int(cnt_in))

c = Counter(true_dclk_widths)
print(f"  total LE pulses: {len(true_dclk_widths)}")
for w in sorted(c.keys()):
    cmd = {1:'DATA_LATCH', 3:'VSYNC', 5:'WR_CFG', 7:'RD_CFG', 11:'EN_OP', 12:'DIS_OP', 14:'PRE_ACT'}.get(w, '???')
    print(f"  {w:>3} DCLK rises inside LE high: {c[w]:>7}  {cmd}")

# For each RD_CFG (LE=7) pulse, check data lines for SDO response.
print()
print(f"=== SDO response check: data lines AFTER each RD_CFG (LE=7) ===")
# Find LE pulses where DCLK rising count inside is exactly 7
rd_cfg_idx = [j for j in range(n3) if true_dclk_widths[j] == 7]
print(f"  found {len(rd_cfg_idx)} RD_CFG pulses")

# For each RD_CFG: look at 400us window after LE falls (~192 DCLK at 645kHz = ~300us)
WINDOW_US = 400
WIN_SAMP = int(WINDOW_US * 1e-6 * SR)  # 8000 samples

for ch in [3, 4, 5]:
    bits = chan_bits[ch]
    if bits is None:
        continue
    label = LABELS.get(ch, f'CH{ch}')
    total_edges_in_resp = 0
    pulses_with_edges = 0
    for j in rd_cfg_idx[:10]:
        le_end = le_f3[j]
        win_end = min(le_end + WIN_SAMP, len(bits))
        seg = bits[le_end:win_end]
        edges = int(np.abs(np.diff(seg.astype(np.int8))).sum())
        total_edges_in_resp += edges
        if edges > 0:
            pulses_with_edges += 1
    avg = total_edges_in_resp / max(1, min(10, len(rd_cfg_idx)))
    print(f"  CH{ch} ({label}): avg {avg:.1f} edges in 400us after RD_CFG, "
          f"{pulses_with_edges}/{min(10,len(rd_cfg_idx))} responses had any edge")

# Sample dump: for first RD_CFG, show data line states at DCLK rising edges in response window
if rd_cfg_idx:
    j = rd_cfg_idx[0]
    le_end = le_f3[j]
    win_end = min(le_end + WIN_SAMP, len(chan_bits[0]))
    # find DCLK rising edges in window
    dclk_in_win = dclk_rise_all[(dclk_rise_all >= le_end) & (dclk_rise_all < win_end)]
    print(f"\n  Sample dump first RD_CFG @ t={le_end/SR*1000:.2f}ms — first 30 DCLK rises after RD_CFG ends:")
    print(f"  DCLK# | t_us  | R1 G1 B1 LE_state")
    for k, dr in enumerate(dclk_in_win[:30]):
        t_us = (dr - le_end) / SR * 1e6
        r1 = chan_bits[3][dr]; g1 = chan_bits[4][dr]; b1 = chan_bits[5][dr]
        le = chan_bits[1][dr]
        print(f"  {k:>4}  | {t_us:>5.2f} |  {r1}  {g1}  {b1}   {le}")

# Old wide-window analysis (kept)
print()
print(f"=== Wide LE pulses (>300 samples) — true DCLK count ===")
dclk_bits2 = chan_bits[0]
ddiff2 = np.diff(dclk_bits2.astype(np.int8))
dclk_rise_idx = np.where(ddiff2 == 1)[0]

le_d2 = np.diff(chan_bits[1].astype(np.int8))
le_r2 = np.where(le_d2 == 1)[0]
le_f2 = np.where(le_d2 == -1)[0]
if len(le_f2) and len(le_r2) and le_f2[0] < le_r2[0]:
    le_f2 = le_f2[1:]
n2 = min(len(le_r2), len(le_f2))
widths2 = le_f2[:n2] - le_r2[:n2]

# For pulses > 300 samples, count DCLK rises within [le_r, le_f]
big_idx = np.where(widths2 > 300)[0]
print(f"  total wide LE pulses (>300 samp): {len(big_idx)}")
for j in big_idx[:15]:
    start = le_r2[j]; stop = le_f2[j]
    n_dclk = ((dclk_rise_idx >= start) & (dclk_rise_idx < stop)).sum()
    t_us = start / SR * 1e6
    print(f"  LE high @ t={t_us:>10.2f}us  width={widths2[j]} samp ({widths2[j]/SR*1e6:.1f}us)  -> {n_dclk} DCLK rises inside")

# Same: 1 ms BEFORE first LE=5 — looking for PRE_ACT specifically
print()
print(f"=== Wide-window LE pulses in first 200ms of capture (looking for any >8 DCLK) ===")
le_bits = chan_bits[1]
le_d = np.diff(le_bits.astype(np.int8))
le_r = np.where(le_d == 1)[0]
le_f = np.where(le_d == -1)[0]
if len(le_f) and len(le_r) and le_f[0] < le_r[0]:
    le_f = le_f[1:]
n = min(len(le_r), len(le_f))
widths = le_f[:n] - le_r[:n]
wide_idx = np.where(widths > 8 * dclk_period_samples)[0]
print(f"  total LE pulses > 8 DCLK: {len(wide_idx)}")
for j in wide_idx[:20]:
    t_us = le_r[j] / SR * 1e6
    w_dclk = widths[j] / dclk_period_samples
    print(f"  @ {le_r[j]:>10} (t={t_us:.3f}us): {widths[j]} samp = {w_dclk:.2f} DCLK")
