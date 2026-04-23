from vitis import *
client = create_client()
client.set_workspace(path='D:/workspace/zynq_pov/02_hello_zynq/vitis_ws')
app = client.get_component(name='hello_world')
app.build()
print("App built.")
