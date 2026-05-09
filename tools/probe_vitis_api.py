"""Probe Vitis Python API to find right calls for rebuilding platform from XSA."""
from vitis import *
client = create_client()
ws = 'D:/workspace/zynq_pov/02_hello_zynq/vitis_ws'

print("=== client methods ===")
print([m for m in dir(client) if not m.startswith('_')])

try:
    client.update_workspace(path=ws)
    plat = client.get_component(name='hello_plat')
    print("\n=== platform methods ===")
    print([m for m in dir(plat) if not m.startswith('_')])
    print("\n=== get_domains ===")
    try:
        print(plat.get_domains())
    except Exception as e:
        print("get_domains err:", e)
    print("\n=== list_domains ===")
    try:
        print(plat.list_domains())
    except Exception as e:
        print("list_domains err:", e)
except Exception as e:
    print("ERR:", e)
