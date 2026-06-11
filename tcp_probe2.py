"""Connect + try read - see if anything's actually on the other end."""
import socket, time
for i in range(20):
    try:
        s = socket.create_connection(("10.168.168.103", 8888), timeout=1)
        # Get local + remote addrs (verify routing)
        local = s.getsockname()
        remote = s.getpeername()
        s.settimeout(0.5)
        # Try sending HTTP request
        s.sendall(b"GET / HTTP/1.0\r\n\r\n")
        try:
            data = s.recv(256)
            print(f"#{i}: local={local} remote={remote} recv {len(data)}: {data[:100]!r}", flush=True)
        except socket.timeout:
            print(f"#{i}: local={local} remote={remote} no recv (timeout)", flush=True)
        s.close()
        time.sleep(1)
    except Exception as e:
        if i % 5 == 0:
            print(f"#{i}: {type(e).__name__}", flush=True)
    time.sleep(0.3)
