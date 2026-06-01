"""Cycle through 6 single-channel COLOR values + capture each."""
import subprocess, time, os, shutil
XSDB = r"C:\Xilinx\Vitis\2024.2\bin\xsdb.bat"
SET_COLOR = r"D:\workspace\zynq_pov\tools\hub75e_set_color.tcl"
CAP_PY = r"D:\workspace\zynq_pov\tools\cap_panel_now.py"
PYEXE = r"C:\Users\kiujkiu\AppData\Local\Programs\Python\Python312\python.exe"
SRC = r"D:\workspace\zynq_pov\tools\panel_now.jpg"

tests = [
    (0x01, "R1_only"),
    (0x02, "G1_only"),
    (0x04, "B1_only"),
    (0x08, "R2_only"),
    (0x10, "G2_only"),
    (0x20, "B2_only"),
]

for color, label in tests:
    print(f"\n=== {label} (COLOR=0x{color:02x}) ===", flush=True)
    subprocess.run([XSDB, SET_COLOR, hex(color)], capture_output=True, timeout=30)
    time.sleep(2)
    subprocess.run([PYEXE, CAP_PY], capture_output=True, timeout=20)
    dst = rf"D:\workspace\zynq_pov\tools\sweep_{label}.jpg"
    shutil.copy(SRC, dst)
    print(f"  saved {dst}", flush=True)

print("\n[done]")
