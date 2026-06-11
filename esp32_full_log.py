import serial, time
s = serial.Serial("COM6", 115200, timeout=0.5)
t_end = time.time() + 15
buf = b''
while time.time() < t_end:
    d = s.read(2048)
    if d: buf += d
s.close()
# Extract pov_bridge tag messages only
text = buf.decode('ascii', errors='replace')
print(f"=== pov_bridge_sdio msgs ===")
for ln in text.split('\n'):
    if 'pov_bridge' in ln.lower() or 'TCP' in ln or 'Got IP' in ln or 'mDNS' in ln or 'sdio_slave' in ln.lower():
        print(ln.strip())
