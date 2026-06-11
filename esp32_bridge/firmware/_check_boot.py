"""Read 25s of boot log to verify pov_bridge connects + dials PC."""
import serial, time, sys
s = serial.Serial('COM6', 115200, timeout=0.2)
s.setDTR(False); s.setRTS(True); time.sleep(0.15); s.setRTS(False)
end = time.time() + 25
while time.time() < end:
    d = s.read(8192)
    if d: sys.stdout.buffer.write(d); sys.stdout.flush()
s.close()
