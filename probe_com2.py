import serial, time
for c in ["COM4", "COM5"]:
    print(f"=== {c} 921600 ===", flush=True)
    try:
        s = serial.Serial(c, 921600, timeout=0.5)
        t_end = time.time() + 3
        buf = b''
        while time.time() < t_end:
            d = s.read(512)
            if d: buf += d
        s.close()
        print(buf[:1200].decode('ascii', errors='replace'))
    except Exception as e:
        print(f"err: {e}")
