"""Just open COM10 and read for 3 sec — print raw bytes count + first 20 lines."""
import serial, time, sys

ser = serial.Serial("COM10", 115200, timeout=0)
print("opened, draining 3 sec...")
acc = b""
t0 = time.time()
while time.time() - t0 < 3:
    chunk = ser.read(8192)
    if chunk:
        acc += chunk
    else:
        time.sleep(0.05)
print(f"got {len(acc)} bytes")
text = acc.decode("ascii", errors="replace")
lines = [ln.strip() for ln in text.split("\n") if ln.strip()]
print(f"{len(lines)} lines, first 20:")
for l in lines[:20]:
    print(f"  | {l}")
ser.close()
