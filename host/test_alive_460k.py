"""Probe board at given baud — print bytes and ASCII safely."""
import serial, time, sys

baud = int(sys.argv[1]) if len(sys.argv) > 1 else 460800

ser = serial.Serial("COM10", baud, timeout=0)
print(f"opened COM10 @ {baud}, draining 3 sec...")
acc = b""
t0 = time.time()
while time.time() - t0 < 12:
    chunk = ser.read(8192)
    if chunk:
        acc += chunk
    else:
        time.sleep(0.05)
print(f"got {len(acc)} bytes")

# Show hex first 64 bytes
hex_str = " ".join(f"{b:02x}" for b in acc[:64])
print(f"hex[0:64]: {hex_str}")

# ASCII (printable only)
ascii_str = "".join(chr(b) if 32 <= b < 127 else "." for b in acc[:120])
print(f"ascii[0:120]: {ascii_str}")
ser.close()
