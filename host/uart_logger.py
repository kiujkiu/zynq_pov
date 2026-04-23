"""Continuously read COM7 and append to D:\\workspace\\zynq_pov\\uart.log.
Shared view: run this once in background; everyone tails the log file.
Ctrl-C to stop. Re-opens on disconnect."""
import serial, time, sys, os

PORT = "COM7"
BAUD = 115200
LOG  = r"D:\workspace\zynq_pov\uart.log"

def open_port():
    while True:
        try:
            s = serial.Serial(PORT, BAUD, timeout=0.2)
            print(f"[logger] opened {PORT}@{BAUD}", flush=True)
            return s
        except Exception as e:
            print(f"[logger] open failed: {e}; retry in 2s", flush=True)
            time.sleep(2)

ser = open_port()
with open(LOG, "a", buffering=1) as f:
    f.write(f"\n=== logger start {time.strftime('%Y-%m-%d %H:%M:%S')} ===\n")
    while True:
        try:
            d = ser.read(1024)
            if d:
                # Write raw bytes interpreted as ascii; keep line endings.
                try:
                    text = d.decode('ascii', errors='replace')
                except:
                    text = str(d)
                f.write(text)
                f.flush()
                sys.stdout.write(text)
                sys.stdout.flush()
        except serial.SerialException as e:
            print(f"[logger] serial lost: {e}; reopening", flush=True)
            try: ser.close()
            except: pass
            time.sleep(1)
            ser = open_port()
        except KeyboardInterrupt:
            break
print("[logger] exit", flush=True)
