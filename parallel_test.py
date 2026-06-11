"""Parallel: watch ESP32 logs while attempting many TCP connects."""
import serial, time, socket, threading

stop = [False]
log_buf = []

def log_reader():
    s = serial.Serial("COM6", 115200, timeout=0.3)
    while not stop[0]:
        d = s.read(1024)
        if d:
            try:
                log_buf.append(d.decode('ascii', errors='replace'))
            except: pass
    s.close()

def tcp_attempts():
    time.sleep(1)  # let log reader warm up
    for i in range(30):
        if stop[0]: break
        try:
            sock = socket.create_connection(("10.168.168.103", 8888), timeout=1)
            print(f"[{i}] CONNECT OK", flush=True)
            sock.close()
        except Exception as e:
            if i % 5 == 0: print(f"[{i}] {type(e).__name__}", flush=True)
        time.sleep(0.5)
    stop[0] = True

t1 = threading.Thread(target=log_reader)
t2 = threading.Thread(target=tcp_attempts)
t1.start(); t2.start()
t2.join()
time.sleep(0.5)
stop[0] = True
t1.join()

print("\n=== ESP32 LOG SLICE ===")
full = ''.join(log_buf)
# Get last 100 lines
lines = full.split('\n')
for ln in lines[-80:]:
    ln = ln.rstrip()
    if ln:
        print(ln)
