"""BCM sweep v4 — subtract panel-off baseline, mask to panel pixels only."""
import subprocess, time, os, cv2, numpy as np
out_dir = r"D:\claude_workspace\pov3d\zynq_pov"
xsdb = r"C:\Xilinx\Vitis\2024.2\bin\xsdb.bat"
tcl  = r"D:\claude_workspace\pov3d\zynq_pov\tools\set_solid_color.tcl"

TUNIT = 8
EXP   = -7
vals  = [1, 2, 4, 8, 16, 32]

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

def xsdb_call(*args):
    cmd = f"{xsdb} " + " ".join(map(str, args))
    return subprocess.run(["cmd.exe","/c",cmd], capture_output=True, text=True, timeout=30)

# Step 1: capture baseline with panel OFF
print("Step 1: panel OFF baseline")
xsdb_call(r"D:\claude_workspace\pov3d\zynq_pov\tools\set_off.tcl")
time.sleep(1.0)
base = grab()
cv2.imwrite(os.path.join(out_dir, "bcm4_base.jpg"), base)
print(f"  base mean={base.mean():.1f}")

# Step 2: capture bright reference (mode 0 SOLID with COLOR=0x3F)
print("Step 2: full bright reference (COLOR=0x3F3F3F)")
xsdb_call(tcl, TUNIT, 0x3F3F3F)
time.sleep(1.0)
bright = grab()
cv2.imwrite(os.path.join(out_dir, "bcm4_bright.jpg"), bright)
print(f"  bright mean={bright.mean():.1f}")

# Step 3: build panel mask from R-channel (bright - base) > threshold
diff_r = bright[:,:,2].astype(np.int16) - base[:,:,2].astype(np.int16)
mask = diff_r > 30
n_panel = mask.sum()
print(f"  panel pixels = {n_panel}  (mask threshold 30 in R-channel diff)")
mask_img = np.zeros_like(base)
mask_img[mask] = [0,255,0]
cv2.imwrite(os.path.join(out_dir, "bcm4_mask.jpg"), cv2.addWeighted(bright, 0.5, mask_img, 0.5, 0))

# Step 4: per-color sweep on panel-only pixels
print(f"\nStep 4: sweep (only counting panel pixels)")
results = []
for v in vals:
    rgb = (v << 16) | (v << 8) | v
    xsdb_call(tcl, TUNIT, rgb)
    time.sleep(1.0)
    frame = grab()
    if frame is None: print(f"cap fail v={v}"); continue
    cv2.imwrite(os.path.join(out_dir, f"bcm4_v{v:02x}.jpg"), frame)
    # mask + subtract baseline
    diff = frame.astype(np.int16) - base.astype(np.int16)
    diff[~mask] = 0
    bgr_mean = diff[mask].mean(axis=0) if n_panel else np.array([0,0,0])
    plane = v.bit_length() - 1
    gray = diff[mask].mean()
    results.append((v, plane, gray, bgr_mean[2], bgr_mean[1], bgr_mean[0]))
    print(f"  v=0x{v:02x} p{plane} signal_gray={gray:.1f} R={bgr_mean[2]:.1f} G={bgr_mean[1]:.1f} B={bgr_mean[0]:.1f}")

print()
print(f"{'val':>5} {'plane':>5} {'gray':>7} {'R':>6} {'R_norm':>8} {'expect':>7}")
if results:
    r0 = results[0][3]
    expect = [1, 2, 4, 8, 16, 32]
    for i, (v, p, g, R, G, B) in enumerate(results):
        ratio = R / r0 if r0 else 0
        print(f"0x{v:02x}  p{p}  {g:7.1f} {R:6.1f}  {ratio:7.2f}x  {expect[i]:>6}x")
