import serial, time
s = serial.Serial("COM4", 921600, timeout=0.3)
buf = b''
t_end = time.time() + 10
while time.time() < t_end:
    d = s.read(4096)
    if d: buf += d
s.close()
print(buf.decode('ascii', errors='replace'))
