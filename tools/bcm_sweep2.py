"""BCM weight sweep v2 — locked low exposure, tight panel ROI."""
import subprocess, time, sys, os, cv2, numpy as np
out_dir = r"D:\claude_workspace\pov3d\zynq_pov"
xsdb = r"C:\Xilinx\Vitis\2024.2\bin\xsdb.bat"
tcl  = r"D:\claude_workspace\pov3d\zynq_pov\tools\set_solid_color.tcl"

# tighter panel ROI based on prior captures
ROI = (130, 80, 540, 380)  # x0,y0,x1,y1
EXP = -10
TUNIT = 64
vals = [1, 2, 4, 8, 16, 32]

def grab(tag):
    cap = cv2.VideoCapture(0, cv2.CAP_ANY)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
    cap.set(cv2.CAP_PROP_AUTO_EXPOSURE, 0.25)
    cap.set(cv2.CAP_PROP_EXPOSURE, EXP)
    for _ in range(25): cap.read(); time.sleep(0.04)
    ok, frame = cap.read()
    cap.release()
    if not ok: return None
    cv2.imwrite(os.path.join(out_dir, f"bcm2_{tag}.jpg"), frame)
    return frame

print(f"=== BCM sweep v2: TUNIT={TUNIT} EXP={EXP} ROI={ROI} ===")
results = []
for v in vals:
    rgb = (v << 16) | (v << 8) | v
    r = subprocess.run(["cmd.exe", "/c", f"{xsdb} {tcl} {TUNIT} {rgb}"],
                       capture_output=True, text=True, timeout=30)
    time.sleep(0.8)
    frame = grab(f"v{v:02x}")
    if frame is None: print(f"cap fail v={v}"); continue
    x0,y0,x1,y1 = ROI
    region = frame[y0:y1, x0:x1]
    bgr = region.mean(axis=(0,1))
    plane = v.bit_length() - 1
    results.append((v, plane, region.mean(), bgr[2], bgr[1], bgr[0]))
    print(f"  v=0x{v:02x} plane{plane} gray={region.mean():.2f} R={bgr[2]:.2f} G={bgr[1]:.2f} B={bgr[0]:.2f}")

if results:
    print()
    print(f"{'val':>5} {'plane':>5} {'gray':>7} {'R':>6} {'G':>6} {'B':>6} {'ratio':>8}")
    mins = min(r[2] for r in results) or 1
    for v, p, g, R, G, B in results:
        print(f"0x{v:02x}  p{p}  {g:7.2f} {R:6.2f} {G:6.2f} {B:6.2f} {g/mins:7.2f}x")
    # Expected if BCM works: 1, 2, 4, 8, 16, 32 (ratio)
    print()
    print("expected if BCM weights preserved: 1, 2, 4, 8, 16, 32 (each plane 2x prev)")
    print("expected if BCM collapsed:          all values similar")
