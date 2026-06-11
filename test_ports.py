import socket, time
HOST = "10.168.168.103"
for port in [8888, 9999, 22]:
    try:
        s = socket.create_connection((HOST, port), timeout=2)
        print(f"port {port}: CONNECT OK")
        s.close()
    except ConnectionRefusedError as e:
        print(f"port {port}: REFUSED (port closed)")
    except socket.timeout:
        print(f"port {port}: TIMEOUT")
    except Exception as e:
        print(f"port {port}: {type(e).__name__}: {e}")
