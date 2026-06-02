"""BCM weight sweep: iterate COLOR=0x01..0x20 (each lights one plane only),
   capture panel, measure mean brightness over panel ROI.
   If BCM weights work: brightness doubles each step.
   If collapsed:        all 6 values give similar brightness.
"""
import subprocess, time, sys, os
out_dir = r"D:\claude_workspace\pov3d\zynq_pov"

xsdb = r"C:\Xilinx\Vitis\2024.2\bin\xsdb.bat"
tcl  = r"D:\claude_workspace\pov3d\zynq_pov\tools\set_solid_color.tcl"

# Six values: each isolates one BCM plane
# 0x010101 -> plane 0 only on all 3 channels (R=G=B=1)
# 0x020202 -> plane 1, etc.
vals = [1, 2, 4, 8, 16, 32]
TUNIT = 64  # higher TUNIT for visible signal even on plane 0

# Camera helper: cv2 idx 0 ANY backend
import cv2, numpy as np
def grab(tag):
    cap = cv2.VideoCapture(0, cv2.CAP_ANY)
    if not cap.isOpened():
        print("CAM FAIL"); return None
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
    cap.set(cv2.CAP_PROP_AUTO_EXPOSURE, 0.25)
    cap.set(cv2.CAP_PROP_EXPOSURE, -6)
    for _ in range(20):
        cap.read(); time.sleep(0.04)
    ok, frame = cap.read()
    cap.release()
    if not ok or frame is None: return None
    cv2.imwrite(os.path.join(out_dir, f"bcm_sweep_{tag}.jpg"), frame)
    return frame

# Run
print(f"=== BCM sweep, TUNIT={TUNIT} ===")
results = []
# crop ROI: laptop cam 640x480, panel occupies center-ish
# from prior captures panel is roughly x=50..560, y=50..420 in 640x480
roi = (50, 50, 560, 420)
for v in vals:
    rgb = (v << 16) | (v << 8) | v
    r = subprocess.run(["cmd.exe", "/c", f"{xsdb} {tcl} {TUNIT} {rgb}"],
                       capture_output=True, text=True, timeout=30)
    last = r.stdout.strip().splitlines()[-1] if r.stdout else "no out"
    print(f"  COLOR=0x{v:02x}  {last}")
    time.sleep(1.0)
    frame = grab(f"v{v:02x}")
    if frame is None:
        print("  cap fail"); continue
    x0, y0, x1, y1 = roi
    region = frame[y0:y1, x0:x1]
    bgr_mean = region.mean(axis=(0,1))
    gray_mean = region.mean()
    print(f"  v=0x{v:02x} (plane {bin(v).count('1')-1}) gray={gray_mean:.1f}  B={bgr_mean[0]:.1f} G={bgr_mean[1]:.1f} R={bgr_mean[2]:.1f}")
    results.append((v, gray_mean, bgr_mean[2], bgr_mean[1], bgr_mean[0]))

print()
print(f"{'val':>5} {'plane':>5} {'gray':>6} {'R':>6} {'G':>6} {'B':>6} {'gray/min':>8}")
if results:
    mins = min(r[1] for r in results)
    for v, g, r, gg, b in results:
        plane = (v.bit_length() - 1)
        ratio = g / mins if mins > 0 else 0
        print(f"0x{v:02x}  p{plane}  {g:6.1f} {r:6.1f} {gg:6.1f} {b:6.1f} {ratio:8.2f}x")
