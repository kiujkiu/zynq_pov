import serial, time, re
s = serial.Serial("COM6", 115200, timeout=0.5)
t_end = time.time() + 25
buf = b''
last_print = 0
ip_seen = None
tcp_listening = False
while time.time() < t_end:
    d = s.read(2048)
    if d:
        buf += d
        s_str = d.decode('ascii', errors='replace')
        # Look for IP
        m = re.search(r'sta_ip:\s*([\d.]+)', s_str) or re.search(r'got ip:\s*([\d.]+)', s_str)
        if m and not ip_seen:
            ip_seen = m.group(1)
            print(f"IP: {ip_seen}", flush=True)
        if 'TCP listening' in s_str and not tcp_listening:
            tcp_listening = True
            print("TCP listening!", flush=True)
        if 'WiFi disconnected' in s_str:
            print("WiFi DISC", flush=True)
        if 'wifi:state' in s_str:
            for ln in s_str.split('\n'):
                if 'state:' in ln:
                    print(ln.strip(), flush=True)
s.close()
print("\n--- last 1500 bytes ---")
print(buf[-1500:].decode('ascii', errors='replace'))
