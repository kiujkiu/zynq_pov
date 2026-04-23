import sys, time, serial
ser = serial.Serial("COM7", 115200, timeout=0.5)
t_end = time.time() + 10
buf = b''
while time.time() < t_end:
    d = ser.read(512)
    if d:
        buf += d
        while b'\n' in buf:
            ln, buf = buf.split(b'\n', 1)
            try:
                print(ln.decode('ascii', errors='replace').rstrip())
            except: pass
ser.close()
