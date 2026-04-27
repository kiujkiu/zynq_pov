"""Send a frame, wait for ack, repeat. Deterministic 1-in-flight.
If success rate stays low, problem is on board RX side (FIFO overflow).
If success rate climbs, problem is host write/USB pile-up.
"""
import os, sys, time, re

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import serial
from glb_to_points import sample_glb
from pointcloud_proto import pack_frame

ser = serial.Serial("COM10", 921600, timeout=0)
pts = sample_glb(os.path.join(HERE, "anime_62459.glb"),
                 n_points=5000, target_scale=40,
                 color_mode="keep", brighten=1.5, gamma=0.8,
                 lighting="none", z_stretch=5.0, verbose=False)

ATTEMPTS = 10
ACK_TIMEOUT = 6.0   # generous wait

ack_re = re.compile(rb"stream_frame=(\d+)")
success = 0
last_ack = -1

for i in range(1, ATTEMPTS + 1):
    # Drain anything pending so our wait is clean
    while ser.read(8192):
        pass

    buf = pack_frame(i, pts, compressed=True)
    t0 = time.time()
    ser.write(buf)
    ser.flush()
    send_dt = time.time() - t0

    # Wait for ack containing a stream_frame= NEW value
    deadline = time.time() + ACK_TIMEOUT
    accum = b""
    got_new = None
    while time.time() < deadline:
        chunk = ser.read(8192)
        if chunk:
            accum += chunk
            for m in ack_re.findall(accum):
                v = int(m)
                if v != last_ack:
                    got_new = v
                    last_ack = v
                    break
            if got_new is not None:
                break
        else:
            time.sleep(0.02)

    wait_dt = time.time() - (deadline - ACK_TIMEOUT)
    if got_new is not None:
        success += 1
        print(f"  frame {i:2d} OK  ack=stream_frame={got_new}  "
              f"send={send_dt:.2f}s  wait={wait_dt:.2f}s")
    else:
        # show first 80 bytes of captured to see if it's ASCII or garbage
        sample = accum[:80]
        ascii_str = "".join(chr(b) if 32 <= b < 127 else "." for b in sample)
        print(f"  frame {i:2d} FAIL  no ack ({len(accum)} B): {ascii_str}")

ser.close()
print(f"\nresult: {success}/{ATTEMPTS} = {100*success/ATTEMPTS:.0f}%")
