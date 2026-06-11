import serial, time
s = serial.Serial("COM6", 115200, timeout=0.5)
t_end = time.time() + 5
buf = b''
while time.time() < t_end:
    d = s.read(1024)
    if d: buf += d
s.close()
print(f"got {len(buf)} bytes")
try:
    print(buf.decode('utf-8', errors='replace')[-3000:])
except Exception as e:
    print(buf[-3000:])
