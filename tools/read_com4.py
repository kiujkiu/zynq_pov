import serial, time, sys
port = sys.argv[1] if len(sys.argv) > 1 else "COM4"
secs = int(sys.argv[2]) if len(sys.argv) > 2 else 25
s = serial.Serial(port, 921600, timeout=0.5)
print(f"reading {port} for {secs}s...", flush=True)
end = time.time() + secs
while time.time() < end:
    d = s.read(4096)
    if d:
        sys.stdout.write(d.decode(errors="replace"))
        sys.stdout.flush()
s.close()
print("\n[done]")
