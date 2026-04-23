"""Quick sanity check: send only 6 slices (ids 0, 6, 12, 24, 48, 71).
If OK then run send_72_slices.py for full batch."""
import sys, time, serial
from send_72_slices import make_slice, ESC, PORT, BAUD, NUM_SLICES

ser = serial.Serial(PORT, BAUD, timeout=1.0)
time.sleep(0.3)
# clear
ser.write(bytes([ESC, 0x01])); ser.flush()
time.sleep(1.0)
for n in [0, 6, 12, 24, 48, 71]:
    payload = make_slice(n)
    pkt = bytes([ESC, 0x04, n]) + payload
    t0 = time.time()
    ser.write(pkt); ser.flush()
    print(f"slice {n:2d} sent in {time.time()-t0:.2f}s")
ser.close()
print("done")
