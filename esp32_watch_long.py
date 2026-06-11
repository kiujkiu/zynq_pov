import serial, time
s = serial.Serial("COM5", 115200, timeout=0.3)
t_end = time.time() + 40
while time.time() < t_end:
    d = s.read(2048)
    if d:
        try:
            txt = d.decode('ascii', errors='replace')
            for ln in txt.split('\n'):
                ln = ln.strip()
                if 'pov_bridge' in ln or 'Got IP' in ln or 'state:' in ln or 'reason' in ln:
                    print(ln, flush=True)
        except: pass
s.close()
