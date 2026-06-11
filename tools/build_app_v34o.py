from vitis import *
client = create_client()
client.set_workspace(path='D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws')
print("[build] hello_world app...")
app = client.get_component(name='hello_world')
app.build()
print("[build] done")
