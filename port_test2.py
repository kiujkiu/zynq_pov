import socket, time
results = {80: 0, 8888: 0}
attempts = 0
t_end = time.time() + 60
while time.time() < t_end:
    for port in [80, 8888]:
        try:
            s = socket.create_connection(("10.168.168.103", port), timeout=1)
            results[port] += 1
            print(f"#{attempts} port {port}: OK ({results[port]}th)", flush=True)
            s.close()
        except Exception as e:
            pass
    attempts += 1
    time.sleep(0.3)
print(f"\nTotal: port80={results[80]}, port8888={results[8888]}, attempts={attempts}")
