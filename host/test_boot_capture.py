"""Open COM10 at 115200 and dump first 6 sec of output — captures boot banner."""
import serial, time, sys

baud = int(sys.argv[1]) if len(sys.argv) > 1 else 115200
ser = serial.Serial("COM10", baud, timeout=0)
print(f"COM10 @ {baud} for 6s...")
acc = bytearray()
t0 = time.time()
while time.time() - t0 < 6:
    chunk = ser.read(8192)
    if chunk: acc.extend(chunk)
    else: time.sleep(0.02)
print(f"got {len(acc)} bytes")
text = bytes(acc).decode("ascii", errors="replace")
for ln in text.split("\n"):
    ln = ln.strip()
    if ln:
        clean = "".join(ch if 32 <= ord(ch) < 127 else "?" for ch in ln)
        print(f"  | {clean}")
ser.close()
