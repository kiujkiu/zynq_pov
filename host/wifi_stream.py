"""WiFi streaming framework for POV3D (Phase 9 stub, no hardware).

Mirrors the contract of `test_send_mesh.py` / `anime_stream.py` but writes to
a TCP socket instead of `serial.Serial`. The far end can be:

  1. ESP32 bridge (esp32_bridge/firmware/main/pov_bridge.c) which transparently
     forwards bytes to UART on the Zynq side. In this mode we only emit raw
     PMSH / PPCL frames — no PWFR wrapping needed, board sees the same wire as
     today over UART.
  2. A future Zynq-direct lwIP listener which understands the PWFR session
     header (see docs/wifi_protocol.md). We add PWFR around payloads when
     `mode != "passthrough"`.

This file deliberately does NOT call socket.connect() at import time; nothing
runs without an explicit `WifiStream("host", port).open()`. Until ESP32 / lwIP
hardware is up, callers should pass `dry_run=True` and inspect the framed
bytes via `WifiStream.last_buf`.

Usage examples (none of these run today — placeholders):

    from wifi_stream import WifiStream
    from mesh_proto import pack_mesh_v3

    # ESP32 bridge passthrough (today's wire)
    s = WifiStream("pov-bridge.local", 8888, mode="passthrough")
    s.open()
    s.send(pack_mesh_v3(0, verts, tris, tex, w, h))
    s.close()

    # Future Zynq-direct, wrapped in PWFR
    s = WifiStream("192.168.1.42", 8080, mode="pwfr")
    s.open()
    s.send_msg(MSG_FULL_PMSH, pack_mesh_v3(...))
    s.send_msg(MSG_PHASE, struct.pack("<II", phase_q16_16, frame_id))
    s.close()
"""

from __future__ import annotations

import socket
import struct
import time
import zlib
from typing import Optional


# ----------------------------------------------------------------------------
# PWFR session header (see docs/wifi_protocol.md §3.1)
# ----------------------------------------------------------------------------
PWFR_MAGIC = struct.unpack("<I", b"PWFR")[0]   # 0x52465750
PWFR_VER = 1
PWFR_HDR_FMT = "<IHHIIIHH"   # magic, ver, type, seq, len, crc, ack_seq, rsvd
PWFR_HDR_SIZE = struct.calcsize(PWFR_HDR_FMT)
assert PWFR_HDR_SIZE == 24, PWFR_HDR_SIZE


# msg_type values — keep in sync with docs/wifi_protocol.md §3.2 + board stub
MSG_PING        = 0x0001
MSG_PONG        = 0x0002
MSG_FULL_PMSH   = 0x0010
MSG_FULL_PPCL   = 0x0011
MSG_FULL_VOXEL  = 0x0012
MSG_DELTA_VOXEL = 0x0020
MSG_PHASE       = 0x0030
MSG_MODE        = 0x0040
MSG_ACK         = 0x0080
MSG_NAK         = 0x0081
MSG_FPS         = 0x0090


def pwfr_pack(msg_type: int, payload: bytes, seq: int = 0,
              ack_seq: int = 0) -> bytes:
    """Wrap one payload in a PWFR header. CRC32 computed over payload only."""
    crc = zlib.crc32(payload) & 0xFFFFFFFF
    hdr = struct.pack(PWFR_HDR_FMT, PWFR_MAGIC, PWFR_VER, msg_type & 0xFFFF,
                      seq & 0xFFFFFFFF, len(payload), crc,
                      ack_seq & 0xFFFF, 0)
    return hdr + payload


def pwfr_unpack(buf: bytes):
    """Parse a single PWFR frame from the head of `buf`. Returns
    (msg_type, seq, payload, ack_seq, consumed_bytes) or raises ValueError.
    Caller is responsible for chunked reads / partial frames."""
    if len(buf) < PWFR_HDR_SIZE:
        raise ValueError("short header")
    (magic, ver, mtype, seq, plen, crc, ack_seq, _) = struct.unpack(
        PWFR_HDR_FMT, buf[:PWFR_HDR_SIZE])
    if magic != PWFR_MAGIC:
        raise ValueError(f"bad magic {magic:#x}")
    if ver != PWFR_VER:
        raise ValueError(f"unsupported ver {ver}")
    total = PWFR_HDR_SIZE + plen
    if len(buf) < total:
        raise ValueError("short body")
    payload = buf[PWFR_HDR_SIZE:total]
    if zlib.crc32(payload) & 0xFFFFFFFF != crc:
        raise ValueError("crc mismatch")
    return mtype, seq, payload, ack_seq, total


