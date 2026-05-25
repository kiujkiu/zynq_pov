"""Dump the FIRST init sequence from .dsl: list all LE pulses with widths in DCLK rises, plus surrounding context."""
import zipfile, sys, numpy as np
from collections import Counter

DSL = sys.argv[1] if len(sys.argv) > 1 else r'C:\Users\kiujkiu\Desktop\DSLogic U2Pro16-la-260522-164055.dsl'
SR = 25_000_000

def load_ch(zf, ch):
    parts = []
    for blk in range(4):
        try:
            parts.append(zf.read(f'L-{ch}/{blk}'))
        except KeyError:
            break
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

# Find first PRE_ACT (14-DCLK inside): start of first complete frame
first_pre = next((i for i, c in enumerate(true_cnt) if c == 14), None)
if first_pre is None:
    print("ERROR no PRE_ACT found")
    sys.exit(1)

print(f"First PRE_ACT @ LE pulse index {first_pre}, t={le_r[first_pre]/SR*1e6:.2f}us")
print()
print("=== Init sequence dump (PRE_ACT + 25 following LE pulses) ===")
print(f"{'idx':>4} {'t_us':>10} {'width_DCLK':>10} {'dt_to_prev_us':>13} {'gap_DCLK_since_prev_fall':>25} {'cmd':<12}")
cmds = {1:'LATCH', 3:'VSYNC', 5:'WR_CFG', 7:'RD_CFG', 11:'EN_OP', 12:'DIS_OP', 14:'PRE_ACT'}
prev_fall = None
prev_t = None
for k in range(first_pre, min(first_pre + 25, n)):
    t_us = le_r[k] / SR * 1e6
    w = true_cnt[k]
    cmd = cmds.get(w, '???')
    if prev_t is None:
        dt = 0
        gap_dclk = 0
    else:
        dt = t_us - prev_t
        # count DCLK rises between prev_fall and current rise
        gap_dclk = np.searchsorted(dclk_rises, le_r[k]) - np.searchsorted(dclk_rises, prev_fall)
    print(f"{k:>4} {t_us:>10.2f} {w:>10} {dt:>13.2f} {gap_dclk:>25} {cmd}")
    prev_fall = le_f[k]
    prev_t = t_us

# Also: time between consecutive WR_CFG within init = should be ~12 chip shifts = 192 DCLK
# Setup completes when we hit EN_OP. Then VSYNC. Then LATCH burst starts.
print()
print("=== Time between PRE_ACT and EN_OP (= full setup duration) ===")
en_op_k = next((k for k in range(first_pre, n) if true_cnt[k] == 11), None)
if en_op_k:
    span_us = (le_r[en_op_k] - le_r[first_pre]) / SR * 1e6
    n_wr = sum(1 for k in range(first_pre, en_op_k) if true_cnt[k] == 5)
    print(f"  PRE_ACT @ {le_r[first_pre]/SR*1e6:.2f}us -> EN_OP @ {le_r[en_op_k]/SR*1e6:.2f}us")
    print(f"  span = {span_us:.2f}us, contains {n_wr} WR_CFG")
    print(f"  avg WR_CFG spacing = {span_us/(n_wr+1):.2f}us (expected ~23us @ 12 chip × 16 DCLK / 8.33MHz)")

# After EN_OP: how long until next LATCH burst (LE=1)?
if en_op_k:
    latch_k = next((k for k in range(en_op_k+1, n) if true_cnt[k] == 1), None)
    if latch_k:
        gap_us = (le_r[latch_k] - le_f[en_op_k]) / SR * 1e6
        gap_dclk_n = np.searchsorted(dclk_rises, le_r[latch_k]) - np.searchsorted(dclk_rises, le_f[en_op_k])
        # Are there other LE pulses between EN_OP and first LATCH?
        between = [(k, true_cnt[k]) for k in range(en_op_k+1, latch_k)]
        print()
        print(f"=== EN_OP -> first LATCH ===")
        print(f"  gap = {gap_us:.2f}us = {gap_dclk_n} DCLK rises in between")
        print(f"  intermediate LE pulses: {between}")
