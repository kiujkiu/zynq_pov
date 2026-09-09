---
name: 安路 TD/FD 工具链安装实测 + 无头批处理流程
description: TD 5.9.1_DR1_2025.1 装在 C:\Anlogic, license 已过期是硬卡点; .al 工程是纯 XML, td_commands_prompt.exe 跑全流程; 命令行下载 download -mode jtag; AL-Link Mini 会被 Windows 绑错驱动; 🔴 TD 是确定性的, 比对设计看 .bit 头里的 Bitstream CRC 不是 md5(头里有构建时间戳)
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

## 🔴 时序报告 SWNS/HWNS **全 0** = 约束没生效, 不是"时序完美"

踩过两次, 症状不一样但根子一样 —— **约束的对象不是实际驱动逻辑的那条时钟**:

1. `read_sdc` / `read_adc` 没写进 run tcl ⇒ `Constraint File:` 一栏是空的,
   时钟变成 `DeriveClock`(那次恰好也是 50 MHz, 更容易骗过去)。
2. 顶层用参数切了时钟源 (`aclk = CLK_SRC ? p2f_clk0 : sysclk`), SDC 却还约束着
   已经不驱动任何东西的 `sysclk` ⇒ **SWNS/HWNS 全 0**, 因为一条路径都没分析。

**判据**: 跑完必须回读**四条**, 缺一不可
- `grep "Constraint File"` 非空
- `grep -E "SWNS|HWNS"` 不是全 0
- 时钟表里的**时钟名**与预期一致
- 🔴 时钟表里的 **Fanout 不是 0**, `Report Clock Domain Luts` 表**不是空的**

最后两条是最隐蔽的: `create_clock ... [get_nets p2f_clk0]` 会被 TD 接受、
`Constraint File` 也非空, 但报告里是
```
Clock-Id:  C-Freq   Fanout   Clock-Name
    clk0:  50.000        0   sysclk        <- 绑到了不驱动逻辑的网上, 且不报错
```
⇒ **约束绑错网时 TD 完全不告警**, 只能靠 Fanout=0 和空的 Domain Luts 表认出来。
可用的写法是指顶层里实际驱动逻辑的那条网 (本例 `[get_nets aclk]`)。

顺带: `p2f_clk0` 这种内部网用 `[get_nets p2f_clk0]`;
`[get_pins u_ps/p2f_clk0]` 在 TD 里找不到 (报 `USR-8134`)。

---

# 🔴 下载器: AL-Link Mini 被 Windows 绑错驱动 (2026-09-08 实测解决)

**症状**: TD 报 `PRG-9505 : USB device open error`, GUI 与命令行都下不进去。
**根因**: 板上下载器是 `VID_336C&PID_1002` = **AL-Link Mini**, 但 Windows 把它绑到了
**通用 WinUSB** —— 来自一个 "Windows Phone" 的 `oem76.inf`, 而安路自己的 `ANLOCYUSB`
驱动**从来没装过**。设备管理器里看着"工作正常"、没有黄色感叹号, 所以极难认出来。

**修法**: 装 `driver\al-link\win10\x64\anlocyusb.inf`(装完成为 `oem88.inf`), 重启设备。
**判据**(三条都要):
```
设备描述  = Anlogic AL-Link Mini      (不是 "WinUSB Device")
Service   = ANLOCYUSB                 (不是 WinUSB)
ProblemCode = 0
```
然后 `read_device_id` 应当回读出器件名(本例 `EG4X20`) —— **这一步过了才说明 JTAG 链通**。

⚠ 老板子/老下载器用的是 Cypress/EZ-USB FX2, 驱动在 `driver\dl-cable\win10`;
**先看 VID/PID 再决定装哪个**, 装错了症状一模一样。

📌 与 [[project_lz4_pl_decoder]] 里"卡在安路下载器那条阻塞挂了三周、是伪命题"呼应:
那次的结论是"绕开它"(Zynq 走 JTAG / DR1 走 fpga_manager), **这次是把它真正修好了**。

## TD 有命令行下载, 不用开 GUI

