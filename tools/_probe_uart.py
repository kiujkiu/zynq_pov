import serial, time
s = serial.Serial("COM5", 921600, timeout=3)
t0 = time.time()
got = 0
while time.time() - t0 < 5:
    line = s.readline().decode(errors="replace").strip()
    if line:
        print(repr(line))
        got += 1
print(f"--- {got} lines in 5s ---")
s.close()
