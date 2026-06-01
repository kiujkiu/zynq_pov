"""Cycle 3 patterns + cap each."""
import subprocess, time, shutil
XSDB = r"C:\Xilinx\Vitis\2024.2\bin\xsdb.bat"
SET_MODE = r"D:\workspace\zynq_pov\tools\hub75e_set_mode.tcl"
CAP_PY = r"D:\workspace\zynq_pov\tools\cap_stable.py"
PYEXE = r"C:\Users\kiujkiu\AppData\Local\Programs\Python\Python312\python.exe"
SRC = r"D:\workspace\zynq_pov\tools\panel_now.jpg"

tests = [
    (7, "mode7_white"),
    (1, "mode1_hstripe"),
    (2, "mode2_vstripe"),
    (3, "mode3_checker"),
    (4, "mode4_rowwalk"),
]

for mode, label in tests:
    print(f"\n=== {label} (mode={mode}) ===", flush=True)
    r = subprocess.run([XSDB, SET_MODE, str(mode)], capture_output=True, timeout=30, text=True)
    print(r.stdout.strip().split("\n")[-1] if r.stdout else "")
    time.sleep(4)
    subprocess.run([PYEXE, CAP_PY], capture_output=True, timeout=25)
    dst = rf"D:\workspace\zynq_pov\tools\pat_{label}.jpg"
    shutil.copy(SRC, dst)
    print(f"  saved {dst}", flush=True)
print("[done]")
