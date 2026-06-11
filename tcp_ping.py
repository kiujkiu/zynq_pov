"""Send tiny 4-byte SINK marker to ESP32, watch its log."""
import socket, time, threading, serial

stop = [False]
def watch():
    s = serial.Serial("COM6", 115200, timeout=0.2)
    while not stop[0]:
        d = s.read(2048)
        if d:
            try:
                for ln in d.decode('ascii', errors='replace').split('\n'):
                    if 'pov_bridge' in ln or 'client' in ln.lower() or 'SINK' in ln:
                        print(f"  [ESP] {ln.strip()}", flush=True)
            except: pass
    s.close()

threading.Thread(target=watch, daemon=True).start()
time.sleep(0.5)

for i in range(50):
    try:
        s = socket.create_connection(("10.168.168.103", 8888), timeout=1)
        s.settimeout(3)
        s.sendall(b"SINK")
        print(f"#{i}: sent SINK", flush=True)
        time.sleep(0.5)
        s.close()
        time.sleep(1)
    except Exception as e:
        if i % 5 == 0:
            print(f"#{i}: {e}", flush=True)
    time.sleep(0.3)

time.sleep(2)
stop[0] = True
time.sleep(0.3)
