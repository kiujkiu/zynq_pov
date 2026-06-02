"""Try multiple baud rates on COM10."""
import serial, time
for baud in [921600, 460800, 230400, 115200, 9600]:
    try:
        s = serial.Serial("COM10", baud, timeout=0.3)
        time.sleep(0.1)
        buf = b""
        t = time.time()
        while time.time() - t < 1.5:
            c = s.read(4096)
            if c: buf += c
        s.close()
        if buf:
            print(f"=== {baud} baud: {len(buf)} bytes ===")
            print(buf.decode("utf-8", errors="replace")[-1500:])
            print()
    except Exception as e:
        print(f"{baud}: {e}")
