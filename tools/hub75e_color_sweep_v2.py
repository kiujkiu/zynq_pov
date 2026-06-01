"""Slow sweep: set color → 4s wait → drain + cap stable frame."""
import subprocess, time, shutil
XSDB = r"C:\Xilinx\Vitis\2024.2\bin\xsdb.bat"
SET_COLOR = r"D:\workspace\zynq_pov\tools\hub75e_set_color.tcl"
CAP_PY = r"D:\workspace\zynq_pov\tools\cap_stable.py"
PYEXE = r"C:\Users\kiujkiu\AppData\Local\Programs\Python\Python312\python.exe"
SRC = r"D:\workspace\zynq_pov\tools\panel_now.jpg"

tests = [
    (0x01, "R1"), (0x02, "G1"), (0x04, "B1"),
    (0x08, "R2"), (0x10, "G2"), (0x20, "B2"),
]

for color, label in tests:
    print(f"\n=== {label} (COLOR=0x{color:02x}) ===", flush=True)
    r = subprocess.run([XSDB, SET_COLOR, hex(color)], capture_output=True, timeout=30, text=True)
    print(r.stdout.strip().split("\n")[-1] if r.stdout else "")
    time.sleep(4)  # PL update + panel display stabilize
    subprocess.run([PYEXE, CAP_PY], capture_output=True, timeout=25)
    dst = rf"D:\workspace\zynq_pov\tools\sweep2_{label}.jpg"
    shutil.copy(SRC, dst)
    print(f"  saved {dst}", flush=True)
print("\n[done]")
