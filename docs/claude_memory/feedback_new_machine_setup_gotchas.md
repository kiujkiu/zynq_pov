---
name: 换机/首次重建踩坑
description: NEW_MACHINE_SETUP 漏写的换机坑：HLS PATH、vivado-library、Vitis platform domain、rgb2dvi BD external、dl_helloworld 路径、OBS 假帧
type: feedback
originSessionId: b06db388-19ba-43ae-89cd-9634b2018e56
---
换新机后从零跑通整条 (HLS→Vivado→Vitis→烧板→host stream→HDMI capture) 流水线，踩了 6 个坑，按顺序记录。

## 坑 1：vitis_hls.bat 报 `'tee.exe' 不是内部或外部命令`

**Why**：本机 Vitis_HLS 是 partial install，缺 `C:\Xilinx\Vitis_HLS\2024.2\tps\win64\msys64\`（含 tee.exe + msys2 工具集）。`vitis_hls.bat` 把日志 pipe 到 tee.exe，找不到就 exit 255。

**How to apply**：跑 HLS 综合前，把 Vitis 完整安装的 msys64 加进 PATH：
```cmd
set PATH=C:\Xilinx\Vitis\2024.2\tps\win64\msys64\usr\bin;%PATH% && D:\Vitis_HLS\2024.2\bin\vitis_hls.bat -f run_hls.tcl
```

## 坑 2：`vivado-library/` 不在 repo 里，但 BD 强依赖

**Why**：`02_hello_zynq.xpr` 写死 `IPRepoPath="$PPRDIR/../vivado-library"`，BD 用 Digilent rgb2dvi IP + TMDS 接口。但 `.gitignore` 把它排除，git clone 拿不到。

**症状**：BD validate / generate_target 报 `Could not find the abstraction definition ... digilentinc.com:interface:tmds_rtl:1.0`，IP locked。

**How to apply**：clone 主仓库后立即：
```cmd
cd /d D:\workspace\zynq_pov && git clone --depth 1 https://github.com/Digilent/vivado-library.git
```
位置必须 `D:\workspace\zynq_pov\vivado-library\`（与 `02_hello_zynq\` 同级），路径写死在 .xpr 里。

## 坑 3：Digilent rgb2dvi IP-XACT 与 Vivado 2024.2 不兼容

**Why**：vivado-library master 分支 `ip/rgb2dvi/component.xml` 的 modelParameter (kGenerateSerialClk/kClkPrimitive 等) 用 spirit:dataType="" 空类型，Vivado 2024.2 generate_target 时报 `Unsupported VHDL data type ''`，wrapper.vhd 里 generic 全是空类型。

**How to apply**：用 `tools/repack_rgb2dvi.tcl` 让 Vivado 自己重打包（从 .vhd entity 现场推 generic 类型）。一次性，不用每次跑：
```cmd
D:\Vivado\2024.2\bin\vivado.bat -mode batch -source repack_rgb2dvi.tcl -nojournal
```

## 坑 4：rgb2dvi 重打包后 BD 顶层 hdmi_tmds external port 被悄悄丢

**Why**：`bd_use_batch_ip.tcl` 里 `upgrade_ip` rgb2dvi 时，因 IP-XACT 改了，Vivado silently 把 BD 顶层 `hdmi_tmds` external interface 和 `rgb2dvi_0_TMDS` 连线一起丢掉。结果 wrapper.v 没有 hdmi_tmds_clk_p/n/data_p/n 这 8 根 port，led_pins.xdc 全部 `No ports matched` → HDMI 完全黑（不是 capture 卡问题，是芯片真没输出）。

**症状（log 里看）**：
```
WARNING: instance 'rgb2dvi_0' has 10 connections declared, but only 6 given
No ports matched 'hdmi_tmds_clk_p'   (× 8 条 + 8 个 CRITICAL set_property)
```

**How to apply**：`bd_use_batch_ip.tcl` 在 generate_target 之前加 hdmi_tmds external 重建逻辑（已写入），或单独跑 `tools/bd_fix_hdmi_tmds.tcl` 补一次：
```tcl
set rgb_tmds [get_bd_intf_pins rgb2dvi_0/TMDS]
if {[llength [get_bd_intf_nets -of_objects $rgb_tmds]] == 0} {
    make_bd_intf_pins_external $rgb_tmds
    set_property name hdmi_tmds [get_bd_intf_ports TMDS_0]
}
```

## 坑 5：Vitis platform 工作目录没跟 git，update_hw 报 Invalid Domain path

**Why**：repo 只跟踪 `vitis_ws/hello_plat/vitis-comp.json` + `resources/*/qemu_args.txt`，但 domain 工作目录（`hello_plat/zynq_fsbl/`、`hello_plat/standalone_ps7_cortexa9_0/`）是 build 时生成、`.gitignore` 排除的。新机 clone 后调 `plat.update_hw(...)` 直接报：
```
Invalid Domain path 'D:\...\hello_plat\zynq_fsbl\zynq_fsbl_bsp'
```
然后 build 失败。clean 也救不了（同样 BSP 要重生成）。

**How to apply**：换机第一次走 `delete_component + create_platform_component` 重建（不是 update_hw）。`tools/init_and_switch_xsa.py` 已改成这个流程：
```python
client.delete_component(name='hello_plat')
plat = client.create_platform_component(
    name='hello_plat', hw_design=XSA, cpu='ps7_cortexa9_0',
    os='standalone', domain_name='standalone_ps7_cortexa9_0')
plat.build()
```
名字 + domain_name 跟 hello_world/vitis-comp.json 里的 platform/domain 引用对齐就不用改 app。

## 坑 6：dl_helloworld.tcl 老路径在 Python API 重建 platform 后失效

**Why**：旧路径 `vitis_ws/hello_world/_ide/bitstream/*.bit` 和 `_ide/psinit/ps7_init.tcl` 是 Vitis classic IDE 烧的；用 Python API `create_platform_component` 重建 platform 后，bit + ps7_init 在 `vitis_ws/hello_plat/hw/sdt/` 下，老路径不存在，xsdb 找不到 .bit 报错。

**How to apply**：`dl_helloworld.tcl` 已切到新路径：
```tcl
set bit "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/hello_zynq_wrapper.bit"
set psinit "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"
```

## 坑 7：OBS Virtual Camera 在 OBS 没真连源时输出最后一帧 placeholder（假帧坑）

**Why**：`tools/capture_obs.py` / `grab_obs.bat` 抓的是 dshow `OBS Virtual Camera`。若 OBS 进程开着但 source 没连/freeze（HDMI capture 卡未激活、OBS scene 切走、或 OBS 后台），虚拟相机仍以 60 fps 输出**最后一帧的 placeholder**，看起来一直是同一张画面。

**症状**：HDMI 实际在跑（VDMA 输出正常、UART 60.54 FPS、ARM 写 fb 都对），但每次抓到的 jpg 完全相同，导致误判 ARM 渲染挂掉。

**How to apply**：调试 HDMI 一律用 `tools/grab_direct.bat`（直接 dshow `video=C1-1 USB3 Video`，绕过 OBS）。OBS 必须先关：
```cmd
powershell -Command "Stop-Process -Name obs64 -Force"
D:\workspace\zynq_pov\tools\grab_direct.bat
```
直抓需要 capture 卡空闲，OBS 占用就抓不到 (`Could not run graph (device already in use)`)。

## 应该把这些加到 NEW_MACHINE_SETUP.md 的检查清单

1. clone 主仓库
2. **clone vivado-library 到同级**（坑 2）
3. 建 `D:\workspace` 符号链接（如果路径不是 `D:\workspace\zynq_pov`）
4. 装 Xilinx 工具，确认 Vitis 完整 install（坑 1 兜底）
5. **跑一次 `repack_rgb2dvi.tcl`**（坑 3，一次性）
6. (a) HLS：`set PATH=C:\Xilinx\Vitis\2024.2\tps\win64\msys64\usr\bin;%PATH%` 后启 vitis_hls
7. (b) Vivado：`bd_use_batch_ip.tcl`（已含坑 4 修复）
8. (c) Vitis：`init_and_switch_xsa.py`（坑 5）+ `build_hello_world.py`
9. (d) 烧板：`dl_helloworld.tcl`（坑 6 已修）
10. 验证 HDMI：`grab_direct.bat`，**别用 OBS Virtual Camera**（坑 7）
