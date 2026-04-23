from vitis import *
client = create_client()
client.set_workspace(path='D:/workspace/zynq_pov/02_hello_zynq/vitis_ws')

plat = client.get_component(name='hello_plat')
print("Building platform (will rebuild lwip220 with patch)...")
plat.build()
print("Platform done.")

# Build app
app = client.get_component(name='lwip_echo_server')
print("Building app...")
app.build()
print("App done.")