```
download -bit "<path>.bit" -mode jtag         # SRAM, 掉电丢失 —— 调试用这个
download -bit "<path>.bit" -mode jtag_burst   # 烧 flash
download -bit "<path>.bit" -mode program_spi  # 烧 SPI
```
内部展开成 `bit_to_vec -freq 3.0` + `program -cable 0 -mode svf -spd 8 -p`。
成功判据: **`PRG-2014 : Chip validation success: <器件名>`**(本例 5.4 秒完成)。

⇒ 配合 `td_commands_prompt.exe`(tcl 末尾补 `exit` + 调用时 `< nul`, 见本文前面),
**从综合到下板全程可以无头脚本化**, 不必开 GUI。

## 上板换 bit 的一条纪律

**建构建到新目录, 不要覆盖板上正在跑的那份 `.bit`。** 两版必须能用 md5 区分,
否则"板上跑的是哪一版"这个疑问会吃掉比缺陷本身多得多的时间。
**同一块板上换 bit 而不换判读基准, 是最容易得出假结论的做法。**

🔴 **但"用 md5 区分"这句要打个补丁 —— md5 会被构建时间戳污染。** 见下一节。

# 🔴 TD 是确定性的; 比对设计要看 `Bitstream CRC`, 不是 md5 (2026-09-08 实测)

## 现象

同一个工程、同一份输入、连跑两次, **`.bit` 的 md5 不同**:
```
v2 第一次  ee4484eb69f4edd718e652b075b05dab
v2 第二次  6414139f28d2290611ee72dae444cffa
```
差点据此下"TD 构建不可复现"的结论 —— **错的**。

## 判决性实验 (几秒钟, 不用重建)

```bash
cmp -l run1.bit run2.bit | wc -l     # → 1
cmp -l run1.bit run2.bit             # → 160  70  71   (八进制: '8' → '9')
```
**整个 629,644 字节的文件只差 1 个字节**, 在偏移 160。dump 文件头就明白了:

```
# Anlogic ASCII Bitstream
# Version: Release_2026.1_SP2
# Design name: pll400_probe_led
# Architecture: eagle_20
# Package: EG4X20BG256
# Date: 2026/ 9/ 8 15:28        ← ★ 唯一的差别: 15:28 vs 15:29
# Bitstream CRC: 10110100011100111111101111100100    ← **两次逐位相同**
# USER CODE:     00000000100100100011011110010010    ← 两次逐位相同
```

⇒ **`.bit` 是带 ASCII 文件头的文本格式, 头里有构建时间(精确到分)。**
⇒ **TD 的布局布线是确定性的**; md5 变只是因为跨了一分钟。

## ⇒ 三条用法

1. **比对两个设计是否相同, 看文件头的 `Bitstream CRC`**, 不要看 md5。
   ```bash
   head -c 400 x.bit | grep -a 'Bitstream CRC'
   ```
2. **md5 仍然能回答"我下的是哪个文件"** —— 对着要下载的那份算就行。
   但它**不能**用来判断"两个工程是不是同一个设计", 也**不能靠重建复现**。
   ⚠ 重建会让已经记下来的 md5 表失效, 而设计一个比特都没变。
3. 想让 md5 也可复现, 就别重建; 或者比对时先剥掉文件头
   (`tail -c +N`, 头长度以 `Bitstream CRC` 行之后为界)。

## 这条印证了另一条已有结论

工作包 D 当初解释 `−2.032` vs `−2.404` 时写过「经 md5 核对是 RTL 版本差异,
**不是布局随机(同输入 TD 是确定性的)**」—— ✅ **这句成立**, 本次实测支持它。
"同一份 RTL 在某频点落点随种子漂移"要另找证据, 不能拿 md5 差异当证据。

## 附: 它顺手替一个 A/B 实验判了"空"

实验 ⑤ 曾怀疑「`pllin_p` 声明 `LVDS25`、而 bank 物理供电是 3.3V」会导致 PLL 不锁,
于是建了只差这一个变量的 v3(`LVDS33`)。结果:

| | Bitstream CRC |
|---|---|
| v2 (`pllin_p = LVDS25`) | `10110100011100111111101111100100` |
| v3 (`pllin_p = LVDS33`) | `10110100011100111111101111100100` ← **逐位相同** |
| v1 (探针版, 不同设计) | `10000000001111000000101101100110` ← 不同, 佐证 CRC 确实会随设计变 |

