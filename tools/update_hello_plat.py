"""Update hello_plat hw spec from new XSA (with QSPI peripheral enabled),
regenerate BSP so XQspiPs driver + new ps7_init.c included."""
from vitis import *
client = create_client()
client.set_workspace(path='D:/workspace/zynq_pov/02_hello_zynq/vitis_ws')
plat = client.get_component(name='hello_plat')
print(f"updating hw spec for {plat}")
plat.update_hw(hw_design='D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xsa')
print(f"building hello_plat (regen BSP + ps7_init)...")
plat.build()
print("hello_plat built. now build hello_world.")
app = client.get_component(name='hello_world')
app.build()
print("hello_world built.")
