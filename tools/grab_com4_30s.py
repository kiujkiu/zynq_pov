import serial, time, sys
s = serial.Serial("COM5", 921600, timeout=0.3)
buf = b''
t_end = time.time() + 30
while time.time() < t_end:
    d = s.read(4096)
    if d: buf += d; sys.stdout.write(d.decode('ascii', errors='replace')); sys.stdout.flush()
s.close()
print("\n--- total bytes: %d ---" % len(buf))
