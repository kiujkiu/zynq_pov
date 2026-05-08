"""Force regen hello_plat from new XSA: clean + delete + recreate."""
import os, shutil
from vitis import *

WS = 'D:/workspace/zynq_pov/02_hello_zynq/vitis_ws'
XSA = 'D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xsa'

client = create_client()
client.set_workspace(path=WS)

# Try: delete then re-create platform
try:
    client.delete_component(name='hello_plat')
    print("deleted hello_plat")
except Exception as e:
    print(f"delete failed (may not exist): {e}")

print("creating hello_plat anew from XSA")
plat = client.create_platform_component(
    name='hello_plat',
    hw_design=XSA,
    cpu='ps7_cortexa9_0',
    os='standalone',
)
print("building hello_plat")
plat.build()
print("hello_plat built")

# Re-build hello_world
app = client.get_component(name='hello_world')
app.build()
print("hello_world built")
