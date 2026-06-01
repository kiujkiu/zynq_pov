"""Build hello_world after new xsa: regen hello_plat BSP, then build app.

Run from Vitis Python (vitis -s build_hub75e_app.py) or vitis client.
"""
from vitis import *
client = create_client()
client.set_workspace(path='D:/workspace/zynq_pov/02_hello_zynq/vitis_ws')

XSA = 'D:/workspace/zynq_pov/hello_plat/hw/hello_zynq.xsa'

print("[step 1/3] Updating hello_plat hardware to new xsa...")
plat = client.get_component(name='hello_plat')
try:
    plat.update_hw(hw_design=XSA)
    print("  update_hw OK")
except Exception as e:
    print(f"  update_hw failed (maybe same xsa): {e}")

print("[step 2/3] Re-building hello_plat (BSP regen)...")
plat.build()
print("  hello_plat built.")

print("[step 3/3] Building hello_world app...")
app = client.get_component(name='hello_world')
app.build()
print("  hello_world built.")

print("Done.")
