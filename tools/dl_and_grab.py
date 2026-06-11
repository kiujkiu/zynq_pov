"""dl + capture UART boot log immediately. Auto-detect CH340 COM port."""
import subprocess, serial, serial.tools.list_ports, time, threading, sys

# find CH340 COM
port = None
for p in serial.tools.list_ports.comports():
    if "CH340" in (p.description or "") or "1A86:7523" in (p.hwid or ""):
        port = p.device
        break
if not port:
    print("NO CH340 COM PORT FOUND"); sys.exit(1)
print(f"using {port}")

buf = b''
def listener():
    global buf
    s = serial.Serial(port, 921600, timeout=0.3)
    t_end = time.time() + 25
    while time.time() < t_end:
        d = s.read(4096)
        if d: buf += d
    s.close()
    with open(r"D:\claude_workspace\pov3d\zynq_pov\dl_grab_raw.txt", "wb") as fp:
        fp.write(buf)

t = threading.Thread(target=listener, daemon=True)
t.start()
time.sleep(0.5)
print("--- launching xsdb dl ---")
subprocess.run([r"D:\Vitis\2024.2\bin\xsdb.bat", r"D:\claude_workspace\pov3d\zynq_pov\tools\dl_helloworld.tcl"], capture_output=True)
print("--- xsdb done, waiting for listener ---")
t.join()
print("--- total bytes: %d ---" % len(buf))
