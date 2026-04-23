import sys, time, serial
dur = int(sys.argv[1]) if len(sys.argv) > 1 else 15
ser = serial.Serial("COM7", 115200, timeout=0.3)
t_end = time.time() + dur
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
