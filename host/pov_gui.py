"""POV3D Streamer GUI.

Drop a .glb/.gltf/.obj/.ply file → auto-sample → compress → UART-stream.
Supports static (single frame) and animated (continuous resample) modes.
Auto-detects USB serial ports.

Usage:
  python pov_gui.py
"""
import os
import sys
import time
import math
import threading
import queue
import serial
import serial.tools.list_ports
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

# Make sibling imports work
HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from pointcloud_proto import pack_frame
from glb_to_points import sample_glb
from mesh_to_points import sample_mesh
from anim_loader import build_animator


# ---------------------------------------------------------------------- #
# Serial worker thread                                                   #
# ---------------------------------------------------------------------- #

class SerialWorker(threading.Thread):
    """Background thread: receives commands from UI queue, sends frames over UART."""
    def __init__(self, ui_log):
        super().__init__(daemon=True)
        self.ui_log = ui_log
        self.cmd_q = queue.Queue()
        self.ser = None
        self.running = True
        self.stream_state = None     # None or {points, animate, t0, fid}

    def open(self, port, baud):
        self.cmd_q.put(("open", port, baud))

    def close_port(self):
        self.cmd_q.put(("close",))

    def send_static(self, points):
        """Send a single frame, then stop streaming."""
        self.cmd_q.put(("static", points))

    def stream_animated(self, points, fps):
        """Legacy: stream with built-in breathing/rotation animation."""
        self.cmd_q.put(("stream", points, fps))

    def stream_animator(self, animator_fn, fps):
        """Stream using a generic f(t)→points animator (covers procedural,
        OBJ sequence, and glb keyframe modes)."""
        self.cmd_q.put(("stream2", animator_fn, fps))

    def stop_stream(self):
        self.cmd_q.put(("stop",))

    def shutdown(self):
        self.running = False
        self.cmd_q.put(("quit",))

    def _send_one(self, points, fid, compressed=True):
        if not self.ser or not self.ser.is_open:
            return
        try:
            buf = pack_frame(fid, points, compressed=compressed)
            self.ser.write(buf)
            self.ui_log(f"[tx] frame {fid}  {len(points)} pts  {len(buf)} B")
        except Exception as e:
            self.ui_log(f"[err] write: {e}")

    def _animate_pts(self, base_pts, t):
        # Y rotation 10s + breathing 5%
        ang = t * 2 * math.pi / 10.0
        ca = math.cos(ang); sa = math.sin(ang)
        scale = 1.0 + 0.05 * math.sin(t * 2 * math.pi / 3.0)
        out = []
        for (x, y, z, r, g, b) in base_pts:
            rx = x * ca - z * sa
            rz = x * sa + z * ca
            nx = max(-127, min(127, int(rx * scale)))
            ny = max(-127, min(127, int(y * scale)))
            nz = max(-127, min(127, int(rz * scale)))
            out.append((nx, ny, nz, r, g, b))
        return out

    def run(self):
        last_send = 0.0
        while self.running:
            # Check for new command (non-blocking with timeout)
            try:
                cmd = self.cmd_q.get(timeout=0.05)
            except queue.Empty:
                cmd = None

            if cmd:
                op = cmd[0]
                if op == "open":
                    if self.ser:
                        try: self.ser.close()
                        except: pass
                    try:
                        self.ser = serial.Serial(cmd[1], cmd[2], timeout=0)
                        self.ui_log(f"[port] opened {cmd[1]} @ {cmd[2]}")
                    except Exception as e:
                        self.ui_log(f"[err] open: {e}")
                        self.ser = None
                elif op == "close":
                    if self.ser:
                        try: self.ser.close()
                        except: pass
                        self.ser = None
                        self.ui_log("[port] closed")
                elif op == "static":
                    self.stream_state = None
                    self._send_one(cmd[1], 0)
                elif op == "stream":
                    points = cmd[1]
                    fps = cmd[2]
                    self.stream_state = {
                        "base": points,
                        "animator": None,
                        "period": 1.0 / fps,
                        "t0": time.time(),
                        "fid": 0,
                    }
                    self.ui_log(f"[stream] start  N={len(points)}  {fps:.2f} FPS")
                elif op == "stream2":
                    fn = cmd[1]
                    fps = cmd[2]
                    self.stream_state = {
                        "base": None,
                        "animator": fn,
                        "period": 1.0 / fps,
                        "t0": time.time(),
                        "fid": 0,
                    }
                    self.ui_log(f"[stream] animator-mode  {fps:.2f} FPS")
                elif op == "stop":
                    self.stream_state = None
                    self.ui_log("[stream] stopped")
                elif op == "quit":
                    break

            # Drain RX so it doesn't fill in OS buffer.
            # Board fires ~90 FPS of telemetry — drop chatty lines to keep UI alive.
            if self.ser:
                try:
                    data = self.ser.read(4096)
                    if data:
                        try:
                            text = data.decode("ascii", errors="replace")
                            for line in text.split("\n"):
                                line = line.strip()
                                if not line:
                                    continue
                                # filter out high-rate telemetry; surface errors/tx
                                low = line.lower()
                                if (low.startswith("slot ") or
                                    low.startswith("frame=") or
                                    low.startswith("vdma ") or
                                    low.startswith("r=") or
                                    "park" in low and "curr" in low):
                                    continue
                                self.ui_log(f"[board] {line}")
                        except Exception:
                            pass
                except Exception:
                    pass

            # Animated stream
            if self.stream_state and self.ser and self.ser.is_open:
                now = time.time()
                ss = self.stream_state
                if (now - ss["t0"]) - ss["fid"] * ss["period"] >= ss["period"]:
                    t_elapsed = now - ss["t0"]
                    if ss.get("animator"):
                        pts = ss["animator"](t_elapsed)
                    else:
                        pts = self._animate_pts(ss["base"], t_elapsed)
                    ss["fid"] += 1
                    self._send_one(pts, ss["fid"])
        if self.ser:
            try: self.ser.close()
            except: pass


