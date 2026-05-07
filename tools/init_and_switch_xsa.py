"""换机第一次: 重建 hello_plat (从 XSA), 而不是 update_hw 既有的.

换机踩坑 (2026-05-07): git 仓库里只跟踪了 hello_plat/vitis-comp.json + qemu_args.txt,
domain 工作目录 (zynq_fsbl/, standalone_ps7_cortexa9_0/) 是 build 时生成的,
没跟过 git. clone 出来后 plat.update_hw / plat.build 都报
'Invalid Domain path ...\\zynq_fsbl\\zynq_fsbl_bsp', 因为 update_hw 期望那个路径
已经存在. clean 不解决问题, 因为同样要重生成 BSP.

正解: delete + create_platform_component 让 Vitis 把 domain 目录从 0 开始建出来.
hello_world 通过名字 'hello_plat' + domain 'standalone_ps7_cortexa9_0' 引用平台,
名字保持一致, app 端无需改动.
"""
from vitis import *

WS  = 'D:/workspace/zynq_pov/02_hello_zynq/vitis_ws'
XSA = 'D:/workspace/zynq_pov/02_hello_zynq/hello_zynq_wrapper.xsa'
PLAT_NAME   = 'hello_plat'
DOMAIN_NAME = 'standalone_ps7_cortexa9_0'  # 与 hello_world/vitis-comp.json 里 domainRealName 对齐
CPU         = 'ps7_cortexa9_0'

client = create_client()
print("Setting workspace...")
client.set_workspace(path=WS)

print(f"Deleting old platform {PLAT_NAME!r} (if any)...")
try:
    client.delete_component(name=PLAT_NAME)
    print("  deleted.")
except Exception as e:
    print("  delete warning (ignore if first run):", e)

print(f"Creating new platform from {XSA} ...")
plat = client.create_platform_component(
    name=PLAT_NAME,
    hw_design=XSA,
    cpu=CPU,
    os='standalone',
    domain_name=DOMAIN_NAME,
)

print("Building platform (this can take a few minutes)...")
plat.build()
print("Platform done.")
