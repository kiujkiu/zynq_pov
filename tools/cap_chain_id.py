"""Auto-capture 1 frame per chain (0..8) using UART sync.

Firmware mode_chain_id prints "[chain_id] now lighting chain N (CL)" on each
transition. We catch each line, wait 1s for panel to settle, grab one fresh
frame, save as chain_N_CC.jpg.
"""
import sys, os, time, cv2, serial, re

PORT    = sys.argv[1] if len(sys.argv) > 1 else "COM5"
CAM_IDX = int(sys.argv[2]) if len(sys.argv) > 2 else 1
OUT_DIR = r"D:\workspace\zynq_pov\tools\calib_out"
os.makedirs(OUT_DIR, exist_ok=True)

PAT = re.compile(r"chain (\d+) \((\w+)\)")

ser = serial.Serial(PORT, 921600, timeout=5.0)
cap = cv2.VideoCapture(CAM_IDX, cv2.CAP_MSMF)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
for _ in range(5):
    cap.read(); time.sleep(0.05)
print(f"UART {PORT}, cam {CAM_IDX}, out {OUT_DIR}")

seen = set()
deadline = time.time() + 35  # 9 chains × 3s + slack
while len(seen) < 9 and time.time() < deadline:
    line = ser.readline().decode(errors="replace").strip()
    if not line:
        continue
    m = PAT.search(line)
    if not m:
        continue
    cn, label = int(m[1]), m[2]
    if cn in seen:
        continue
    # Wait 1s after announce for panel to fully stabilize
    time.sleep(1.0)
    for _ in range(5):
        cap.grab()
    ok, frame = cap.retrieve()
    if ok:
        fn = os.path.join(OUT_DIR, f"chain_{cn}_{label}.jpg")
        cv2.imwrite(fn, frame)
        seen.add(cn)
        print(f"  captured chain {cn} ({label}) → {fn}")
    else:
        print(f"  cam fail chain {cn}")
cap.release()
ser.close()
print(f"\ngot {len(seen)}/9 chains")
