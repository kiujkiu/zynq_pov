import serial, time
for c in ["COM4", "COM5", "COM6", "COM7"]:
    for b in [115200, 921600]:
        try:
            s = serial.Serial(c, b, timeout=0.3)
            t_end = time.time() + 1.5
            buf = b''
            while time.time() < t_end:
                d = s.read(512)
                if d: buf += d
            s.close()
            if buf:
                print(f"=== {c} {b} got {len(buf)} bytes ===")
                print(buf[:400].decode('ascii', errors='replace'))
        except Exception as e:
            pass
