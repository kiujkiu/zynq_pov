import os, serial, time
ser = serial.Serial(os.environ.get("POV_COM", "COM5"), 921600, timeout=0)
t0 = time.time()
acc = b""
while time.time() - t0 < 4.0:
    c = ser.read(8192)
    if c: acc += c
    else: time.sleep(0.05)
ser.close()
for line in acc.decode("ascii", errors="replace").split("\n"):
    s = line.strip()
    if s: print(s)
