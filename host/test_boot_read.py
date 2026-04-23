import sys, time, threading, subprocess, serial
p = "COM7"
ser = serial.Serial(p, 115200, timeout=0.2)
stop = False
collected = []
def reader():
    buf = b''
    while not stop:
        d = ser.read(512)
        if d:
            buf += d
            while b'\n' in buf:
                ln, buf = buf.split(b'\n', 1)
                # strip non-printable, encode ASCII only
                safe = ln.decode('ascii', errors='replace').rstrip('\r')
                collected.append(safe)
                try:
                    sys.stdout.buffer.write(b"[BOARD] " + safe.encode('ascii', errors='replace') + b"\n")
                    sys.stdout.buffer.flush()
                except Exception:
                    pass
        else:
            time.sleep(0.02)

t = threading.Thread(target=reader, daemon=True)
t.start()

print("Running XSDB download...")
r = subprocess.run(
    [r"D:\Vitis\2024.2\bin\xsdb.bat", r"D:/workspace/zynq_pov/tools/dl_helloworld.tcl"],
    capture_output=True, text=True, timeout=60
)
print("XSDB rc =", r.returncode)
time.sleep(6)
stop = True
t.join(timeout=1)
print(f"Captured {len(collected)} lines")
ser.close()
