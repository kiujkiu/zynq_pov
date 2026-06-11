import serial, sys, time
for c in ["COM4", "COM5"]:
    print(f"=== {c} ===", flush=True)
    try:
        s = serial.Serial(c, 115200, timeout=0.5)
        t_end = time.time() + 3
        buf = b''
        while time.time() < t_end:
            d = s.read(256)
            if d:
                buf += d
        s.close()
        print(buf.decode('ascii', errors='replace'))
    except Exception as e:
        print(f"err: {e}")
