"""Calibration sweep capture (two-phase).

UART-synchronized: firmware mode_calib_sweep prints
  [CAL]  idx C K B          per Phase 1 tuple (1728 total)
  [CAL2] idx C K B R        per Phase 2 tuple (384 total, fixed C/K/B, sweep R)
We grab a camera frame on each line, save as cal_/cal2_*.jpg.

Run:
    python cap_sweep.py [com_port] [cam_idx]
Defaults: COM4, cam_idx=1.
"""
import sys, os, time, cv2, serial

PORT     = sys.argv[1] if len(sys.argv) > 1 else "COM4"
CAM_IDX  = int(sys.argv[2]) if len(sys.argv) > 2 else 1
BAUD     = 921600
OUT_DIR  = r"D:\workspace\zynq_pov\tools\calib_out"
EXPECTED_P1 = 9 * 12 * 16  # 1728
EXPECTED_P2 = 384
EXPECTED    = EXPECTED_P1 + EXPECTED_P2

os.makedirs(OUT_DIR, exist_ok=True)

print(f"open UART {PORT} @ {BAUD}, cam idx {CAM_IDX}, out {OUT_DIR}")
ser = serial.Serial(PORT, BAUD, timeout=2.0)
cap = cv2.VideoCapture(CAM_IDX, cv2.CAP_MSMF)
cap.set(cv2.CAP_PROP_FRAME_WIDTH,  1920)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
for _ in range(10):
    cap.read(); time.sleep(0.05)

print("waiting for [CAL_BEGIN] (will exit after a FULL cycle: idx0 → CAL_DONE)...")
got = 0
t0 = time.time()
saw_p1_idx0 = False
saw_p2_idx0 = False
while True:
    line = ser.readline().decode(errors="replace").strip()
    if not line:
        continue
    if "[CAL_BEGIN]" in line:
        print(f"BEGIN: {line}")
        t0 = time.time()
        got = 0
        continue
    if "[CAL_END_P1]" in line:
        dt = time.time() - t0 if t0 else 0
        print(f"--- Phase 1 END after {got} captures in {dt:.1f}s ---")
        continue
    if "[CAL_DONE]" in line:
        if saw_p1_idx0 and saw_p2_idx0:
            dt = time.time() - t0
            print(f"--- ALL DONE (full cycle): {got} captures in {dt:.1f}s ---")
            break
        else:
            print(f"--- CAL_DONE seen but no full cycle yet (P1_idx0={saw_p1_idx0} "
                  f"P2_idx0={saw_p2_idx0}), keep capturing next cycle ---")
            continue
    if "[CAL_END_P1]" in line:
        print(f"--- Phase 1 END (captures so far: {got}) ---")
        continue
    if line.startswith("[CAL2]"):
        parts = line.split()
        # [CAL2] idx C K B R
        if len(parts) >= 6:
            try:
                idx, c, k, b, r = (int(parts[i]) for i in (1, 2, 3, 4, 5))
            except ValueError:
                continue
            for _ in range(5):
                cap.grab()
            ok, frame = cap.retrieve()
            if ok:
                fn = os.path.join(OUT_DIR,
                                  f"cal2_{idx:04d}_C{c}_K{k:02d}_B{b:02d}_R{r:03d}.jpg")
                cv2.imwrite(fn, frame)
                got += 1
                if idx == 0:
                    saw_p2_idx0 = True
                    t0 = time.time()  # reset wall clock on fresh cycle start
                if got % 25 == 0 or idx < 5:
                    dt = time.time() - t0
                    rate = got / dt if dt > 0 else 0
                    eta = (EXPECTED - got) / rate if rate > 0 else 0
                    print(f"  P2 [{idx+1:4d}/{EXPECTED_P2}] R={r:03d} "
                          f"rate={rate:.2f}/s ETA={eta:.0f}s")
        continue
    if line.startswith("[CAL]"):
        parts = line.split()
        # [CAL] idx C K B
        if len(parts) >= 5:
            try:
                idx, c, k, b = int(parts[1]), int(parts[2]), int(parts[3]), int(parts[4])
            except ValueError:
                continue
            for _ in range(5):
                cap.grab()
            ok, frame = cap.retrieve()
            if ok:
                fn = os.path.join(OUT_DIR, f"cal_{idx:04d}_C{c}_K{k:02d}_B{b:02d}.jpg")
                cv2.imwrite(fn, frame)
                got += 1
                if idx == 0:
                    saw_p1_idx0 = True
                    t0 = time.time()  # reset wall clock on fresh cycle start
                if got % 50 == 0 or got < 5:
                    dt = time.time() - t0
                    rate = got / dt if dt > 0 else 0
                    eta = (EXPECTED - got) / rate if rate > 0 else 0
                    print(f"  P1 [{idx+1:4d}/{EXPECTED_P1}] C={c} K={k:02d} B={b:02d} "
                          f"rate={rate:.2f}/s ETA={eta:.0f}s")
            else:
                print(f"  CAM FAIL at idx={idx}")

cap.release()
ser.close()
print(f"saved {got} frames to {OUT_DIR}")
