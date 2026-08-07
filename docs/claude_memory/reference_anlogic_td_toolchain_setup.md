---
name: 安路 TD/FD 工具链安装实测 + 无头批处理流程
description: TD 5.9.1_DR1_2025.1 装在 C:\Anlogic, license 已过期是硬卡点; .al 工程是纯 XML, td_commands_prompt.exe 跑全流程
type: reference
---

2026-08-05 FS03-DR1 开发板到货后装工具链的实测记录。上位文档见 [[reference_anlogic_dr1_fs03_eval]]。

## 1. 版本选择: 跟开发板资料包走, 不是 2024.10

[[reference_anlogic_dr1_fs03_eval]] 里写的 "TD 5.9.1_DR1_2024.10 + FD 2024.10" **是错的**。
米联客随板的《安路FPGA TD软件快速入门课程.pdf》实际指定 **TD_5.9.1_DR1_2025.1_151.508 + FD_2025.1**。
装完 `C:\Anlogic\TD_5.9.1_DR1_2025.1_151.508`，版本号 151.508 与教程完全一致。

安装包全在 `D:\BaiduNetdiskDownload\03_anlogic\`（TD_5.9 / FD / JTAG驱动 / license / 常用工具）。
开发板资料包在 `D:\BaiduNetdiskDownload\03_MLKPAI_FS03_DR1V90GEG\`。

**装法**（WSL 里驱动，UAC 要人手点「是」）:
```bash
powershell.exe -NoProfile -Command "Start-Process msiexec -ArgumentList '/i','\"D:\...\TD_5.9.1_DR1_2025.1_NL.msi\"','/passive','/norestart' -Verb RunAs -Wait -PassThru"
```
WSL interop 默认**非管理员**（`IsInRole(Administrator)` = False），必须 `-Verb RunAs`。
第一次发弹窗如果没人点会返回「操作已被用户取消」，重发即可。
FD 2 GB msi 展开后 **11 GB**（Eclipse + RISC-V 工具链），装很久。

## 2. License —— ✅ 2026-08-06 已解决

用户从安路官网下到新的，放进去后**全流程实测跑通**（见本节末）。现役 license:

| | 路径 | FEATURE 到期 |
|---|---|---|
| TD | `C:\Anlogic\TD_5.9.1_DR1_2025.1_151.508\license\Anlogic.lic` | **2027-03-31** |
| FD | `C:\Anlogic\FD_2025.1\tools\license_check\license.lic` | **2026-12-31** |

都是 `HOST_ID = ANY`（换机不用重申请，只看日期）。旧的过期版留了 `*.expired-bak` 备份。
🔴 **FD 到 2026-12-31 先到期**，届时只续 TD 会漏掉 FD。

**验证方式（别只看"没报错"）**: 跑通 demo 全流程才算数 ——
`_demo/07_boot_mode/soc_prj/fpga_prj_Runs/` 下 `syn_1` 再 `phy_1`:
`optimize_rtl` 2.4s → `optimize_gate` → `place` 7.1s → `route` 25.9s(CPU 1127%, 自动多线程)
→ `bitgen` 产出 **`fpga_prj.bit` 2,878,820 B**。全程 WSL 无头驱动，没开过 GUI。

### 下面是当初排查过程（留档）
## 2b. 🔴 License 过期 = 真卡点, "NL 版免 license" 是错的

`03_anlogic\license\Anlogic.lic` 内容: `FEATURE TD Anlogic **2026-02-17**` + `HOST_ID = ANY`。
不绑 MAC（换机没事），但**日期已过期**。

**我猜过 "文件名带 _NL 后缀 = 免 license"，实测证伪**：装 2025.1_NL 后跑综合照样报
```
RUN-1002 : start command "optimize_rtl"
RUN-1001 : Open license file C:/Anlogic/.../license/Anlogic.lic
RUN-8008 ERROR: License expired!
```
注意**卡的位置**: `import_device` / `open_project` / `elaborate` 全过，到 `optimize_rtl` 才查 license。
所以"能打开工程、能 elaborate"不能证明 license 有效，必须跑到综合才算数。

**FD 的那份也过期了**（2026-08-06 查）: FD 安装包自带
`C:\Anlogic\FD_2025.1\tools\license_check\license.lic` = `FEATURE FD Anlogic **2025-12-30**`。
两份都是 `HOST_ID = ANY`，纯粹是日期到了，不是绑机器。
⚠ 两个下载包整棵树按 `*lic*`/`*key*`/`*.dat` 全扫过，**再没有第三份**。

**解法**（要人工，我做不了）: 注册 <https://www.anlogic.com/support/tools-downloads> →
软件工具 → **TD License** / **FD license** 分开两项，各下一份。免费，有效期约 6 个月，所以**每半年要续**。
下载页需登录（手机号注册）；如提示无资料权限，发注册手机号到 web@anlogic.com 开通。

放置位置（文件名必须原样）:
```
TD → C:\Anlogic\TD_5.9.1_DR1_2025.1_151.508\license\Anlogic.lic
FD → C:\Anlogic\FD_2025.1\tools\license_check\license.lic
```
备选来源: 米联客网盘（TD 快速入门 2.2 节给的）`https://pan.baidu.com/s/1CZh8XPFsIBzzmoc9Le6p6w?pwd=1111`
提取码 `1111`（大概率就是本地这份过期的同一快照）；或米联客下载区
<https://www.uisrc.com/f-download.html>「安路开发环境&常用工具」板块（要登录）；或直接找 FAE 要。

