import serial, time
s = serial.Serial("COM5", 115200, timeout=0.3)
s.setRTS(True); time.sleep(0.1); s.setRTS(False); time.sleep(0.2)
print("=== ESP32 reset, watching ===", flush=True)
t_end = time.time() + 25
got_ip = False
tcp_listen = False
seen_reasons = set()
while time.time() < t_end:
    d = s.read(2048)
    if d:
        try:
            txt = d.decode('ascii', errors='replace')
            for ln in txt.split('\n'):
                ln = ln.strip()
                if 'pov_bridge' in ln or 'Got IP' in ln or 'TCP listening' in ln:
                    print(ln, flush=True)
                    if 'Got IP' in ln: got_ip = True
                    if 'TCP listening' in ln: tcp_listen = True
                if 'reason=' in ln:
                    import re
                    m = re.search(r'reason=(\d+)', ln)
                    if m: seen_reasons.add(int(m.group(1)))
        except: pass
s.close()
print(f"\n--- summary: got_ip={got_ip} tcp_listen={tcp_listen} reasons={sorted(seen_reasons)} ---")
