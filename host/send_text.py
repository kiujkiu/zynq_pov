"""send_text.py - PoC host sender sending text frames to Zynq over serial.

Zynq side (hello_world.c) receives bytes via UART RX poll and renders to HDMI
via VDMA framebuffer. This script:
  1. Opens COM port (default COM2 at 115200)
  2. Every 2s, clears screen with '\\r' + spaces and draws a "dashboard"
     showing counter, timestamp, a bouncing char.
  3. Exits on Ctrl+C.

Install:    pip install pyserial
Usage:      python send_text.py               (defaults to COM2, 115200)
            python send_text.py COM3 921600   (override)
"""
import sys, time, datetime
try:
    import serial
except ImportError:
    print("Install pyserial:  pip install pyserial")
    sys.exit(1)


def pad(s: str, w: int) -> str:
    s = s[:w]
    return s + ' ' * (w - len(s))


def main():
    port = sys.argv[1] if len(sys.argv) > 1 else "COM2"
    baud = int(sys.argv[2]) if len(sys.argv) > 2 else 115200
    print(f"opening {port} @ {baud}...")
    ser = serial.Serial(port, baud, timeout=0.1)
    time.sleep(0.3)

    # Send a clear: board's console treats '\\r' as CR (move cursor to col 0).
    # To fully clear we need to overwrite 45 rows × 106 cols.
    # Simpler: just send a formatted dashboard that repaints each cycle.

    tick = 0
    bouncer = 0
    bounce_dir = 1
    WIDTH = 60

    try:
        # Initial clear (send 45 lines of blanks)
        ser.write(b'\r\n' * 2 + b'=== HOST FEED STARTED ===\r\n')
        ser.flush()
        time.sleep(0.5)

        while True:
            now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            bar = (' ' * bouncer) + '<====>' + (' ' * (WIDTH - bouncer - 6))
            payload = (
                f"\r\n"
                f"POV-3D host-to-board PoC\r\n"
                f"host time : {now}\r\n"
                f"tick      : {tick:10d}\r\n"
                f"baud      : {baud}\r\n"
                f"bouncer   : |{bar}|\r\n"
                f"(demo: each 2s the host sends a dashboard via UART)\r\n"
                f">>> "
            )
            ser.write(payload.encode('ascii', errors='ignore'))
            ser.flush()
            print(f"tick={tick} sent {len(payload)}B")

            tick += 1
            bouncer += bounce_dir
            if bouncer <= 0 or bouncer >= WIDTH - 6:
                bounce_dir = -bounce_dir
            time.sleep(2.0)

    except KeyboardInterrupt:
        print("\nstopped by user")
    finally:
        ser.close()


if __name__ == "__main__":
    main()
