"""Show pulse widths for each channel to identify ICND3019 BIN (3019 DCLK) and AIN."""
import zipfile, sys, numpy as np
from collections import Counter
DSL = sys.argv[1]
SR = 25_000_000
def load_ch(zf, ch):
    parts = []
    for blk in range(4):
        try: parts.append(zf.read(f'L-{ch}/{blk}'))
        except KeyError: break
    return np.unpackbits(np.frombuffer(b''.join(parts), dtype=np.uint8), bitorder='little') if parts else None

zf = zipfile.ZipFile(DSL)
for ch in range(8):
    bits = load_ch(zf, ch)
    if bits is None or bits.sum() == 0:
        print(f"CH{ch}: empty"); continue
    d = np.diff(bits.astype(np.int8))
    r = np.where(d == 1)[0]
    f = np.where(d == -1)[0]
    if len(r) == 0 or len(f) == 0:
        print(f"CH{ch}: no edges"); continue
    if f[0] < r[0]: f = f[1:]
    n = min(len(r), len(f))
    high_widths = f[:n] - r[:n]  # samples
    low_widths = r[1:min(n+1, len(r))] - f[:min(n, len(r)-1)]
    print(f"\nCH{ch}: total pulses={n}, hi%={100*bits.mean():.2f}")
    hi_top = Counter(high_widths.tolist()).most_common(5)
    print(f"  HIGH widths (top 5): {[(w, c, f'{w/SR*1e9:.0f}ns') for w,c in hi_top]}")
    lo_top = Counter(low_widths.tolist()).most_common(5)
    print(f"  LOW widths (top 5): {[(w, c, f'{w/SR*1e9:.0f}ns') for w,c in lo_top]}")
    # First 5 rises and their high widths
    print(f"  first 5 rises: {[(r[i], f'{(f[i]-r[i])/SR*1e9:.0f}ns hi') for i in range(min(5,n))]}")
