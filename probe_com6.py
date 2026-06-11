import serial, time
s = serial.Serial("COM6", 921600, timeout=0.5)
t_end = time.time() + 3
buf = b''
while time.time() < t_end:
    d = s.read(512)
    if d: buf += d
s.close()
print(f"got {len(buf)} bytes")
# Filter printable
printable = bytes(b for b in buf if 9 <= b <= 126 or b in (10,13))
print(f"printable len {len(printable)}")
print(printable[:2000].decode('ascii', errors='replace'))
