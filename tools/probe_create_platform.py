"""Probe add_domain after setting workspace."""
from vitis import *
client = create_client()
client.set_workspace(path='D:/workspace/zynq_pov/02_hello_zynq/vitis_ws')
plat = client.get_component(name='hello_plat')
print("=== add_domain ===")
help(plat.add_domain)
print("=== build ===")
help(plat.build)
print("=== retarget_fsbl ===")
help(plat.retarget_fsbl)
