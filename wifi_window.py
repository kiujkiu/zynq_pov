"""Catch any TCP window in 120s of retries. Print log markers."""
import socket, time, threading, serial

log_lines = []
stop = [False]

def log_reader():
    s = serial.Serial("COM6", 115200, timeout=0.2)
    while not stop[0]:
        d = s.read(2048)
        if d:
            try:
                txt = d.decode('ascii', errors='replace')
                for ln in txt.split('\n'):
                    if 'state:' in ln or 'pov_bridge' in ln or 'connected' in ln.lower():
                        log_lines.append(f"  LOG: {ln.strip()}")
            except: pass
    s.close()

threading.Thread(target=log_reader, daemon=True).start()

t_start = time.time()
attempts = 0
while time.time() - t_start < 120:
    elapsed = time.time() - t_start
    try:
        s = socket.create_connection(("10.168.168.103", 8888), timeout=0.8)
        s.settimeout(10)
        # send 4-byte SINK marker for ESP to log
        s.sendall(b"SINK")
        print(f"[{elapsed:.1f}s] #{attempts}: CONNECT + SINK sent", flush=True)
        time.sleep(0.5)
        s.close()
        break
    except (socket.timeout, ConnectionRefusedError, OSError):
        pass
    attempts += 1
    if attempts % 15 == 0:
        print(f"[{elapsed:.1f}s] {attempts} attempts, still failing", flush=True)
        # print recent logs
        recent = log_lines[-5:] if log_lines else ['(no logs)']
        for ln in recent: print(ln, flush=True)
        log_lines.clear()
    time.sleep(0.3)
else:
    print(f"DONE: {attempts} attempts, no success in 120s", flush=True)

stop[0] = True
time.sleep(0.3)
