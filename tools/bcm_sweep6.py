"""BCM sweep v6: TUNIT=128 (plane 0 = 1.7µs >> LED rise time)."""
import subprocess, time, os, cv2, numpy as np
out_dir = r"D:\claude_workspace\pov3d\zynq_pov"
xsdb = r"C:\Xilinx\Vitis\2024.2\bin\xsdb.bat"
tcl_set = r"D:\claude_workspace\pov3d\zynq_pov\tools\set_solid_color.tcl"

TUNIT = 128
EXP   = -9   # short to keep plane 5 below saturation
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
    # average multiple frames to smooth rolling shutter aliasing
    acc = None; n = 0
    for _ in range(30): cap.read(); time.sleep(0.04)
    for _ in range(8):
        ok, f = cap.read()
        if ok:
            if acc is None: acc = f.astype(np.float32)
            else: acc += f.astype(np.float32)
            n += 1
        time.sleep(0.07)
    cap.release()
    return (acc / n).astype(np.uint8) if n > 0 else None

# 1. baseline (CTRL=0, COLOR=0)
print("Step 1: baseline (CTRL=0 + COLOR=0, ARM running)")
# write CTRL=0 first (don't halt ARM!), then COLOR=0
r = subprocess.run(["cmd.exe","/c",
   f'{xsdb} -eval "connect; after 200; targets -set -nocase -filter {{name =~ \\"APU*\\"}}; configparams force-mem-access 1; mwr 0x40020004 0; mwr 0x40020010 0; mwr 0x40020000 0; after 500; puts CTRL=[mrd 0x40020000]; puts STATUS=[mrd 0x4002000C]; exit"'],
   capture_output=True, text=True, timeout=30)
print("  ", "\n  ".join(r.stdout.strip().splitlines()[-5:]))
time.sleep(1.0)
base = grab()
cv2.imwrite(os.path.join(out_dir, "bcm6_base.jpg"), base)
print(f"  base mean={base.mean():.1f}")

# 2. bright ref
print("Step 2: bright (COLOR=0x3F)")
run_xsdb(tcl_set, TUNIT, 0x3F3F3F)
time.sleep(1.0)
bright = grab()
cv2.imwrite(os.path.join(out_dir, "bcm6_bright.jpg"), bright)
print(f"  bright mean={bright.mean():.1f}")

# 3. mask
diff_r = bright[:,:,2].astype(np.int16) - base[:,:,2].astype(np.int16)
mask = diff_r > 20
n_panel = int(mask.sum())
print(f"  panel pixels = {n_panel}")
viz = bright.copy()
viz[mask] = [0, 255, 0]
cv2.imwrite(os.path.join(out_dir, "bcm6_mask.jpg"), viz)

if n_panel < 100:
    print("ERR: panel mask too small, abort")
    raise SystemExit(1)

# 4. sweep
print(f"\nStep 4: sweep TUNIT={TUNIT} EXP={EXP}")
results = []
for v in vals:
    rgb = (v << 16) | (v << 8) | v
    run_xsdb(tcl_set, TUNIT, rgb)
    time.sleep(1.0)
    frame = grab()
    if frame is None: print(f"FAIL v={v:02x}"); continue
    cv2.imwrite(os.path.join(out_dir, f"bcm6_v{v:02x}.jpg"), frame)
    diff = frame.astype(np.int16) - base.astype(np.int16)
    diff_panel = diff[mask]
    bgr = diff_panel.mean(axis=0)
    gray = diff_panel.mean()
    plane = v.bit_length() - 1
    results.append((v, plane, gray, bgr[2], bgr[1], bgr[0]))
    print(f"  v=0x{v:02x} p{plane} gray={gray:6.2f} R={bgr[2]:6.2f} G={bgr[1]:6.2f} B={bgr[0]:6.2f}")

print()
print(f"{'val':>5} {'plane':>5} {'gray':>7} {'R':>7} {'R/p0':>7} {'expect':>7}")
if results:
    r0 = results[0][3]
    expect = [1, 2, 4, 8, 16, 32, 63]
    for i, (v, p, g, R, G, B) in enumerate(results):
        ratio = R / r0 if r0 > 0 else 0
        e = expect[i] if i < len(expect) else "?"
        print(f"0x{v:02x}  p{p}  {g:7.2f} {R:7.2f}  {ratio:6.2f}x  {e:>6}x")