另有 `PHY-3001 : BANK 3 DIFFRESISTOR:100 VOD:350M VCM:1.2` 两版逐字相同。
⇒ **差分*输入*脚上, `LVDS25` 与 `LVDS33` 产生完全相同的硬件配置**
(合理: `VOD`/`VCM` 是*输出*参数, 输入只有片内 100Ω 端接这一项, 两版都开着)。
⇒ 该嫌疑从"没锁"的排查表里**划掉**。查了才知道不成立, 不查就只能一直挂着。

## 🔴 与 X20 那条静默陷阱是同一个机制的两面

`reference_eg4x20_vs_eg4a20_portability` 记着:
「TD 内部按 8 bank 做 DRC, 封装只有 4 条 VCCIO(1:2 映射), 同一条 VCCIO 上混电平不报错直接出 bit」。
本次撞到的是另一面: **TD 只查 bank 内 IOSTANDARD 是否一致, 不查板上真实 VCCIO** ——
声明与实际供电不符, 它不报任何错。
⇒ **TD 的 bank 概念是工具内部的, 不等于板上的电源域。** 两处都要靠人自己对着原理图核。

## 附带: 同 bank IOSTANDARD 冲突会直接挡住"加个按键"这种小事

E104 上想把板载 `F10` 按键接成"手动重测", 结果:
```
USR-8001 ERROR: Design contains multiple IOSTANDARD setups on bank 3.
RUN-1001 :    pllin_p   |    LVDS25
RUN-1001 :     key_i    |   LVCMOS33
```
TD 把 `F10` 与 `B14`(被测的 PLL 输入脚)划进**同一个 bank 3**。
⇒ 要留按键就得改被测对象的 IOSTANDARD ⇒ 放弃按键。
**在实验板上加一个"便利功能"之前, 先查它和被测对象是不是同一个 TD-bank。**

## 🔴 "PLL0 有没有被占用" —— 别读 `PLL setting string`, 去读布线后的物理站点

2026-09-08, `dr1v90/eg4_2260_e104` (E104 / EG4X20BG256) 实测。

**背景**: 该工程把 `BE19`(B14/A14, 复用 `GPLL0_CLKIN`) 与 `BE20`(D11/D12, 复用 `GPLL0_OUT`)
当普通 IO 用掉了 ⇒ 设计里的 PLL **必须**落在 PLL1/2/3, 综合后要能证明这一点。

**❌ 错误做法**: 看 bitgen 日志最后那行
```
BIT-1004 : PLL setting string = 1000
```
它只有 4 个 0/1, **位序没有任何文档**。按直觉"首位 = PLL0"读, 这一版会被判成"占用了 PLL0"——
**假警报**, 而且假警报的方向最坏: 会让人去改一个本来没问题的设计。

**✅ 正确做法: 从布线后的 db 直接读实例的物理站点, 并且先用一个已知答案的工程把量具标定好。**

```tcl
# 在 <prj>/fpga_prj_Runs/phy_1/ 里跑 (只读, 不导出任何东西)
import_device eagle_20.db -package EG4X20BG256
open_project {fpga_prj.prj} -noanalyze
import_db {fpga_prj_pr.db}
foreach c [get_cells *] {
  if {[string match -nocase "*u_pll*" $c] && ![string match -nocase "*bufg*" $c]} {
    puts "PLLSITE: $c ROW=[get_property PLACED_ROW $c] COL=[get_property PLACED_COL $c] REF=[get_property REF_NAME $c]"
  }
}
exit
```
(`td_commands_prompt.exe q.tcl < nul`; `get_cells` / `get_property` / `list_property` 都在 TD 的
tcl 里, 用 `puts [lsort [info commands]]` 可以列全。)

**标定 —— 这一步才是关键**: 拿 `dr1v90/eg4_pll400` 当基准, 它有两颗 PLL, 其中 `u_pll_b` 的
refclk 走 **B14 = `GPLL0_CLKIN` 专用输入** ⇒ 它**必然**是 PLL0。实测:

