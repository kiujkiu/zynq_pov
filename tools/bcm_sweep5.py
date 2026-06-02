"""BCM sweep v5 — proper baseline (CTRL=0+COLOR=0+ARM halt) + per-color via set_solid_color."""
import subprocess, time, os, cv2, numpy as np
out_dir = r"D:\claude_workspace\pov3d\zynq_pov"
xsdb = r"C:\Xilinx\Vitis\2024.2\bin\xsdb.bat"
tcl_off = r"D:\claude_workspace\pov3d\zynq_pov\tools\full_off.tcl"
tcl_set = r"D:\claude_workspace\pov3d\zynq_pov\tools\set_solid_color.tcl"

TUNIT = 8
EXP   = -7
vals  = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x3F]  # last = all planes on for reference

def xsdb_run(*args):
    return subprocess.run(["cmd.exe","/c", f"{xsdb} " + " ".join(map(str,args))],
                          capture_output=True, text=True, timeout=30)

def grab():
    cap = cv2.VideoCapture(0, cv2.CAP_ANY)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
    cap.set(cv2.CAP_PROP_AUTO_EXPOSURE, 0.25)
    cap.set(cv2.CAP_PROP_EXPOSURE, EXP)
    for _ in range(20): cap.read(); time.sleep(0.04)
    ok, frame = cap.read()
    cap.release()
    return frame if ok else None

# 1. baseline
print("Step 1: baseline (panel off)")
xsdb_run(tcl_off)
time.sleep(1.5)
base = grab()
cv2.imwrite(os.path.join(out_dir, "bcm5_base.jpg"), base)
print(f"  mean={base.mean():.1f}")

# 2. bright ref
print("Step 2: bright ref (COLOR=0x3F)")
xsdb_run(tcl_set, TUNIT, 0x3F3F3F)
time.sleep(1.5)
bright = grab()
cv2.imwrite(os.path.join(out_dir, "bcm5_bright.jpg"), bright)
print(f"  mean={bright.mean():.1f}")

# 3. build panel mask from R-channel diff
diff_r = bright[:,:,2].astype(np.int16) - base[:,:,2].astype(np.int16)
mask = diff_r > 30
n_panel = int(mask.sum())
print(f"  panel pixels = {n_panel}")
viz = bright.copy()
viz[mask] = [0, 255, 0]
cv2.imwrite(os.path.join(out_dir, "bcm5_mask.jpg"), viz)

# 4. per-color
print(f"\nStep 4: sweep TUNIT={TUNIT} EXP={EXP}")
results = []
for v in vals:
    rgb = (v << 16) | (v << 8) | v
    xsdb_run(tcl_set, TUNIT, rgb)
    time.sleep(1.2)
    frame = grab()
    if frame is None: print(f"FAIL v={v:02x}"); continue
    cv2.imwrite(os.path.join(out_dir, f"bcm5_v{v:02x}.jpg"), frame)
    diff = frame.astype(np.int16) - base.astype(np.int16)
    diff_panel = diff[mask]
    bgr = diff_panel.mean(axis=0)
    gray = diff_panel.mean()
    plane = v.bit_length() - 1
    results.append((v, plane, gray, bgr[2], bgr[1], bgr[0]))
    print(f"  v=0x{v:02x} p{plane} signal_gray={gray:5.1f} R={bgr[2]:5.1f} G={bgr[1]:5.1f} B={bgr[0]:5.1f}")

print()
print(f"{'val':>5} {'plane':>5} {'gray':>7} {'R':>6} {'R/p0':>7} {'expect':>7}")
if results:
    r0 = results[0][3]
    expect = [1, 2, 4, 8, 16, 32, 63]
    for i, (v, p, g, R, G, B) in enumerate(results):
        ratio = R / r0 if r0 > 0 else 0
        e = expect[i] if i < len(expect) else "?"
        print(f"0x{v:02x}  p{p}  {g:7.1f} {R:6.1f}  {ratio:6.2f}x  {e:>6}x")
