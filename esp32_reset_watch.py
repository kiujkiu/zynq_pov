"""Reset ESP32 (via DTR/RTS) then watch boot logs for 30s."""
import serial, time
s = serial.Serial("COM6", 115200, timeout=0.3)
# ESP32 reset: pull EN low briefly
s.setDTR(False)   # GPIO0 pulled high via inverter? Try simple reset
s.setRTS(True)    # EN low (active low reset)
time.sleep(0.1)
s.setRTS(False)   # EN high → boot
time.sleep(0.2)
print("=== ESP32 reset, watching logs ===", flush=True)
t_end = time.time() + 30
buf = b''
got_ip = False
tcp_listen = False
while time.time() < t_end:
    d = s.read(2048)
    if d:
        buf += d
        s_str = d.decode('ascii', errors='replace')
        for ln in s_str.split('\n'):
            ln = ln.strip()
            if 'Got IP' in ln or 'TCP listening' in ln or 'mDNS' in ln or 'sdio_slave_setup' in ln or 'pov_bridge' in ln.lower():
                print(ln, flush=True)
                if 'Got IP' in ln: got_ip = True
                if 'TCP listening' in ln: tcp_listen = True
s.close()
print(f"\n--- summary: got_ip={got_ip} tcp_listen={tcp_listen} total bytes={len(buf)}")
