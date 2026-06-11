import vitis
ws = "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws"
xsa = "D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xsa"
client = vitis.create_client()
client.set_workspace(path=ws)
print("regen: workspace set")
plat = client.get_component(name="hello_plat")
print(f"regen: platform = {plat}")
status = plat.update_hw(hw_design=xsa)
print(f"regen: update_hw => {status}")
status = plat.build()
print(f"regen: build => {status}")
print("regen: DONE")
vitis.dispose()
