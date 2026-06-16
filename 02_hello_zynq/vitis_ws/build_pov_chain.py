import vitis, os

WS   = r"D:\claude_workspace\pov3d\zynq_pov\02_hello_zynq\vitis_ws"
XPFM = r"D:\claude_workspace\pov3d\zynq_pov\02_hello_zynq\vitis_ws\hello_plat\export\hello_plat\hello_plat.xpfm"
SRC  = r"D:\claude_workspace\pov3d\zynq_pov\02_hello_zynq\vitis_ws\pov_chain_src"

client = vitis.create_client()
client.set_workspace(path=WS)

# 删旧组件 (重跑幂等)
try:
    client.delete_component(name="pov_chain")
except Exception as e:
    print("no old comp:", e)

comp = client.create_app_component(name="pov_chain", platform=XPFM,
                                   domain="standalone_ps7_cortexa9_0",
                                   template="empty_application")
comp = client.get_component(name="pov_chain")
comp.import_files(from_loc=SRC, files=["main.c"], dest_dir_in_cmp="src")
comp.build()
print("POV_BOOT_BUILD_DONE")
vitis.dispose()
