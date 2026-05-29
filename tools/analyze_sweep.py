"""Analyze sweep capture → build LUT (two-phase).

Phase 1 (cal_*.jpg)  : (chain, chip, bit) → [(cx_pct, cy_pct, area), ...]
Phase 2 (cal2_*.jpg) : row_iter → (cx_pct, cy_pct) for the fixed P2 tuple

Output:
  calib_lut.json    – phase 1 (key = "C_KK_BB")
  calib_lut.csv     – phase 1 flat (one blob per row)
  calib_p2_lut.json – phase 2 (key = "R")
  calib_p2_lut.csv  – phase 2 flat

Run:
    python analyze_sweep.py [in_dir] [out_dir]
"""
import sys, os, json, glob, re
import numpy as np
from PIL import Image

IN_DIR  = sys.argv[1] if len(sys.argv) > 1 else r"D:\workspace\zynq_pov\tools\calib_out"
OUT_DIR = sys.argv[2] if len(sys.argv) > 2 else IN_DIR

# Panel ROI tightened (per cal_1011 analysis: panel is x[28-78%], y[5-70%]).
# Excludes desk/cable reflections + external USB hub LEDs that contaminated v1 LUT.
ROI_X0, ROI_X1 = 0.28, 0.78
ROI_Y0, ROI_Y1 = 0.05, 0.70

# Per-chain-color threshold (chan = chain % 3 → 0:R 1:G 2:B).
# Green LEDs proved much dimmer in this capture set — lowered min for greens.
CHAN_MIN_BY = {0: 100, 1: 70, 2: 100}   # R, G, B
CHAN_OVER   = 25
MIN_AREA    = 4
SUBSAMPLE   = 2

P1_RE = re.compile(r"^cal_(\d+)_C(\d+)_K(\d+)_B(\d+)\.jpg$")
P2_RE = re.compile(r"^cal2_(\d+)_C(\d+)_K(\d+)_B(\d+)_R(\d+)\.jpg$")

def flood_label(mask):
    """Simple 4-connected label via BFS, returns list of (cx, cy, area)."""
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    blobs = []
    from collections import deque
    for y in range(h):
        for x in range(w):
            if mask[y, x] and not seen[y, x]:
                q = deque([(y, x)])
                seen[y, x] = True
                sx = sy = n = 0
                while q:
                    yy, xx = q.popleft()
                    sx += xx; sy += yy; n += 1
                    for dy, dx in ((-1,0),(1,0),(0,-1),(0,1)):
                        ny, nx = yy+dy, xx+dx
                        if 0<=ny<h and 0<=nx<w and mask[ny,nx] and not seen[ny,nx]:
                            seen[ny,nx] = True
                            q.append((ny, nx))
                if n >= MIN_AREA:
                    blobs.append((sx/n, sy/n, n))
    return blobs

def analyze_one(path, chain):
    """chain % 3 picks dominant chan: 0=R, 1=G, 2=B."""
    im = np.array(Image.open(path).convert("RGB"))
    H, W, _ = im.shape
    x0, x1 = int(W*ROI_X0), int(W*ROI_X1)
    y0, y1 = int(H*ROI_Y0), int(H*ROI_Y1)
    sub = im[y0:y1:SUBSAMPLE, x0:x1:SUBSAMPLE, :]
    ch = chain % 3
    dom = sub[:,:,ch].astype(np.int16)
    o1  = sub[:,:,(ch+1)%3].astype(np.int16)
    o2  = sub[:,:,(ch+2)%3].astype(np.int16)
    chan_min = CHAN_MIN_BY[ch]
    mask = (dom > chan_min) & ((dom - o1) > CHAN_OVER) & ((dom - o2) > CHAN_OVER)
    blobs_sub = flood_label(mask)
    # back to original pixel coords, then to percent of ROI
    roi_w, roi_h = (x1-x0), (y1-y0)
    out = []
    for cx_s, cy_s, area in blobs_sub:
        cx_px = cx_s * SUBSAMPLE
        cy_px = cy_s * SUBSAMPLE
        out.append({
            "cx_pct": round(cx_px / roi_w * 100, 2),
            "cy_pct": round(cy_px / roi_h * 100, 2),
            "area":   int(area * SUBSAMPLE * SUBSAMPLE),
        })
    out.sort(key=lambda d: -d["area"])  # largest first
    return out