## 3. 无头批处理流程 (可以全 CLI 驱动, 不用点 GUI)

入口是 **`bin\td_commands_prompt.exe <script.tcl>`**（≈ `vivado -mode batch -source`）。
⚠ 别用 `td.exe --help` 探参数 —— 它是 Qt GUI，会直接把窗口拉起来并挂住，得 `taskkill /IM td.exe /F`。

每个 Run 目录里 TD 自己会生成 `fpga_prj.tcl` + `run.bat`，照抄即可。两段流程:

| 阶段 | Run | 命令序列 |
|---|---|---|
| 综合 | `syn_1` | `import_device dr1_90.db -package DR1V90GEG484 -speed 2` → `open_project *.prj` → `commit_param -step design` → `elaborate -top {xxx}` → `optimize_rtl` → `optimize_gate` → `legalize_phy_inst` → `update_timing` → `report_timing_status` |
| 布局布线 | `phy_1` | `import_db ../syn_1/*_gate.db` → `place` → `route` → `report_area -io_info` → `report_timing_summary` → **`bitgen -bit "xxx.bit"`** |

报告文件: `*_rtl.area` / `*_gate.area`（资源）、`*_phy.ts` / `*_pr.timing`（时序）。

## 4. 工程文件是纯 XML ⇒ 我能直接生成/改

`soc_prj/fpga_prj.al` 是 TD 工程文件，**明文 XML**（跟 KiCad 那次一样，可脚本化，不依赖 GUI）:
```xml
<HardWare><Family>DR1</Family><Device>DR1V90GEG484</Device><Speed>-2</Speed></HardWare>
<Source_Files><Verilog><File Path="uisrc/01_rtl/system_top.v">...
<IP_FILE><File Path="uisrc/01_rtl/system/system.xml">
<TOP_MODULE><MODULE>system_top</MODULE>
<Runs><Run Name="syn_1" Type="Synthesis" ...><Run Name="phy_1" Type="PhysicalDesign" SynRun="syn_1" ...>
```
Run 目录里的 `fpga_prj.prj` 是它的派生物，源文件路径是**相对路径**（`../../uisrc/...`）⇒ 工程可整体搬移。
米联客 demo 的目录约定: `soc_hw/`(.hpf) + `soc_prj/`(TD 工程) + `soc_sdk/`(FD 工程)，源码在 `soc_prj/uisrc/01_rtl/`。

## 5. JTAG 驱动: 必须等下载器到手才能装

DR1 系列用的是 **FT AL-Link，OneCable 模式**，跟 PH1A 系列的旧下载器不同。
流程: 下载器插 PC → 管理员权限开 `UsbDriverTool`（在 `03_anlogic\JTAG驱动\UsbDriverTool.rar`）→
找到 **USB Serial Converter A**（VID/PID **0403/6042**）→ 右键 **Install WinUSB**。
然后 TD → Tools → 选 **AL-LINK-FT(Local Host)** 模式。
⚠ 手册警告: **JTAG 端子不支持热插拔**。顺序必须是 断电接 JTAG → 插 USB → 再上电，否则可能烧 JTAG IO。

## 6. 解 rar 用 Windows 7-Zip

WSL 里没有 unrar/p7zip；`C:\Program Files\7-Zip\7z.exe` 在，能解 rar:
```bash
"/mnt/c/Program Files/7-Zip/7z.exe" x "D:\...\01_board_test.rar" -o"D:\claude_workspace\pov3d\dr1v90\_demo" -y
```
demo 已解到 `D:\claude_workspace\pov3d\dr1v90\_demo\`。
