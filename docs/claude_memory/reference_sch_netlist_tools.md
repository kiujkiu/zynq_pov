---
name: Altium PDF 抽网表 + 端到端引脚推导工具
description: mlkpai_fs03/tools/{sch_netlist.py, derive_panel_pins.py} — 从原理图 PDF 无损还原 pin↔net, 并推导 ball↔屏信号 (带自检)
type: reference
---
`mlkpai_fs03/tools/` 下两个工具，2026-07-27 为核对转接板 v1.2 线序写的，以后核任何板子都能用。

## sch_netlist.py — 从 Altium 导出的 PDF 抽网表

原理：Altium 打印 PDF 时会把每个引脚的连接点写成**不可见文本** `PI<位号><pin>`，
紧跟其后的 `NL<网名>` 是这簇引脚所属的网。据此可**无损还原 pin↔net**，不用打开 Altium。

```
<Win python> tools/sch_netlist.py "D:\...\sheet.pdf" [--only J1,P1] [--tail N]
```
- 需 Windows Python 的 PyMuPDF（`fitz`）；WSL 那份没装 PDF 库
- `--only` 只打指定位号，两个连接器一打就是端到端映射表
- ⚠ **`--tail N` 很关键**：电源网（GND/VCC）走 power port、PDF 里**没有 NL 标号**，
  其引脚簇会被并到下一条网前面。原始顺序下本网自己的引脚永远在末尾 → `--tail 2` 截尾即可
- ⚠ 网表**末尾**那几组无标号电源网后面没有 NL，解析器会整个丢掉 —— 要查电源脚得直接读原始 token 流

## derive_panel_pins.py — 三段链路推导 + 自检

链路 `FPGA ball ─FS03 J12─> 接口板 P2 ─10Ω─> P1/P3 ─转接板─> 屏 J1`，
规律 **P1 = 30 − J12**、**P3 = 50 − J12**、`CEP2_kP/N = J12 2k+1/2k+2`。

**自检是核心价值**：用 v1.1（已知能工作）的网表跑同一套推导，必须**逐 pin 复现旧 XDC**，
复现得上才认新版结果。没这一步就是在猜。

## 结构性校验技巧（这次立功了）

怀疑某个 ball 值错时，检查 **CEP2_kP/N 是否落在 FPGA 真实的 Lxx_P/N 差分对上**。
19 对全中不可能是巧合 —— 用这招确认了屏2 那张从没上过屏的表是对的（`T4=IO_L20P_T3_13`
配 `U4=IO_L20N_T3_13`），把排查方向从「表错了」转到「物理链路断了」。

查 pin 属性：Vivado `get_package_pins <site>` 的 `BANK` / `PIN_FUNC` / `IS_VREF` / `IS_CLK_CAPABLE`。

**Why:** 靠这套在 [[project_pov3d_trans_v12_pinmap]] 里查出旧文档 3 处笔误（B1/G2 的 P1 脚号、R3 的 J12 脚号），
且硬件一直是对的、错的只是文档。
