import serial, time
s = serial.Serial("COM6", 115200, timeout=0.5)
t_end = time.time() + 10
buf = b''
while time.time() < t_end:
    d = s.read(4096)
    if d: buf += d
s.close()
text = buf.decode('ascii', errors='replace')
# Find ALL unique tags
import re
tags = set()
for ln in text.split('\n'):
    m = re.search(r'\b([a-z_]+(?:_[a-z0-9]+)*)\s*:', ln)
    if m: tags.add(m.group(1))
print("Tags seen:", sorted(tags))
print("\n=== all lines mentioning IP/dhcp/inet ===")
for ln in text.split('\n'):
    if any(k in ln.lower() for k in ['ip:', 'dhcp', 'inet', 'address', '10.168', '192.168', 'addr=', 'lease']):
        print(ln.strip())