# ----------------------------------------------------------------------------
# WifiStream — TCP client framework
# ----------------------------------------------------------------------------
class WifiStream:
    """TCP client to ESP32 bridge or Zynq-direct lwIP listener.

    Intentionally does NOT use the `serial.Serial` API verbatim, but exposes
    `write/read/close` so existing callers (test_send_mesh.py etc.) only need
    a `Stream = WifiStream(...)` substitution.
    """

    def __init__(self, host: str, port: int = 8888, mode: str = "passthrough",
                 dry_run: bool = False, timeout: float = 5.0,
                 chunk: int = 32768):
        if mode not in ("passthrough", "pwfr"):
            raise ValueError(mode)
        self.host = host
        self.port = port
        self.mode = mode
        self.dry_run = dry_run
        self.timeout = timeout
        self.chunk = chunk
        self.sock: Optional[socket.socket] = None
        self.seq = 0
        self.last_buf = b""        # captured bytes for offline inspection
        self.bytes_sent = 0
        self.t_open = 0.0

    # --- lifecycle -------------------------------------------------------
    def open(self):
        if self.dry_run:
            self.t_open = time.time()
            return
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(self.timeout)
        s.connect((self.host, self.port))
        # Disable Nagle for low-latency PHASE / DELTA frames
        s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 1 << 20)
        self.sock = s
        self.t_open = time.time()

    def close(self):
        if self.sock is not None:
            try:
                self.sock.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            self.sock.close()
            self.sock = None

    def __enter__(self):
        self.open()
        return self

    def __exit__(self, *exc):
        self.close()
        return False

    # --- raw passthrough -------------------------------------------------
    def send(self, payload: bytes) -> int:
        """Passthrough write — board sees this byte-for-byte (over UART
        if going through ESP32). Used for existing PMSH/PPCL wire."""
        return self._write(payload)

    write = send  # serial.Serial parity

    # --- PWFR-wrapped messages ------------------------------------------
    def send_msg(self, msg_type: int, payload: bytes,
                 ack_seq: int = 0) -> int:
        """Wrap in PWFR and send. Only legal in mode='pwfr'."""
        if self.mode != "pwfr":
            raise RuntimeError("send_msg requires mode='pwfr'")
        self.seq = (self.seq + 1) & 0xFFFFFFFF
        buf = pwfr_pack(msg_type, payload, seq=self.seq, ack_seq=ack_seq)
        return self._write(buf)

    # --- helpers ---------------------------------------------------------
    def _write(self, buf: bytes) -> int:
        self.last_buf = buf
        if self.dry_run or self.sock is None:
            self.bytes_sent += len(buf)
            return len(buf)
        view = memoryview(buf)
        off = 0
        while off < len(buf):
            end = min(off + self.chunk, len(buf))
            n = self.sock.send(view[off:end])
            if n == 0:
                raise ConnectionError("peer closed")
            off += n
        self.bytes_sent += len(buf)
        return len(buf)

    def read(self, max_bytes: int = 4096, timeout: Optional[float] = 0.0):
        """Drain RX (board status / acks). Mirrors serial.Serial.read."""
        if self.dry_run or self.sock is None:
            return b""
        old = self.sock.gettimeout()
        try:
            self.sock.settimeout(timeout if timeout is not None else 0.001)
            try:
                return self.sock.recv(max_bytes)
            except (socket.timeout, BlockingIOError):
                return b""
        finally:
            self.sock.settimeout(old)

    def flush(self):
        # TCP has no equivalent of UART flush; leave as no-op for parity.
        pass

    # --- introspection ---------------------------------------------------
    def stats(self):
        dt = max(1e-6, time.time() - self.t_open)
        return {
            "host": self.host,
            "port": self.port,
            "mode": self.mode,
            "bytes_sent": self.bytes_sent,
            "duration_s": dt,
            "kbps": self.bytes_sent / 1024.0 / dt,
        }


# ----------------------------------------------------------------------------
# Self-test (dry run, no socket)
# ----------------------------------------------------------------------------
def _selftest():
    # PWFR pack/unpack round trip
    payload = b"hello-povwifi" * 7
    framed = pwfr_pack(MSG_PING, payload, seq=42)
    assert len(framed) == PWFR_HDR_SIZE + len(payload)
    mtype, seq, body, ack, n = pwfr_unpack(framed)
    assert mtype == MSG_PING and seq == 42 and body == payload
    assert n == len(framed)
    print("[wifi_stream] PWFR pack/unpack OK")

    # WifiStream dry run
    s = WifiStream("dry.invalid", 8888, mode="pwfr", dry_run=True)
    s.open()
    s.send_msg(MSG_PHASE, struct.pack("<II", 0xDEADBEEF, 7))
    assert len(s.last_buf) == PWFR_HDR_SIZE + 8
    s.send(b"\xAA" * 1024)
    s.close()
    print("[wifi_stream] dry-run OK", s.stats())


if __name__ == "__main__":
    _selftest()
