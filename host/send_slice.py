"""send_slice.py — 主机端切片发送器 (Task #8 Stage 2)

协议:
  \\xAA \\x01             : clear framebuffer
  \\xAA \\x02 <xxYY RGB>  : set pixel
  \\xAA \\x03 <x0 y0 w h BGR*w*h> : blit rect

用法:
  python send_slice.py [COMx] [baud]
默认 COM2 115200.

演示:
  1. 先清屏
  2. 发 160x180 测试切片 (彩色渐变 + 动态圆) 5 轮, 每轮位置移动
"""
import sys, time, struct, math

try:
    import serial
except ImportError:
    print("pip install pyserial"); sys.exit(1)

ESC = 0xAA
CMD_CLEAR = 0x01
CMD_PIXEL = 0x02
CMD_BLIT  = 0x03


def pack_clear() -> bytes:
    return bytes([ESC, CMD_CLEAR])


def pack_pixel(x, y, r, g, b) -> bytes:
    return bytes([ESC, CMD_PIXEL]) + struct.pack('<HH', x, y) + bytes([r, g, b])


def pack_blit(x0, y0, w, h, pixels_bgr) -> bytes:
    """pixels_bgr: w*h*3 bytes, BGR order."""
    header = bytes([ESC, CMD_BLIT]) + struct.pack('<HHHH', x0, y0, w, h)
    return header + pixels_bgr


def make_slice(w: int, h: int, frame: int) -> bytes:
    """测试切片: 横向红渐变 + 纵向绿渐变 + 中心动态蓝圆圈 (帧变化)."""
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
            # BGR order!
            pixels[i]   = b
            pixels[i+1] = g
            pixels[i+2] = r
            i += 3
    return bytes(pixels)


def main():
    port = sys.argv[1] if len(sys.argv) > 1 else "COM2"
    baud = int(sys.argv[2]) if len(sys.argv) > 2 else 115200
    W, H = 160, 180

    print(f"open {port} @ {baud}...")
    ser = serial.Serial(port, baud, timeout=1.0)
    time.sleep(0.3)

    # 1. 清屏
    print("[1] clear...")
    ser.write(pack_clear())
    ser.flush()
    time.sleep(0.5)

    # 2. 发 1 个切片到屏幕中央附近
    for frame in range(3):
        x0 = 100 + frame * 200   # 100, 300, 500
        y0 = 100
        payload = make_slice(W, H, frame)
        packet = pack_blit(x0, y0, W, H, payload)
        start = time.time()
        ser.write(packet)
        ser.flush()
        elapsed = time.time() - start
        print(f"[{frame+1}/3] blit {W}x{H} at ({x0},{y0}) "
              f"size={len(packet)}B time={elapsed:.2f}s "
              f"rate={len(packet)/elapsed/1024:.1f}KB/s")
        time.sleep(1.0)  # 给板子时间吃数据

    # 3. 加几个单点像素示范
    print("[end] scatter pixels...")
    for i in range(20):
        pkt = pack_pixel(1000 + i*5, 500 + (i%5)*3, 255, 0, 255)  # magenta
        ser.write(pkt)
    ser.flush()

    ser.close()
    print("done.")


if __name__ == "__main__":
    main()
