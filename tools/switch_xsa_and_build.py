from vitis import *
client = create_client()
client.set_workspace(path='D:/workspace/zynq_pov/02_hello_zynq/vitis_ws')
plat = client.get_component(name='hello_plat')
print("Updating hardware to new XSA...")
plat.update_hw(hw_design='D:/workspace/zynq_pov/02_hello_zynq/hello_zynq_wrapper.xsa')
print("Building platform...")
plat.build()
print("Platform done.")
