"""Visual A/B test: load grid fb, then alternate overlap_en=0 vs 1, capture each.
   Easier to evaluate by eye than noisy single-plane sweep.
"""
import subprocess, time, os, cv2
out_dir = r"D:\claude_workspace\pov3d\zynq_pov"
xsdb = r"C:\Xilinx\Vitis\2024.2\bin\xsdb.bat"

def run_xsdb_inline(script):
    return subprocess.run(["cmd.exe","/c", f'{xsdb} -eval "{script}"'],
                          capture_output=True, text=True, timeout=30)

def grab(label, exp):
    cap = cv2.VideoCapture(0, cv2.CAP_ANY)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
    cap.set(cv2.CAP_PROP_AUTO_EXPOSURE, 0.25)
    cap.set(cv2.CAP_PROP_EXPOSURE, exp)
    for _ in range(25): cap.read(); time.sleep(0.04)
    ok, f = cap.read()
    cap.release()
    if ok:
        path = os.path.join(out_dir, f"grid_ab_{label}.jpg")
        cv2.imwrite(path, f)
        print(f"  {label}: mean={f.mean():.1f} -> {path}")
        return f
    return None

# Step 1: load grid fb (already loaded from previous serial run, but reload to be safe)
print("Loading grid fb + TUNIT=32 ...")
script1 = ("connect; after 300; targets -set -nocase -filter {name =~ \\\"APU*\\\"};"
           "configparams force-mem-access 1;"
           "mwr -bin -file \\\"D:/claude_workspace/pov3d/zynq_pov/tools/fb_top.bin\\\" -size w 0x4002C000 4096;"
           "mwr -bin -file \\\"D:/claude_workspace/pov3d/zynq_pov/tools/fb_bot.bin\\\" -size w 0x40028000 4096;"
           "mwr 0x40020014 32; exit")
r = subprocess.run(["cmd.exe","/c", f'{xsdb} -eval "{script1}"'],
                   capture_output=True, text=True, timeout=60)
time.sleep(1)

# Step 2: enable use_fb mode 0 SERIAL (overlap_en=0)
# CTRL = en | mode0<<1 | addr_bits=5<<8 | use_fb=1<<5 | overlap_en=0<<6 = 0x521
print("\n=== SERIAL grid (CTRL=0x521, overlap_en=0) ===")
run_xsdb_inline("connect; targets -set -nocase -filter {name =~ \\\"APU*\\\"}; configparams force-mem-access 1; mwr 0x40020000 0x521; after 300; puts STATUS=[mrd 0x4002000C]; exit")
time.sleep(1.5)
f_serial = grab("serial", -8)

# Step 3: enable use_fb mode 0 OVERLAP (overlap_en=1)
# CTRL = 0x521 | 0x40 = 0x561
print("\n=== OVERLAP grid (CTRL=0x561, overlap_en=1, OE_PRE=8) ===")
run_xsdb_inline("connect; targets -set -nocase -filter {name =~ \\\"APU*\\\"}; configparams force-mem-access 1; mwr 0x40020000 0x561; after 300; puts STATUS=[mrd 0x4002000C]; exit")
time.sleep(1.5)
f_overlap = grab("overlap", -8)

# Step 4: read frame rate for both
print("\n=== Frame rate measurement ===")
for label, ctrl in [("serial", 0x521), ("overlap", 0x561)]:
    run_xsdb_inline(f"connect; targets -set -nocase -filter {{name =~ \\\"APU*\\\"}}; configparams force-mem-access 1; mwr 0x40020000 {hex(ctrl)}; after 500; "
                    f"set s0 [mrd -value 0x4002000C]; after 1000; set s1 [mrd -value 0x4002000C]; "
                    f"set fps [expr {{(($s1 >> 16) - ($s0 >> 16)) & 0xFFFF}}]; "
                    f"puts \\\"{label} fps=$fps\\\"; exit")
    time.sleep(0.5)
