"""send_72_slices.py - 发 72 个测试切片到板子网格 (Task #8 Stage 3)

协议: \\xAA \\x04 <slice_id> <106*120*3 BGR>
每片 106x120 对应 5° 角度 (slice_id 0..71 → angle 0..355)
"""
import sys, time, struct, math, threading, subprocess, colorsys
try:
    import serial
except ImportError:
    print("pip install pyserial"); sys.exit(1)

PORT = sys.argv[1] if len(sys.argv) > 1 else "COM7"
BAUD = int(sys.argv[2]) if len(sys.argv) > 2 else 115200
W, H = 106, 120
NUM_SLICES = 72
ESC = 0xAA

# 5x7 font bitmaps (subset: digits + letters we need)
FONT = {
    '0': [0x3E,0x51,0x49,0x45,0x3E], '1': [0x00,0x42,0x7F,0x40,0x00],
    '2': [0x42,0x61,0x51,0x49,0x46], '3': [0x21,0x41,0x45,0x4B,0x31],
    '4': [0x18,0x14,0x12,0x7F,0x10], '5': [0x27,0x45,0x45,0x45,0x39],
    '6': [0x3C,0x4A,0x49,0x49,0x30], '7': [0x01,0x71,0x09,0x05,0x03],
    '8': [0x36,0x49,0x49,0x49,0x36], '9': [0x06,0x49,0x49,0x29,0x1E],
    ' ': [0,0,0,0,0], ':': [0,0x36,0x36,0,0], 'o': [0x38,0x44,0x44,0x44,0x38],
    'd': [0x38,0x44,0x44,0x48,0x7F], 'e': [0x38,0x54,0x54,0x54,0x18],
    'g': [0x0C,0x52,0x52,0x52,0x3E], '.': [0,0x60,0x60,0,0],
}

def draw_char(buf, w, h, x, y, ch, col_bgr, scale=2):
    bits = FONT.get(ch, FONT[' '])
    for cx in range(5):
        for cy in range(7):
            if bits[cx] & (1 << cy):
                for dy in range(scale):
                    for dx in range(scale):
                        px = x + cx*scale + dx
                        py = y + cy*scale + dy
                        if 0 <= px < w and 0 <= py < h:
                            i = (py*w + px) * 3
                            buf[i]   = col_bgr[0]
                            buf[i+1] = col_bgr[1]
                            buf[i+2] = col_bgr[2]

def draw_text(buf, w, h, x, y, s, col, scale=2):
    cx = x
    for ch in s:
        draw_char(buf, w, h, cx, y, ch, col, scale)
        cx += (5 + 1) * scale

def make_slice(slice_id):
    """Generate 106x120 BGR bytearray for slice_id 0..71."""
    angle = slice_id * 5
    # HSV color wheel: hue based on angle, full saturation, mid value
    hue = angle / 360.0
    r, g, b = colorsys.hsv_to_rgb(hue, 0.8, 0.7)
    bg_bgr = (int(b*255), int(g*255), int(r*255))

    buf = bytearray(W * H * 3)
    # fill bg color
    for i in range(W * H):
        buf[i*3]   = bg_bgr[0]
        buf[i*3+1] = bg_bgr[1]
        buf[i*3+2] = bg_bgr[2]

    # draw border
    for x in range(W):
        buf[(0*W+x)*3:(0*W+x)*3+3] = bytes([255,255,255])
        buf[((H-1)*W+x)*3:((H-1)*W+x)*3+3] = bytes([255,255,255])
    for y in range(H):
        buf[(y*W+0)*3:(y*W+0)*3+3] = bytes([255,255,255])
        buf[(y*W+(W-1))*3:(y*W+(W-1))*3+3] = bytes([255,255,255])

    # slice id (big, white)
    white = (255, 255, 255)
    draw_text(buf, W, H, 5, 8, f"{slice_id:02d}", white, scale=4)
    # angle (smaller)
    draw_text(buf, W, H, 5, 60, f"{angle:03d}deg", white, scale=2)

    # dial: draw a line radiating at this angle from center
    cx_, cy_ = W//2, H//2 + 20
    for r in range(30):
        rad = math.radians(angle - 90)  # -90 so 0deg points up
        dx = int(r * math.cos(rad))
        dy = int(r * math.sin(rad))
        px = cx_ + dx
        py = cy_ + dy
        if 0 <= px < W and 0 <= py < H:
            i = (py*W + px) * 3
            buf[i]   = 0
            buf[i+1] = 0
            buf[i+2] = 0

    return bytes(buf)

def main():
    print(f"Opening {PORT} @ {BAUD}...")
    ser = serial.Serial(PORT, BAUD, timeout=1.0)
    time.sleep(0.3)

    print(f"Sending CLEAR...")
    ser.write(bytes([ESC, 0x01])); ser.flush()
    time.sleep(1.0)

    total = 0
    t_start = time.time()
    for n in range(NUM_SLICES):
        payload = make_slice(n)
        packet = bytes([ESC, 0x04, n]) + payload
        t0 = time.time()
        ser.write(packet); ser.flush()
        elapsed = time.time() - t0
        total += len(packet)
        print(f"  [{n+1:2d}/{NUM_SLICES}] slice_id={n:2d} angle={n*5:03d}° "
              f"sent {len(packet)}B in {elapsed:.2f}s")
    t_total = time.time() - t_start
    print(f"\n✓ all {NUM_SLICES} sent in {t_total:.1f}s "
          f"({total/1024:.1f}KB total, avg {total/t_total/1024:.1f}KB/s)")
    ser.close()

if __name__ == "__main__":
    main()