# ---------------------------------------------------------------------- #
# UI                                                                     #
# ---------------------------------------------------------------------- #

class POVGUI:
    def __init__(self, root):
        self.root = root
        root.title("POV3D Streamer")
        root.geometry("760x560")

        self.points = None     # current sampled point list (used by static send)
        self.animator = None   # f(t)→points (used by animated stream)
        self.glb_path = None

        # Top: file pick
        f1 = ttk.Frame(root, padding=8)
        f1.pack(fill=tk.X)
        ttk.Label(f1, text="Model:").pack(side=tk.LEFT)
        self.path_var = tk.StringVar(value="(no file)")
        ttk.Label(f1, textvariable=self.path_var, width=60).pack(side=tk.LEFT, padx=4)
        ttk.Button(f1, text="Open .glb/.obj/.ply…", command=self._pick_file).pack(side=tk.LEFT)

        # Sampling parameters
        f2 = ttk.LabelFrame(root, text="Sampling", padding=8)
        f2.pack(fill=tk.X, padx=8, pady=4)
        self.points_var = tk.IntVar(value=32000)
        self.scale_var = tk.IntVar(value=40)
        self.brighten_var = tk.DoubleVar(value=1.0)
        self.gamma_var = tk.DoubleVar(value=1.0)
        self.color_var = tk.StringVar(value="keep")
        self.lighting_var = tk.StringVar(value="studio")
        self.ambient_var = tk.DoubleVar(value=0.3)
        self.zstretch_var = tk.DoubleVar(value=1.5)
        ttk.Label(f2, text="Points:").grid(row=0, column=0, sticky=tk.W)
        ttk.Spinbox(f2, from_=100, to=20000, increment=500, textvariable=self.points_var, width=8).grid(row=0, column=1)
        ttk.Label(f2, text="Scale:").grid(row=0, column=2, sticky=tk.W, padx=(12, 0))
        ttk.Spinbox(f2, from_=10, to=80, textvariable=self.scale_var, width=6).grid(row=0, column=3)
        ttk.Label(f2, text="Color:").grid(row=0, column=4, sticky=tk.W, padx=(12, 0))
        ttk.Combobox(f2, textvariable=self.color_var,
                     values=["keep", "uniform", "height", "random"],
                     width=8, state="readonly").grid(row=0, column=5)
        ttk.Label(f2, text="Brighten:").grid(row=1, column=0, sticky=tk.W, pady=(4, 0))
        ttk.Spinbox(f2, from_=0.5, to=4.0, increment=0.1, textvariable=self.brighten_var, width=6).grid(row=1, column=1, pady=(4, 0))
        ttk.Label(f2, text="Gamma:").grid(row=1, column=2, sticky=tk.W, padx=(12, 0), pady=(4, 0))
        ttk.Spinbox(f2, from_=0.3, to=2.0, increment=0.05, textvariable=self.gamma_var, width=6).grid(row=1, column=3, pady=(4, 0))
        ttk.Label(f2, text="Lighting:").grid(row=2, column=0, sticky=tk.W, pady=(4, 0))
        ttk.Combobox(f2, textvariable=self.lighting_var,
                     values=["none", "lambert", "half-lambert", "studio"],
                     width=12, state="readonly").grid(row=2, column=1, columnspan=2, sticky=tk.W, pady=(4, 0))
        ttk.Label(f2, text="Ambient:").grid(row=2, column=3, sticky=tk.E, padx=(12, 0), pady=(4, 0))
        ttk.Spinbox(f2, from_=0.0, to=1.0, increment=0.05, textvariable=self.ambient_var, width=6).grid(row=2, column=4, sticky=tk.W, pady=(4, 0))
        ttk.Label(f2, text="Z-stretch:").grid(row=3, column=0, sticky=tk.W, pady=(4, 0))
        ttk.Spinbox(f2, from_=1.0, to=8.0, increment=0.5, textvariable=self.zstretch_var, width=6).grid(row=3, column=1, sticky=tk.W, pady=(4, 0))
        ttk.Button(f2, text="Re-sample", command=self._resample).grid(row=3, column=5, padx=(12, 0), pady=(4, 0))

        # Serial port
        f3 = ttk.LabelFrame(root, text="Serial", padding=8)
        f3.pack(fill=tk.X, padx=8, pady=4)
        self.port_var = tk.StringVar()
        ttk.Label(f3, text="Port:").pack(side=tk.LEFT)
        self.port_combo = ttk.Combobox(f3, textvariable=self.port_var, width=12, state="readonly")
        self.port_combo.pack(side=tk.LEFT, padx=4)
        ttk.Button(f3, text="↻ Detect", command=self._refresh_ports).pack(side=tk.LEFT)
        self.baud_var = tk.IntVar(value=921600)
        ttk.Label(f3, text="Baud:").pack(side=tk.LEFT, padx=(12, 4))
        ttk.Combobox(f3, textvariable=self.baud_var, width=8, state="readonly",
                     values=[9600, 115200, 230400, 460800, 921600]).pack(side=tk.LEFT)
        ttk.Button(f3, text="Open", command=self._open_port).pack(side=tk.LEFT, padx=8)
        ttk.Button(f3, text="Close", command=self._close_port).pack(side=tk.LEFT)

        # Stream control
        f4 = ttk.LabelFrame(root, text="Stream", padding=8)
        f4.pack(fill=tk.X, padx=8, pady=4)
        self.fps_var = tk.DoubleVar(value=0.3)
        ttk.Button(f4, text="Send static (1 frame)", command=self._send_static).pack(side=tk.LEFT, padx=4)
        ttk.Label(f4, text="FPS:").pack(side=tk.LEFT, padx=(12, 4))
        ttk.Spinbox(f4, from_=0.1, to=5.0, increment=0.1, textvariable=self.fps_var, width=6).pack(side=tk.LEFT)
        ttk.Button(f4, text="Start animated stream", command=self._start_stream).pack(side=tk.LEFT, padx=8)
        ttk.Button(f4, text="Stop stream", command=self._stop_stream).pack(side=tk.LEFT)

        # Log area
        f5 = ttk.LabelFrame(root, text="Log", padding=4)
        f5.pack(fill=tk.BOTH, expand=True, padx=8, pady=4)
        self.log_text = tk.Text(f5, height=14, font=("Consolas", 9))
        self.log_text.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        sb = ttk.Scrollbar(f5, command=self.log_text.yview)
        sb.pack(side=tk.RIGHT, fill=tk.Y)
        self.log_text.config(yscrollcommand=sb.set, state=tk.DISABLED)

        # File log mirror (overwrite on each session, so the file always
        # holds the latest run — easy to read externally).
        log_path = os.path.join(HERE, "pov_gui.log")
        try:
            self._log_file = open(log_path, "w", encoding="utf-8", buffering=1)
            self._log_file.write(f"=== pov_gui session start, log: {log_path} ===\n")
        except Exception as e:
            print(f"[warn] could not open log file: {e}")
            self._log_file = open(os.devnull, "w")

        # Worker
        self.worker = SerialWorker(self._log_threadsafe)
        self.worker.start()

        self._refresh_ports()

        root.protocol("WM_DELETE_WINDOW", self._on_close)

    # ----- helpers -----
    def _log(self, msg):
        self.log_text.config(state=tk.NORMAL)
        self.log_text.insert(tk.END, msg + "\n")
        # Cap at ~500 lines so years-long sessions don't bloat Text widget
        line_count = int(self.log_text.index("end-1c").split(".")[0])
        if line_count > 500:
            self.log_text.delete("1.0", f"{line_count - 500}.0")
        self.log_text.see(tk.END)
        self.log_text.config(state=tk.DISABLED)
        # Mirror to file so external tools (or Claude) can tail the session log.
        try:
            self._log_file.write(msg + "\n")
            self._log_file.flush()
        except Exception:
            pass

    def _log_threadsafe(self, msg):
        self.root.after(0, self._log, msg)

    def _refresh_ports(self):
        ports = [p.device for p in serial.tools.list_ports.comports()]
        self.port_combo["values"] = ports
        if ports and not self.port_var.get():
            # prefer non-Intel-MEI (SOL) ports
            preferred = [p for p in ports
                         if "COM" in p and not "SOL" in p.upper()]
            self.port_var.set((preferred or ports)[0])
        self._log(f"detected ports: {ports}")

    def _open_port(self):
        if not self.port_var.get():
            messagebox.showerror("Error", "No port selected")
            return
        self.worker.open(self.port_var.get(), self.baud_var.get())

    def _close_port(self):
        self.worker.close_port()

    def _pick_file(self):
        path = filedialog.askopenfilename(
            title="Choose a 3D model",
            filetypes=[("3D model", "*.glb *.gltf *.obj *.ply"),
                       ("All files", "*")])
        if not path:
            return
        self.glb_path = path
        self.path_var.set(os.path.basename(path))
        self._resample()

    def _resample(self):
        if not self.glb_path:
            messagebox.showinfo("Info", "Pick a model first")
            return
        if getattr(self, "_sampling", False):
            self._log("sampling already in progress; ignored")
            return
        # Snapshot params now (UI vars may change during background work).
        path = self.glb_path
        n = self.points_var.get()
        scale = self.scale_var.get()
        color = self.color_var.get()
        brighten = self.brighten_var.get()
        gamma = self.gamma_var.get()
        lighting = self.lighting_var.get()
        ambient = self.ambient_var.get()
        z_stretch = self.zstretch_var.get()
        self._sampling = True
        self._log(f"sampling {n} pts from {os.path.basename(path)}…")

        def work():
            try:
                ext = os.path.splitext(path)[1].lower()
                # Build animator first; for static-only models its t=0 sample
                # is a fine source of `self.points`, so we avoid sampling twice.
                animator = build_animator(
                    path, n_points=n, target_scale=scale,
                    color_mode=color, brighten=brighten, gamma=gamma,
                    lighting=lighting, ambient=ambient,
                    z_stretch=z_stretch,
                    fallback_period_y=10.0)
                pts = animator(0.0)

                def done():
                    self.points = pts
                    self.animator = animator
                    self._log(f"  → {len(pts)} points sampled, animator ready")
                    self._sampling = False
                self.root.after(0, done)
            except Exception as e:
                msg = str(e)
                def fail():
                    self._sampling = False
                    self._log(f"[err] sampling: {msg}")
                    messagebox.showerror("Sampling failed", msg)
                self.root.after(0, fail)

        threading.Thread(target=work, daemon=True).start()

    def _send_static(self):
        if not self.points:
            messagebox.showinfo("Info", "Sample model first (open a file)")
            return
        self.worker.send_static(self.points)

    def _start_stream(self):
        if not self.animator:
            messagebox.showinfo("Info", "Sample model first")
            return
        # Pass the animator function to the worker
        self.worker.stream_animator(self.animator, self.fps_var.get())

    def _stop_stream(self):
        self.worker.stop_stream()

    def _on_close(self):
        self.worker.shutdown()
        try: self._log_file.close()
        except Exception: pass
        self.root.destroy()


if __name__ == "__main__":
    root = tk.Tk()
    app = POVGUI(root)
    root.mainloop()
