import serial, time
s = serial.Serial("COM6", 115200, timeout=0.5)
t_end = time.time() + 8
buf = b''
while time.time() < t_end:
    d = s.read(4096)
    if d: buf += d
s.close()
text = buf.decode('ascii', errors='replace')
# Print everything
for ln in text.split('\n'):
    ln = ln.rstrip()
    if ln:
        print(ln)