| 工程 / 实例 | refclk 来源 | 站点 |
|---|---|---|
| `eg4_pll400` `u_pll_b` | B14 = `GPLL0_CLKIN` ⇒ **必是 PLL0** | **ROW=0 COL=0** |
| `eg4_pll400` `u_pll_a` | H3 (板载 50 MHz 晶振) | ROW=0 COL=40 |
| `eg4_2260_e104` (100/150 两档 × 4 个相位版, 8 次跑) | H3 | **ROW=0 COL=40** ⇒ 不是 PLL0 ✅ |

⇒ **`ROW=0 COL=0` 就是 PLL0。**
⇒ 顺带把那个字符串的位序也定死了: `eg4_pll400` 两颗 = `1001`, `eg4_2260_e104` 只有 COL=40 那颗
= `1000` ⇒ **首位是 COL=40 那颗, 末位才是 PLL0**。想用它当旁证可以, 但别拿它当判据。

## 这条真正的教训: 又一次是"先证明量具自己对"救了场

判据本身是可以骗人的。`PLL setting string` 看起来像个现成的判据 —— 4 个位、名字就叫 PLL、
一眼就能读 —— 但它**位序未知**, 而未知的位序会把结论**整个翻过来**。
把它换成"物理站点"并不是因为站点更精确, 而是因为**站点可以用一个答案已知的工程标定**
(refclk 走专用脚 ⇒ 必是 PLL0), 而那个字符串没有任何东西可以标定它。

⇒ **判据要先能被标定, 才配当判据。** 同一条教训在本仓已经出现过至少三次:
[[feedback_criterion_must_not_contain_its_answer]]、
[[feedback_changed_instrument_and_design_together]]、
以及 `reference_eg4_iol_phase_measurable` 里那个"TD 把 IOCLK 插入延迟记成 0.000 ns 且标 unrouted"
—— 那次也是一个**看起来是数据、其实是占位符**的值差点让人选错方案。

相关: [[reference_eg4x20_vs_eg4a20_portability]] [[reference_anlogic_dr1_fs03_eval]]

# 🔴 slack 不能做减法 (2026-09-08, 我自己犯的)

## 犯法现场

`eg4_2260_e104` 的 SDC 漏了 `set_clock_uncertainty`(桥片 `build.sh` 默认带 `UNCERT=0.160`)。
我发现这一点是**对的** —— 那意味着两个工程**不是同一把尺子**。但接下来我做了个减法:

```
它报的       150 MHz  SWNS = +0.107 ns   (无 sdc uncertainty, TD 默认 0.100)
我算的       +0.107 − 0.160 = −0.053 ns  ⇒ "加上抖动就是违例"    🔴 错
重跑出来的   +0.367 ns, 零违例                                    ✅ 对
```

**收紧约束, 余量反而变大。**

## 为什么

**TD 的布局布线是朝着约束优化的 —— 约束一紧它就更用力。**
`+0.107` 是「**满足即停**」的 slack, 不是 Fmax, **不是可以拿来做减法的量**。
两个数不是同一把尺子量的同一个东西。

⇒ **要知道加了不确定度之后什么样, 唯一办法是把约束写进 SDC 重跑。** 20 分钟, 省不掉。

⚠ 我引的那条先例(`uplink_rx` 补上 160 ps 抖动后 `+0.102 → −0.056`, 见
`project_pov3d_eg4a20bg256_bridge_selection` §一 证据 1)之所以成立,
**正因为当初也是重跑出来的**。我**抄了它的形式, 丢了它的方法**。

## 第二条: 反证可能就在你自己手里

同一轮我还编了个因果: 「4:1 相位 mux + 多一级 BUFG 压过了抖动线」。
但**上一条消息里我自己刚转述过**: 转发时钟改成自由跑、**`ck_fwd` 域里一个寄存器都没有**。
**一个没有寄存器的时钟域不可能出现在任何 setup 路径上。**
两句话自相矛盾, 我没察觉。(实际最差路径两版都在 `u_tx` 里, `+0.298 → +0.107` 是布线噪声。)

⇒ **下断言之前, 先跟自己前面几句话对一遍。** 尤其是"我刚说过 X 域没有寄存器"这类
**结构性事实** —— 它们能直接否掉一整类因果假设, 成本是零。

## ⇒ 落地成判据, 别靠记性

