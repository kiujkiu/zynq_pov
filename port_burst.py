"""Hammer port 80 (current firmware) and port 8888 alternately."""
import socket, time, threading

stop = [False]
results = {80: 0, 8888: 0, 'connection_refused_80': 0, 'connection_refused_8888': 0}

def hammer(port):
    while not stop[0]:
        try:
            s = socket.create_connection(("10.168.168.103", port), timeout=0.5)
            results[port] += 1
            s.close()
        except ConnectionRefusedError:
            results[f'connection_refused_{port}'] += 1
        except (socket.timeout, OSError):
            pass

t1 = threading.Thread(target=hammer, args=(80,))
t2 = threading.Thread(target=hammer, args=(8888,))
t1.start(); t2.start()
time.sleep(60)
stop[0] = True
t1.join(); t2.join()

print(f"60s hammer test:")
print(f"  port 80   connect OK: {results[80]}")
print(f"  port 80   conn refused: {results['connection_refused_80']}")
print(f"  port 8888 connect OK: {results[8888]}")
print(f"  port 8888 conn refused: {results['connection_refused_8888']}")
