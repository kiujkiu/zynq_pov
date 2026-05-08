"""Just rebuild hello_plat (no update_hw) so patched ps7_init is used."""
from vitis import *
client = create_client()
client.set_workspace(path='D:/workspace/zynq_pov/02_hello_zynq/vitis_ws')
plat = client.get_component(name='hello_plat')
plat.build()
print("hello_plat built")
app = client.get_component(name='hello_world')
app.build()
print("hello_world built")
