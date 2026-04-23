from vitis import *
client = create_client()
client.set_workspace(path='D:/workspace/zynq_pov/02_hello_zynq/vitis_ws')
app = client.get_component(name='lwip_echo_server')
print("Building app...")
app.build()
print("Done.")
