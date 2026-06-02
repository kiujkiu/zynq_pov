"""v28 A/B: BCM sweep with overlap_en=0 (serial) vs overlap_en=1 (overlap+OE_PRE).
   If overlap_en=1 gives same monotonic 1:2:4:8:16:32 ratio as serial, FM6124DJ
   supports overlap and OE_PRE delay fixes the timing.
   If overlap_en=1 still gives flat ratio, chip is plain FM6124 (no OE-fall cache),
   must stay serial.
"""
import subprocess, time, os, cv2, numpy as np
out_dir = r"D:\claude_workspace\pov3d\zynq_pov"
xsdb = r"C:\Xilinx\Vitis\2024.2\bin\xsdb.bat"
tcl  = r"D:\claude_workspace\pov3d\zynq_pov\tools\set_solid_v28.tcl"

TUNIT = 64
EXP   = -10
vals  = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x3F]

def run_xsdb(*args):
    return subprocess.run(["cmd.exe","/c", f"{xsdb} " + " ".join(map(str,args))],
                          capture_output=True, text=True, timeout=30)

def grab():
    cap = cv2.VideoCapture(0, cv2.CAP_ANY)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
    cap.set(cv2.CAP_PROP_AUTO_EXPOSURE, 0.25)
    cap.set(cv2.CAP_PROP_EXPOSURE, EXP)
    for _ in range(20): cap.read(); time.sleep(0.04)
    # average 5 frames to smooth rolling shutter
    acc = None; n = 0
    for _ in range(5):
        ok, f = cap.read()
        if ok:
            acc = f.astype(np.float32) if acc is None else acc + f.astype(np.float32)
            n += 1
        time.sleep(0.06)
    cap.release()
    return (acc / n).astype(np.uint8) if n else None

def sweep(mode_label, overlap_en):
    print(f"\n=== {mode_label} (overlap_en={overlap_en}) ===")
    # baseline: write COLOR=0, then bright ref COLOR=0x3F to build panel mask
    run_xsdb(tcl, TUNIT, 0, overlap_en)
    time.sleep(1.0)
    base = grab()
    run_xsdb(tcl, TUNIT, 0x3F3F3F, overlap_en)
    time.sleep(1.0)
    bright = grab()
    cv2.imwrite(os.path.join(out_dir, f"ab_{mode_label}_base.jpg"), base)
    cv2.imwrite(os.path.join(out_dir, f"ab_{mode_label}_bright.jpg"), bright)
    diff_r = bright[:,:,2].astype(np.int16) - base[:,:,2].astype(np.int16)
    mask = diff_r > 25
    n_panel = int(mask.sum())
    print(f"  base mean={base.mean():.1f} bright mean={bright.mean():.1f} panel_px={n_panel}")
    if n_panel < 500:
        print(f"  ERROR: panel mask too small, skipping {mode_label}")
        return None
    # sweep
    results = []
    for v in vals:
        rgb = (v << 16) | (v << 8) | v
        run_xsdb(tcl, TUNIT, rgb, overlap_en)
        time.sleep(1.0)
        frame = grab()
        if frame is None: continue
        cv2.imwrite(os.path.join(out_dir, f"ab_{mode_label}_v{v:02x}.jpg"), frame)
        diff = frame.astype(np.int16) - base.astype(np.int16)
        diff_panel = diff[mask]
        bgr = diff_panel.mean(axis=0)
        gray = diff_panel.mean()
        plane = v.bit_length() - 1
        results.append((v, plane, gray, bgr[2], bgr[1], bgr[0]))
        print(f"  v=0x{v:02x} p{plane} gray={gray:6.1f} R={bgr[2]:6.1f}")
    return results

print(f"v28 BCM A/B test  TUNIT={TUNIT} EXP={EXP}")
res_serial  = sweep("serial",  0)
res_overlap = sweep("overlap", 1)

def show(label, results):
    if not results: print(f"\n{label}: NO DATA"); return
    print(f"\n{label}:")
    print(f"  {'val':>5} {'plane':>5} {'R':>7} {'R/p0':>7} {'expect':>7}")
    r0 = results[0][3]
    expect = [1, 2, 4, 8, 16, 32, 63]
    for i, (v, p, g, R, G, B) in enumerate(results):
        ratio = R / r0 if r0 > 0 else 0
        e = expect[i] if i < len(expect) else "?"
        print(f"  0x{v:02x}  p{p}  {R:7.1f}  {ratio:6.2f}x  {e:>6}x")

show("SERIAL", res_serial)
show("OVERLAP+OE_PRE", res_overlap)
print()
print("Verdict: if OVERLAP ratios are also monotonic 1,2,4,8,16,32, then FM6124DJ overlap works.")
print("         if OVERLAP ratios are flat (~1.0x all planes), chip is plain FM6124, stay serial.")
