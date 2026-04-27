"""Diagnose GUI→Board UART frame loss rate at 115200 baud.

Sends N frames using several strategies, then counts how many board
[rx] stream_frame= echo lines come back in a 6 sec drain.

Strategies:
  A: 'rapid'    — back-to-back writes, no delay
  B: 'pace100'  — 100 ms between frames
  C: 'pace500'  — 500 ms between frames
  D: 'chunked'  — split each frame into 1 KB chunks, 5 ms between chunks
"""
import os, sys, time, re, argparse

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import serial
from glb_to_points import sample_glb
from pointcloud_proto import pack_frame

PORT = "COM10"
BAUD = 115200
GLB = os.path.join(HERE, "anime_34.glb")
N_FRAMES = 10
DRAIN_SEC = 6


def sample():
    return sample_glb(GLB, n_points=5000, target_scale=40,
                      color_mode="keep", brighten=1.5, gamma=0.8,
                      lighting="none", z_stretch=5.0, verbose=False)


def drain(ser, timeout):
    deadline = time.time() + timeout
    acc = b""
    while time.time() < deadline:
        chunk = ser.read(4096)
        if chunk:
            acc += chunk
        else:
            time.sleep(0.05)
    return acc


def count_frames(text, base_offset):
    """Find unique [rx] stream_frame=N values, return set of N."""
    seen = set()
    for m in re.finditer(r"stream_frame=(\d+)", text):
        seen.add(int(m.group(1)))
    return seen


def run_strategy(name, send_fn, pts, base_seen):
    """send_fn(ser, frames_buf_list, accum) sends all frames while draining ACKs."""
    print(f"\n=== {name} ===")
    ser = serial.Serial(PORT, BAUD, timeout=0)
    bufs = [pack_frame(i, pts, compressed=True) for i in range(1, N_FRAMES + 1)]

    accum = bytearray()
    t0 = time.time()
    send_fn(ser, bufs, accum)
    ser.flush()
    send_dt = time.time() - t0
    print(f"  send done in {send_dt:.2f} sec  (drained {len(accum)} B during)")

    # final drain after sends
    extra = drain(ser, DRAIN_SEC)
    accum.extend(extra)
    print(f"  total RX bytes captured: {len(accum)}")

    text = accum.decode("ascii", errors="replace")
    seen_now = count_frames(text, 0)
    new = seen_now - base_seen
    print(f"  unique stream_frame= seen this session: {len(seen_now)}")
    print(f"  ↑↑↑ new this run: {sorted(new)}")
    print(f"  success rate: {len(new)} / {N_FRAMES} = {100*len(new)/N_FRAMES:.0f}%")
    ser.close()
    return seen_now


def _drain_briefly(ser, accum):
    """Read whatever is buffered without blocking; append to accum (bytearray).
    PC USB-UART receive buffer would overflow under heavy board TX otherwise,
    losing ACK lines."""
    chunk = ser.read(8192)
    if chunk:
        accum.extend(chunk)


def s_rapid(ser, bufs, accum):
    for b in bufs:
        ser.write(b)
        _drain_briefly(ser, accum)


def s_pace100(ser, bufs, accum):
    for b in bufs:
        ser.write(b)
        ser.flush()
        # 100 ms paced with reads
        end = time.time() + 0.1
        while time.time() < end:
            _drain_briefly(ser, accum)
            time.sleep(0.01)


def s_pace500(ser, bufs, accum):
    for b in bufs:
        ser.write(b)
        ser.flush()
        end = time.time() + 0.5
        while time.time() < end:
            _drain_briefly(ser, accum)
            time.sleep(0.01)


def s_chunked(ser, bufs, accum):
    CHUNK = 1024
    for b in bufs:
        for off in range(0, len(b), CHUNK):
            ser.write(b[off:off+CHUNK])
            ser.flush()
            time.sleep(0.005)
            _drain_briefly(ser, accum)


STRATEGIES = {
    "rapid":   s_rapid,
    "pace100": s_pace100,
    "pace500": s_pace500,
    "chunked": s_chunked,
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("strategy", nargs="?", default="all",
                    choices=["all"] + list(STRATEGIES.keys()))
    args = ap.parse_args()

    print("sampling once...")
    pts = sample()
    print(f"  {len(pts)} pts ready")

    base = set()
    if args.strategy == "all":
        for name, fn in STRATEGIES.items():
            base = run_strategy(name, fn, pts, base)
    else:
        run_strategy(args.strategy, STRATEGIES[args.strategy], pts, base)


if __name__ == "__main__":
    main()
