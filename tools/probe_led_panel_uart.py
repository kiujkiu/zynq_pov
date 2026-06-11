"""Probe COM ports for [led_panel] pattern N log @ 921600 baud."""
import serial, time, threading

found_port = None
def listen(port, baud, secs=6):
    global found_port
    try:
        s = serial.Serial(port, baud, timeout=0.3)
        t_end = time.time() + secs
        buf = b''
        while time.time() < t_end and not found_port:
            d = s.read(2048)
            if d:
                buf += d
                if b'led_panel' in buf or b'pattern' in buf or b'ENABLE_LED_PANEL' in buf:
                    found_port = (port, baud, buf[-1500:])
                    break
        s.close()
    except Exception:
        pass

threads = []
for c in [f"COM{i}" for i in range(3, 20)]:
    t = threading.Thread(target=listen, args=(c, 921600))
    t.daemon = True
    t.start()
    threads.append(t)

for t in threads:
    t.join(timeout=10)

if found_port:
    p, b, data = found_port
    print(f"FOUND Zynq LED-panel UART at {p} @ {b}")
    print("--- last buffer ---")
    print(data.decode('ascii', errors='replace'))
else:
    print("NOT FOUND on any COM3-19 @ 921600")
