import socket, time
for attempt in range(30):
    for port in [80, 443, 22, 8888]:
        try:
            s = socket.create_connection(("10.168.168.103", port), timeout=1)
            print(f"#{attempt} port {port}: CONNECT OK!", flush=True)
            s.close()
            time.sleep(0.1)
        except Exception as e:
            if attempt < 3 or attempt % 10 == 0:
                print(f"#{attempt} port {port}: {type(e).__name__}", flush=True)
    time.sleep(0.5)
