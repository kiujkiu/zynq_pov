import sys, time, serial
p = sys.argv[1] if len(sys.argv) > 1 else "COM7"
ser = serial.Serial(p, 115200, timeout=2.0)
time.sleep(0.2)
# read for 3 seconds
t_end = time.time() + 3
buf = b''
while time.time() < t_end:
    d = ser.read(256)
    if d: buf += d
print(buf.decode('latin-1', errors='replace'))
ser.close()
