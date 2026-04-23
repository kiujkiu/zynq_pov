from vitis import *
import inspect
client = create_client()
client.set_workspace(path='D:/workspace/zynq_pov/02_hello_zynq/vitis_ws')

app = client.get_component(name='lwip_echo_server')
print("=== App methods ===")
for m in sorted(dir(app)):
    if not m.startswith('_'):
        print(f"  {m}")
