"""Find which COM port has the Zynq UART by listening for `[ringV]` print."""
import serial, time, sys, threading

found_port = None
def listen(port, baud):
    global found_port
    try:
        s = serial.Serial(port, baud, timeout=0.3)
        t_end = time.time() + 5
        buf = b''
        while time.time() < t_end and not found_port:
            d = s.read(512)
            if d:
                buf += d
                if b'ringV' in buf or b'PL IP' in buf or b'Voxel' in buf or b'pov_project' in buf:
                    found_port = (port, baud, buf[:600])
                    break
        s.close()
    except Exception as e:
        pass

threads = []
for c in ["COM3", "COM4", "COM5", "COM7", "COM8", "COM9"]:
    for b in [115200, 921600]:
        t = threading.Thread(target=listen, args=(c, b))
        t.daemon = True
        t.start()
        threads.append(t)

for t in threads:
    t.join(timeout=8)

if found_port:
    p, b, data = found_port
    print(f"FOUND Zynq UART at {p} @ {b}")
    print(data.decode('ascii', errors='replace'))
else:
    print("NOT FOUND")
