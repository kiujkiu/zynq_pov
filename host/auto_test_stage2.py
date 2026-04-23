"""auto_test_stage2.py — 全自动跑 Stage 2 测试
1) 开 COM2 后台读线程 (所有串口数据打印到 stdout)
2) XSDB 下 elf 到板子启动
3) 发 clear + 3 个切片 + 20 像素
4) 打印汇总
"""
import sys, time, threading, subprocess, struct, math
try:
    import serial
except ImportError:
    print("pip install pyserial"); sys.exit(1)

PORT = sys.argv[1] if len(sys.argv) > 1 else "COM2"
BAUD = int(sys.argv[2]) if len(sys.argv) > 2 else 115200

XSDB = r"D:\Vitis\2024.2\bin\xsdb.bat"
DL_TCL = r"D:\workspace\zynq_pov\tools\dl_helloworld.tcl"

ESC = 0xAA
W, H = 160, 180

rx_lines = []
stop_reader = False

def reader_thread(ser):
    buf = b''
    while not stop_reader:
        data = ser.read(256)
        if data:
            buf += data
            while b'\n' in buf:
                line, buf = buf.split(b'\n', 1)
                s = line.decode('latin-1', errors='replace').rstrip('\r')
                rx_lines.append(s)
                print(f"[BOARD] {s}")
        else:
            time.sleep(0.01)

def pack_clear():
    return bytes([ESC, 0x01])

def pack_pixel(x, y, r, g, b):
    return bytes([ESC, 0x02]) + struct.pack('<HH', x, y) + bytes([r, g, b])

def pack_blit(x0, y0, w, h, pixels_bgr):
    return bytes([ESC, 0x03]) + struct.pack('<HHHH', x0, y0, w, h) + pixels_bgr

def make_slice(w, h, frame):
    pixels = bytearray(w * h * 3)
    cx = w // 2 + int(w / 4 * math.sin(frame * 0.3))
    cy = h // 2 + int(h / 4 * math.cos(frame * 0.3))
    R2 = (min(w, h) // 4) ** 2
    i = 0
    for y in range(h):
        for x in range(w):
            r = x * 255 // w
            g = y * 255 // h
            dx = x - cx; dy = y - cy
            b = 255 if (dx*dx + dy*dy) < R2 else 0
            pixels[i]   = b
            pixels[i+1] = g
            pixels[i+2] = r
            i += 3
    return bytes(pixels)

def main():
    global stop_reader
    print(f"Opening {PORT} @ {BAUD}...")
    ser = serial.Serial(PORT, BAUD, timeout=0.2)
    t = threading.Thread(target=reader_thread, args=(ser,), daemon=True)
    t.start()

    print("\n=== 1. Download elf via XSDB ===")
    r = subprocess.run([XSDB, DL_TCL], capture_output=True, text=True, timeout=120)
    print("xsdb stdout tail:")
    for line in r.stdout.splitlines()[-10:]:
        print("  ", line)
    if r.returncode != 0:
        print(f"XSDB failed rc={r.returncode}"); stop_reader = True; return

    print("\n=== 2. Wait 8s for board init ===")
    time.sleep(8)

    print("\n=== 3. Send CLEAR ===")
    ser.write(pack_clear()); ser.flush()
    time.sleep(1.5)

    print("\n=== 4. Send 3 blit slices ===")
    for frame in range(3):
        x0 = 100 + frame * 250
        y0 = 100
        payload = make_slice(W, H, frame)
        packet = pack_blit(x0, y0, W, H, payload)
        start = time.time()
        ser.write(packet); ser.flush()
        elapsed = time.time() - start
        kbps = len(packet) / elapsed / 1024 if elapsed > 0 else 0
        print(f"  [{frame+1}/3] sent {len(packet)}B at ({x0},{y0}) in {elapsed:.2f}s ({kbps:.1f}KB/s)")
        # Wait for "blit done" from board
        wait_start = time.time()
        while time.time() - wait_start < 15:
            if any('blit done' in l for l in rx_lines[-10:]):
                rx_lines.append(None)  # marker so next check only sees newer
                break
            time.sleep(0.1)

    print("\n=== 5. Send 20 magenta pixels ===")
    for i in range(20):
        pkt = pack_pixel(1000 + i*5, 500 + (i%5)*3, 255, 0, 255)
        ser.write(pkt)
    ser.flush()
    time.sleep(2)

    print("\n=== 6. Done. Check HDMI. Waiting 3s for final prints ===")
    time.sleep(3)
    stop_reader = True
    t.join(timeout=1)
    ser.close()
    print(f"\nTotal board lines captured: {len(rx_lines)}")

if __name__ == "__main__":
    main()
