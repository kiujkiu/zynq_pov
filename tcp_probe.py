import socket, time
HOST = "10.168.168.103"
PORT = 8888
for i in range(5):
    try:
        s = socket.create_connection((HOST, PORT), timeout=2)
        print(f"#{i}: CONNECTED!")
        s.close()
        break
    except Exception as e:
        print(f"#{i}: {e}")
    time.sleep(0.5)