def run_phase1():
    files = sorted(f for f in glob.glob(os.path.join(IN_DIR, "cal_*.jpg"))
                   if P1_RE.search(os.path.basename(f)))
    print(f"\n=== Phase 1: {len(files)} cal_*.jpg files ===")
    if not files:
        return
    lut = {}
    csv_rows = ["idx,chain,chip,bit,blob_n,cx_pct,cy_pct,area"]
    for i, fp in enumerate(files):
        m = P1_RE.search(os.path.basename(fp))
        idx, c, k, b = int(m[1]), int(m[2]), int(m[3]), int(m[4])
        blobs = analyze_one(fp, c)
        key = f"{c}_{k:02d}_{b:02d}"
        lut[key] = {"idx": idx, "chain": c, "chip": k, "bit": b, "blobs": blobs}
        for n, bl in enumerate(blobs):
            csv_rows.append(f"{idx},{c},{k},{b},{n},{bl['cx_pct']},{bl['cy_pct']},{bl['area']}")
        if (i+1) % 100 == 0 or i < 3:
            print(f"  [{i+1}/{len(files)}] C{c} K{k:02d} B{b:02d}  blobs={len(blobs)}")

    j_path = os.path.join(OUT_DIR, "calib_lut.json")
    c_path = os.path.join(OUT_DIR, "calib_lut.csv")
    with open(j_path, "w") as f:
        json.dump(lut, f, indent=1)
    with open(c_path, "w") as f:
        f.write("\n".join(csv_rows))
    n_with = sum(1 for v in lut.values() if v["blobs"])
    avg    = sum(len(v["blobs"]) for v in lut.values()) / max(1, len(lut))
    print(f"P1 LUT  : {n_with}/{len(lut)} tuples have ≥1 blob, avg={avg:.2f}")
    print(f"  → {j_path}")

def run_phase2():
    files = sorted(f for f in glob.glob(os.path.join(IN_DIR, "cal2_*.jpg"))
                   if P2_RE.search(os.path.basename(f)))
    print(f"\n=== Phase 2: {len(files)} cal2_*.jpg files ===")
    if not files:
        return
    lut = {}
    csv_rows = ["idx,chain,chip,bit,row_iter,blob_n,cx_pct,cy_pct,area"]
    for i, fp in enumerate(files):
        m = P2_RE.search(os.path.basename(fp))
        idx, c, k, b, r = (int(m[i]) for i in range(1, 6))
        blobs = analyze_one(fp, c)
        # P2 is dim (1/384 duty) — keep only the brightest blob if any
        if blobs:
            best = max(blobs, key=lambda d: d["area"])
            lut[str(r)] = {"row_iter": r, "cx_pct": best["cx_pct"],
                           "cy_pct": best["cy_pct"], "area": best["area"]}
        for n, bl in enumerate(blobs):
            csv_rows.append(f"{idx},{c},{k},{b},{r},{n},{bl['cx_pct']},{bl['cy_pct']},{bl['area']}")
        if (i+1) % 50 == 0 or i < 3:
            print(f"  [{i+1}/{len(files)}] R={r:03d}  blobs={len(blobs)}")

    j_path = os.path.join(OUT_DIR, "calib_p2_lut.json")
    c_path = os.path.join(OUT_DIR, "calib_p2_lut.csv")
    with open(j_path, "w") as f:
        json.dump(lut, f, indent=1)
    with open(c_path, "w") as f:
        f.write("\n".join(csv_rows))
    print(f"P2 LUT  : {len(lut)}/{len(files)} row_iter mapped")
    if lut:
        ys = sorted((v["row_iter"], v["cy_pct"]) for v in lut.values())
        print(f"  y range: [{min(y for _,y in ys):.1f}%, {max(y for _,y in ys):.1f}%]")
        print(f"  → {j_path}")

if __name__ == "__main__":
    run_phase1()
    run_phase2()
