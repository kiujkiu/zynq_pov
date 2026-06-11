"""Auto-detect CH340 COM port and grab 30s @ 921600."""
import serial, serial.tools.list_ports, time, sys

port = None
for p in serial.tools.list_ports.comports():
    if "CH340" in (p.description or "") or "1A86:7523" in (p.hwid or ""):
        port = p.device
        break
if not port:
    print("NO CH340 COM PORT FOUND")
    sys.exit(1)
print(f"using {port}")
s = serial.Serial(port, 921600, timeout=0.3)
buf = b''
t_end = time.time() + 30
while time.time() < t_end:
    d = s.read(4096)
    if d:
        buf += d
s.close()
with open(r"D:\claude_workspace\pov3d\zynq_pov\uart_grab.txt", "wb") as fp:
    fp.write(buf)
print("--- total bytes: %d ---" % len(buf))
