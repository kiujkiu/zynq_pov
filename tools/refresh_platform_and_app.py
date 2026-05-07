"""换 XSA 后重 build platform + app.

XSA 已被 Vivado 重导出 (新版含 hdmi_tmds 顶层端口), platform 直接 update_hw + build,
不需要 delete-recreate (domain 工作目录已存在). app 重 build 让 elf 链上新 BSP.
"""
from vitis import *

WS  = 'D:/workspace/zynq_pov/02_hello_zynq/vitis_ws'
XSA = 'D:/workspace/zynq_pov/02_hello_zynq/hello_zynq_wrapper.xsa'

client = create_client()
client.set_workspace(path=WS)

print("=== Update platform hw ===")
plat = client.get_component(name='hello_plat')
plat.update_hw(hw_design=XSA)

print("=== Build platform ===")
plat.build()

print("=== Build app ===")
app = client.get_component(name='hello_world')
app.build()

print("Done.")
