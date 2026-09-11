---
name: reference_gowin_eda_install
description: 高云云源 Gowin EDA V1.9.12.03 装在 C:\Gowin\Gowin_V1.9.12.03_x64 (2026-09-11), gw_sh 无头; ✅ license 已装 C:\Gowin\gowin.lic (NODELOCK STD, 绑以太网 84F758400219, 到 2027-09-11), GW5A-25/60 冒烟均到 bit; -pn 必须配 -device_version
metadata:
  type: reference
---

**装了什么** (2026-09-11): 安装包在 `D:\工程软件\gowin\`, 装的是 **V1.9.12.03**(2026-06-17, 比同目录 1.9.12 新, 1.9.12 不用装)。
NSIS 安装器, asInvoker 不要管理员: `Gowin_V1.9.12.03_x64_win.exe /S /D=C:\Gowin` 静默 56 秒装完 ⇒
`C:\Gowin\Gowin_V1.9.12.03_x64\{IDE,Programmer}`, 2.4 GB。**IDE 自带 Programmer**, 独立 `programmer1.9.12(2558)` 包多余。
USB 下载线驱动在 `Programmer\driver\GowinUSBCableDriverV{4,5}_for_win7+.exe`, **未装**(要 UAC)。

**无头命令**: `cmd.exe /c 'C:\Gowin\Gowin_V1.9.12.03_x64\IDE\bin\gw_sh.exe run.tcl'`,
tcl 用 `create_project -name X -dir ... -pn GW5A-LV25UG324C2/I1 -device_version A -force` / `add_file` / `set_option -top_module` / `run all`。
冒烟工程在 `C:\temp\gw_smoke\`。

✅ **License 已就绪 (09-11 14:13)**: 用户微信发来 `gowin_E_84F758400219.lic`(原件在 `Documents\xwechat_files\...\msg\file\2026-09\`),
原样拷到 `C:\Gowin\gowin.lic`(= gwlicense.ini 默认值, ini 未改); `MODE=NODELOCK TYPE=STD HOST_ID=84F758400219 EXP_DATE=2027-09-11` 🔴**一年到期要续**。
冒烟实测: **GW5A-LV25UG324C2/I1 `-device_version A` 13s 到 bit / GW5A-LV60UG324SC2/I1 `-device_version B` 15s 到 bit**, 0 error。
🔴 **`-pn` 不带 `-device_version` 直接报 `The target device does not have device version` 退出**; 版本号查 `IDE\data\device\device_info.csv` 第 6 列:
GW5A-60 只有 **B**; GW5A-25 有 **A/B 两版**(B 多一列 180Kb 存储) ⇒ ⚠ **ACG525-V1 上贴的是 A 还是 B 版未确认**, 上板前要看芯片丝印/板卡资料。
UG324 可选 PN: 25 = C1/I0 C2/I1 SC1/I0 SC2/I1 ES; 60 = `UG324A{C1/I0,C2/I1,ES}` 与 `UG324S{C1/I0,C2/I1}`(还有 GW5AT-60 同封装)。

以下为装 license 前的排查记录:
🔴 **License**: 综合/PnR 都要 license, 没有就只打一行 `License verification failed  File can not be opened.` 然后退出。
- 配置文件 `IDE\bin\gwlicense.ini`, 默认 `lic="C:/Gowin/gowin.lic"`(不存在)
- gw_sh 字符串里有正则 `lic\s*=\s*"(.*)"` 和 `^(.*):(\d+)$` ⇒ **`lic=` 写 `host:port` 即走浮动 license 服务器**(端口 10559/10558, 见发布说明)
- 报错表含 `License hostid not match` / `Software require license 2.0 file` ⇒ 绑 MAC 的 2.0 格式
- 本机(`wanqi.liu`) MAC: 以太网 Realtek 2.5GbE `84-F7-58-40-02-19` / WLAN AX211 `D4-94-A9-C8-AA-BE`
- ✅ **09-11 定: license 绑以太网 `84-F7-58-40-02-19`(`84F758400219`)**, 已核: MacAddress==PermanentAddress(原厂烧录)、驱动 `NetworkAddress` 覆盖为空;
  gw_sh/GowinSynthesis/license_config_gui 只导入 `QNetworkInterface::allInterfaces`+`hardwareAddress`, **不调 `flags()` ⇒ 不筛 Up/Down**,
  .NET 同 API 实测断网的以太网照样列出(Down) ⇒ **不插网线也能验**; 🔴 唯一会让它消失的是**在设备管理器/网络连接里"禁用"以太网**(禁用的网卡 GetAdaptersAddresses 不返回);
  不用 WLAN(Windows "随机硬件地址"可让它变) / 绝不用 `00-15-5D-*`(WSL Hyper-V 虚拟网卡, 重启会变)
- `Gowin_LicenseServer_V2.2_win.zip` 是自建浮动服务器的程序, 本身也要一份绑服务器 MAC 的 license 才能跑

发布说明要点: GW5A(T)-60 **VCC 典型值改为 0.95V**; 内存 GW5A-60 推荐 5GB / GW5A-25 4GB; 工程放 `C:\temp\` 这类 ASCII 路径(预防性做法, 中文路径会不会出问题**未验证**)。

相关: [[reference_bridge_fpga_alternatives]] [[project_pov3d_adapter_board_and_uplink_bank]]
