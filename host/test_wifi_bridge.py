"""Quick connectivity test for ESP32-C5 WiFi bridge.

Run after flashing ESP32 firmware + verifying serial log shows "Got IP".

Tests in order:
  1. mDNS resolution: pov-bridge.local → IP
  2. TCP connect to <ip>:8888
  3. Echo round-trip (PWFR header + small payload)
  4. Throughput sample (send 256 KB, measure MB/s)

Usage:
    python test_wifi_bridge.py [--host pov-bridge.local] [--port 8888]
"""
import argparse
import socket
import time
import sys


def resolve_mdns(host):
    """Try DNS lookup including mDNS. Returns IP string or None."""
    try:
        addrs = socket.getaddrinfo(host, None, family=socket.AF_INET)
        ip = addrs[0][4][0]
        return ip
    except (socket.gaierror, IndexError):
        return None


def tcp_echo(ip, port, payload):
    """Send payload, read same length back. Returns (ok, rtt_ms, recv_bytes)."""
    s = socket.create_connection((ip, port), timeout=5)
    s.settimeout(5)
    t0 = time.time()
    s.sendall(payload)
    received = b""
    while len(received) < len(payload):
        chunk = s.recv(4096)
        if not chunk:
            break
        received += chunk
        if time.time() - t0 > 5:
            break
    rtt = (time.time() - t0) * 1000
    s.close()
    return received == payload, rtt, len(received)


def throughput_test(ip, port, total_bytes=256 * 1024):
    """Send total_bytes, time it. Returns MB/s."""
    payload = bytes(range(256)) * 1024  # 256 KB pattern
    payload = payload[:total_bytes]
    s = socket.create_connection((ip, port), timeout=10)
    s.settimeout(10)
    t0 = time.time()
    sent = 0
    chunk_size = 8192
    while sent < total_bytes:
        end = min(sent + chunk_size, total_bytes)
        s.send(payload[sent:end])
        sent = end
    s.close()
    dt = time.time() - t0
    return total_bytes / dt / (1024 * 1024) if dt > 0 else 0.0


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--host", default="pov-bridge.local")
    p.add_argument("--port", type=int, default=8888)
    p.add_argument("--throughput-mb", type=int, default=0,
                   help="optional throughput test size in MB")
    args = p.parse_args()

    print(f"[1/4] Resolving {args.host}...")
    ip = resolve_mdns(args.host)
    if ip is None:
        print(f"  FAIL: {args.host} cannot resolve")
        print(f"  HINT: 1) ESP32 not on WiFi 'undef'? 2) mDNS blocked by router?")
        print(f"        try direct IP: --host 192.168.x.y")
        sys.exit(1)
    print(f"  OK: {args.host} -> {ip}")

    print(f"[2/4] TCP connect {ip}:{args.port}...")
    try:
        s = socket.create_connection((ip, args.port), timeout=3)
        s.close()
        print(f"  OK: connected")
    except OSError as e:
        print(f"  FAIL: {e}")
        print(f"  HINT: ESP32 firmware running? port 8888 server up?")
        sys.exit(2)

    print(f"[3/4] Echo round-trip (32 byte payload)...")
    payload = b"POV3D_PWFR_TEST_" + b"x" * 16
    try:
        ok, rtt, n = tcp_echo(ip, args.port, payload)
        if ok:
            print(f"  OK: {n} byte echo in {rtt:.1f} ms")
        else:
            print(f"  PARTIAL: got {n}/{len(payload)} byte in {rtt:.1f} ms")
            print(f"  NOTE: depends on ESP32 firmware echo logic — may need adjustment")
    except OSError as e:
        print(f"  WARN: echo failed ({e}) — bridge may be receive-only")

    if args.throughput_mb > 0:
        size = args.throughput_mb * 1024 * 1024
        print(f"[4/4] Throughput {args.throughput_mb} MB...")
        try:
            mbps = throughput_test(ip, args.port, size)
            print(f"  result: {mbps:.2f} MB/s ({mbps*8:.1f} Mbps)")
            print(f"  benchmark: PWFR delta needs ~1-10 MB/s, full frame 720@30Hz=186 MB/s")
        except OSError as e:
            print(f"  FAIL: {e}")
    else:
        print(f"[4/4] Throughput skipped (use --throughput-mb N to enable)")

    print(f"\nBridge IP for follow-up tests: {ip}")


if __name__ == "__main__":
    main()
