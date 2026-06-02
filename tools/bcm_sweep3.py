"""BCM sweep v3 — TUNIT=8 + long exp + cumulative brightness via R channel."""
import subprocess, time, os, cv2
out_dir = r"D:\claude_workspace\pov3d\zynq_pov"
xsdb = r"C:\Xilinx\Vitis\2024.2\bin\xsdb.bat"
tcl  = r"D:\claude_workspace\pov3d\zynq_pov\tools\set_solid_color.tcl"

ROI = (130, 80, 540, 380)
TUNIT = 8
EXPS = [-7, -6, -5]
vals = [1, 2, 4, 8, 16, 32]

def grab():
    for exp in EXPS:
        cap = cv2.VideoCapture(0, cv2.CAP_ANY)
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
        cap.set(cv2.CAP_PROP_AUTO_EXPOSURE, 0.25)
        cap.set(cv2.CAP_PROP_EXPOSURE, exp)
        for _ in range(20): cap.read(); time.sleep(0.04)
        ok, frame = cap.read()
        cap.release()
        if not ok: continue
        x0,y0,x1,y1 = ROI
        r = frame[y0:y1, x0:x1]
        if 20 < r.mean() < 240:
            return r, exp
        time.sleep(0.2)
    return r, exp  # return last even if outside range

print(f"=== BCM sweep v3 TUNIT={TUNIT} ROI={ROI} EXPS={EXPS} ===")
results = []
for v in vals:
    rgb = (v << 16) | (v << 8) | v
    subprocess.run(["cmd.exe","/c",f"{xsdb} {tcl} {TUNIT} {rgb}"],
                   capture_output=True, text=True, timeout=30)
    time.sleep(1.0)
    region, exp = grab()
    bgr = region.mean(axis=(0,1))
    plane = v.bit_length() - 1
    results.append((v, plane, exp, region.mean(), bgr[2], bgr[1], bgr[0]))
    print(f"  v=0x{v:02x} p{plane} exp={exp} gray={region.mean():.1f} R={bgr[2]:.1f} G={bgr[1]:.1f} B={bgr[0]:.1f}")

print()
print(f"{'val':>5} {'plane':>5} {'exp':>5} {'gray':>7} {'R':>6} {'G':>6} {'B':>6} {'R_norm':>8}")
if results:
    # use R channel since it's brightest, normalize to plane 0
    r0 = results[0][4]
    for v, p, e, g, R, G, B in results:
        ratio = R / r0 if r0 > 0 else 0
        print(f"0x{v:02x}  p{p}  {e:>+5} {g:7.1f} {R:6.1f} {G:6.1f} {B:6.1f} {ratio:7.2f}x")
print()
print("If BCM works:    1, 2, 4, 8, 16, 32 (R channel ratio doubles each step)")
print("If BCM dead:     all R ratios ~1.0")