`build.sh` 的判据里直接打出这一行, 并写明期望值:
```
Clock Uncertainty : 0.260ns (sdc uncertainty: 0.160ns, default uncertainty: 0.100ns)
                                              ^^^^^ 不是 0.160 就是约束没生效, SWNS 是假余量
```
⇒ **约束没生效当场看得出来, 不用事后猜。** 这和"先证明量具自己对"是同一条,
只不过这次量的是**约束本身**。

`TAG` 里带口径(`d150_p0_u0.160h0_poultra`), **不同口径的结果不放在同一个名字下比**。

## 顺带两条实测(同一轮)

- `UNCERT_HOLD` **只改分析不改设计**: `UNCERT_HOLD=0.160` 与 `=0` 两版
  `Bitstream CRC` **逐位相同**, 只是 HWNS 从 +0.160 变 +0.000。
  ⇒ 周期抖动加在同沿 hold 上是方法学过保守, 但**即便按最保守口径查也照样零违例**时,
  就不必再争这一条。
- `PHYS_OPT=ultra` 在这个小设计里**反而略差**(+0.510 → +0.367, 只占 3% 面积, 是布局噪声)。
  仍**默认常开** —— 它防的是 seed 波动, 不是给这一次跑用的
  (见 `project_pov3d_eg4_200mhz_solved`: `PLACE_SEED=3` 不开掉到 −0.310, 开了回 +0.132)。

## 🔴🔴 一条**显眼的未了项**: 抖动只建模了手册那一项

`UNCERT=0.160` 来自 DS300 表 3-2-2 的 **PLL 输出周期抖动 160 ps p-p**(fOUT > 100 MHz)。
**板级电源噪声、晶振自身抖动、5R 电阻网络的边沿抖动, 一项都没进预算。**
⇒ **"两档零违例"是工具侧结论, 不是上板结论。** 别让那个 ✅ 盖住这条。

# 🔴 用 `Bitstream CRC` 做回归 —— 证明"这次改动没动到别的"

`.bit` 文件头里的 `Bitstream CRC` **只由设计决定**(不含时间戳, 见上一节)。
⇒ 它是一把**免费的回归尺**: 改了工具流程或重构了参数计算之后, 拿它证明**已交付的版本一个比特没动**。

```bash
head -c 400 x.bit | grep -a 'Bitstream CRC'
```

## 2026-09-08/09 一天内用它救过三次

| 场合 | 怎么用的 |
|---|---|
| **`LVDS25` vs `LVDS33`** 的 A/B | 两版 CRC **逐位相同** ⇒ 证明差分**输入**脚上这两个标准产生**完全相同的硬件配置** ⇒ 该嫌疑从排查表里划掉。**用 md5 会得出"两版不同"的错误结论**(时间戳) |
| **重构相位步长的数学** (`CPHASE ≤ DIV` 展开成 `E ≤ 15`) | 改完 `d150_p0` 的 CRC 与改动前**逐位相同** ⇒ **已交付的 8 版一个比特没动**, 不用重新验证 |
| **给 syn 流程加 `write_verilog`**(为了解码 BRAM INIT) | 加之前/之后 17 版 CRC **逐位一致** ⇒ 证明这道新判据**不改变综合结果**, 可以常开 |

## ⇒ 两条用法

1. **改工具流程/重构参数计算之后, 先跑一遍受影响的旧版本, 比 CRC。**
   相同 ⇒ 改动是纯重构, 旧结论继续有效; 不同 ⇒ 旧结论全部作废, 要重新验。
   **这比"我觉得只是重构"可靠得多**, 而且几乎不花时间。
2. **`md5` 只能回答"我下的是哪个文件", 不能回答"是不是同一个设计"** —— 文件头带构建时间,
   跨一分钟就变。**比对设计一律用 CRC。**

⚠ 前提是**不重建**: 重建会让记下来的 md5 表失效(设计没变), 但 CRC 不受影响。

# 🔴 用 JTAG 边界扫描读回引脚电平 —— 不用示波器、不用人在旁边 (2026-09-09 实测打通)

**能做什么**: 用**已经在跑的那版 bit**(不用改 RTL、不用重编), 通过 JTAG 读回**任意引脚的当前电平**。
⇒ "帮我量一下这个脚是高还是低"这件事**归工具, 不归人**。

**做不到什么**: 只读**引脚**, 读不到内部信号(要看的量必须先引到脚上);
采样是每次一整条链、每次一个 TD 进程调用(秒级), **抓不了微秒级波形**。

## 三块拼图

```
gen_bsdl        ← **无参数调用**(16 个选项名全试过, 全非法; 位置参数也忽略)
                  用法: import_device eagle_20.db -package <封装> ; gen_bsdl  ⇒ <封装>.bsdl
                  BSDL 给出: INSTRUCTION_LENGTH / BOUNDARY_LENGTH / 指令码 / PIN_MAP / cell 顺序
EG4X20BG256:    INSTRUCTION_LENGTH=8  BOUNDARY_LENGTH=540
                SAMPLE=00000101  EXTEST=00001111  BYPASS=11111111  IDCODE=00000110
                "Cell 0 is the closest to TDO" ⇒ 移出的第 i 位 = cell i
program_svf -svf <f> -cable 0    ← 回放 SVF
```

## 🔴 `-rdbk` 不通 —— 绕法是把 `TDO` 期望值当 oracle

`program_svf -rdbk <file>` 报 `PRG-2505 program ... successfully` 但**根本不生成文件**。
改用 SVF 自带的比较机制:

```svf
SIR 8 TDI (05);                                  // SAMPLE, **只读不驱动**
SDR 540 TDI (0..0) TDO (0..0) MASK (只置想读的位);
```
- 读到 **1** 的位会逐条报 `PRG-9507 ERROR: line N read = 0x01   ref = 0x00`
- **`line = 2 × cell + 53`**(从两个已知脚 cell 1→line 55、cell 407→line 867 反解, 再用第三个脚验证)
- ⚠ **TD 同一消息 ID 只报 10 条**就 `Similar messages will be suppressed`
  ⇒ **每次掩码 ≤9 位**才能逐位读全
- ✅ 但 `PRG-9512 ERROR: Total error line : N` 给**总数**, **不受抑制**
  ⇒ 想数"有多少位是 1"可以一次掩码全链(540 位)

**读单个位的确定做法**(不依赖逐条报): 同一位分别用 `TDO=0` 和 `TDO=1` 各跑一次,
**一次 OK 一次 ERR ⇒ 值确定**。这也是自检的做法。

## 🔴🔴 安全: 只用 `SAMPLE`(05), 绝不用 `EXTEST`(0F)

`EXTEST` 会**驱动**引脚。板上接着屏、屏电源使能、电源轨 —— 驱错了轻则花屏, 重则损坏器件。
**生成 SVF 的脚本里要把这条写成文件头警告。**

## 自检不可跳 (今天救过第五次)

映射错了会读出**看起来合理但全是垃圾**的值。**先读状态已知的脚**:
```
设计里恒 0 的脚(如常驱动为 0 的输出)   → 必须读到 0
运行时确定为 1 的脚(如已使能的电源使能) → 必须读到 1
最硬的一条: 找一个**能受控改变**的位(如某个跳线), 改它再读一次,
            必须跟着变 —— **静态位读对可能是运气, 受控变量不可能是运气**
```

## ⚠ 一个会给出"错的已验证"的坑

拿**高频周期信号**当采样率基准会**混叠, 而且混叠了看不出来**。
(例: `isync` 每帧翻一次 @100 MHz 只有 2.6 ms 周期。)
⇒ 基准要选**周期远大于采样间隔**的慢信号, 并且**用它的跳变间隔反算实测采样间隔**, 不要估。

## ⇒ 设计侧的配套做法

想让工具读到什么, 就**把它引到脚上**, 而且**做成静态并行输出**(几位一组), 别做成闪码/时序编码
—— 每次读是一次独立的 TD 进程调用(秒级), **时序编码读不了**。

相关: 同一天试过但**没打通**的两条 —— `VPI`(read_vpi_reg 无参数**让 TD coredump**;
VPI.sv 是空壳, 手写黑盒撞 `PHY-8054 missing physical model`; TD 前端**不吃 SystemVerilog`)、
`ChipWatcher`(命令在、`report_cwc_status` 返回 OK, 但 `-h` 不打印、二进制无 usage 串、
33 个常见参数名全部 invalid option)。下一个入口是**用 GUI 生成一份 `.cwc` 样本再反推**。
