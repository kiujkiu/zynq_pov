---
name: POV3D panel chip pivot FM6124 → ICND2047 (2026-06-04)
description: 静态 HUB75E panel 驱动 chip 路径切换 — 跳过 FM6047 (编程手册 NDA), 锁定 ICND2047 (datasheet 完整公开 register, 永远 DDR, 估 ~13700 fps)
type: project
created_at: 2026-06-04 12:30 CST
updated_at: 2026-06-04 12:50 CST
originSessionId: cddd55be-5600-43d2-9b26-a291ffc28846
---
# 决策路径

**FM6124 (现 v29 配置, 8545 fps)** → 调研 FM6047 → **最终 ICND2047**

## 为啥不用 FM6047

- 富满 FM6047 datasheet 提到倍频功能 (CLK 上升+下降沿都采样 SDI), 但**寄存器 bit 定义没公开**
- 倍频 enable 在 WR_REG1/2/3 哪个 bit, datasheet 不说, 需要 NDA "编程指导" (类似 ICND1069 有的那种厂家专用 PDF)
- 本地 `docs/fm/` 只有 FM6124 + FM6047 datasheet (公开版), 没编程手册
- 不写 register 默认是非倍频 → fps 比 FM6124 还低 (25M vs 36M 超频)

## 为啥选 ICND2047

集创北方 ICND2047 datasheet 在 `docs/chipone/ICND2047_datasheet.pdf` (V2.0 Mar 2022), 完整公开:

| 项 | FM6047 | **ICND2047** |
|---|---|---|
| DDR (双沿采样) | 默认非倍频, 需写 REG enable (bit 未公开) | **永远 DDR**, 无需切换 |
| Register bit 定义 | 没公开 | ✅ datasheet 直接给 REG1+REG2 完整 bit map |
| 默认 register 是否够用 | 不明 | ✅ default 即可正常显示 |
| LE 命令计数 | 倍频/非倍频两套表 | 永远数双沿数 (rise+fall 个数) |
| FCLK max | 25 MHz | 25 MHz |
| twCLK / twLE / setup / hold | 几乎一致 | 几乎一致 |

# ICND2047 关键技术参数

## 时序 (datasheet 动态特性, VDD=3.3V)

- FCLK MAX: **25 MHz** (= 物理 CLK, effective bit rate 50M because of DDR)
- twCLK: **20 ns** min
- twLE: 20 ns min
- twOE: 40 ns min
- tHOLD1/tHOLD2/tSETUP1/tSETUP2: **5 ns** min

## LE 命令字 (LE 高电平期间 CLK 上升+下降总边沿数)

| LE 长度 | 命令 | 说明 |
|---|---|---|
| 0 | Reset | 寄存器复位, 新版要求 LE 包含至少 1 个 CLK 上升 |
| **3** | DATA_LATCH 普通行 | row 不变 |
| **4** | DATA_LATCH 换行 | row + 1 |
| **5** | DATA_LATCH 首行 | row 复位到 0 |
| 4~10 中其他 | Reserved | 不用 |
| **11** | WR_REG1 | 写白平衡 + 电流增益 |
| **12** | WR_REG2 | 写开路检测 + 消影 |

⚠ chip **内部自动 row counter**, 不需要外部 ABCDE 行选 — 这是跟 HUB75E + FM6124 最大架构差异.

正常显示序列: `LE 长度 5 (首行) → 3 → 4 → 3 → 4 → 3 ...` 即换行/不换行交替 (datasheet line 1735-1739).

## 寄存器 (16-bit shift register, 高位先传)

**REG1**:
- [15:11] R_UP: 白平衡修调, default 5'h1f, `VR_UP = VDD-3.25V + bits×0.0855V`
- [10:7] R_IGAIN: 电流增益, default 4'hf = 100%, 公式 `25%~100%`
- [6:4] R_V0P3: 恒流源拐点电压, default 3'h7
- [3:0] Reserved

**REG2**:
- [15:13] Reserved
- [12:11] OPEN_D: 开路检测使能, default 2'h0 (关), 2'h01 进行, 2'h11 启用
- [10:9] Reserved
- [8] R_UPCTRL: 消影电路使能, default 1'h0 (程序控制消影)
- 其他 bit 待查

**默认就能跑**: 不写 register, 用 default 即可正常显示 (100% 增益 / 开路检测关闭). 白平衡可后续校.

# fps 预估

```
当前 v29 (FM6124, 16 col TUNIT=1 FCLK1=72M DCLK 36M, OE_PRE=8):
  shift 85.3 µs/帧 + OE_PRE 21.3 µs/帧 + LATCH/ADDR 8 µs + display 28 µs(overlap 隐藏)
  = 117 µs/帧 → 8545 fps

ICND2047 + DDR (aclk 50M / DCLK 25M / effective 50M):
  shift 16/50M × 6 plane × 32 row = 61.4 µs/帧
  OE_PRE = 0 (双缓存, 不需 setup)
  LATCH+ADDR = (3 cyc 双沿数 + 行管 setup) × 6 × 32 ≈ 12 µs/帧
  display 28 µs (overlap 隐藏)
  ≈ 73 µs/帧 → ~13700 fps (+60%)
```

# verilog v30 改造方向 (待硬件到位)

新 PL IP 名 `icnd2047_panel_seq` (跟 hub75e_panel_seq 完全不同协议, 不共用):

1. **DDR shift FSM**: aclk = 50M, DCLK_DIV=2 → DCLK = 25M
   - 每 aclk 周期 SDI <= bit[n+1], DCLK toggle
   - 1 aclk = 1 bit shift (vs FM6124 = DCLK_DIV/2 aclk = 1 bit)
   - SDI 切换 vs DCLK 边沿对齐: tSETUP1=5ns, aclk 20ns 余量充足

2. **LE 命令字 generator**: LE 拉高期间 DCLK 跑 N 个上升+下降沿
   - 3 边沿 = DATA_LATCH 普通行 (= 1.5 DCLK 周期)
   - 4 边沿 = 换行 (= 2 DCLK 周期)
   - 5 边沿 = 首行 (= 2.5 DCLK 周期)

3. **OE_PRE_CYC = 0**: 双缓存, OE-fall 不需 setup time, 直接 shift 下一 plane

4. **删 ABCDE 输出**: chip 自动 row counter, ABCDE 5 路 IO 释放, 但行管侧 (ICND3019/PMOS) 还要 ABCDE 译码 OE — 这部分独立处理

5. **REG 配置 (可选)**: 上电后默认 register 够用. 若要写白平衡/电流增益, FSM 增加 init state 发送 16-bit pattern + LE 长度 11/12 命令.

6. **BD 改 FCLK1 = 50M** (现 72M), DCLK 25M 满足 spec.

# 硬件状态待确认

User 决定切 ICND2047 路径前需要确认:

1. **panel 状态**: 现 FM6124 panel 是不是要换成 ICND2047 panel? 还是 ICND2047 单 chip 样片?
2. **行管侧**: ICND3019 行管 (NMOS) 跟 ICND2047 (cathode sink) 极性是否兼容? 跟 FM6124 panel 一样还是要换 PMOS?
3. **PANEL_WIDTH / 分辨率**: 还是 128×64 1/32 scan? 还是新分辨率?
4. **验证节点**: 先跑通"亮起来"还是直接量 fps?

# 文档路径

- ICND2047 datasheet: `docs/chipone/ICND2047_datasheet.pdf` (V2.0 Mar 2022)
- ICND2047 提取文本: `docs/chipone/ICND2047.txt` (2222 行)
- FM6047 datasheet: `docs/fm6047.pdf` (公开版, 无 register 详情)
- FM6047 提取文本: `docs/fm6047.txt`
- 富满官网: www.superchip.cn
- 集创北方官网: www.chiponeic.com

# 当前进度状态

- ✅ v29 FM6124 timing 优化完成 (8170 → 8545 fps, +4.6%), git commit 7fc37aa
- ✅ chip pivot 调研完成 (FM6124 → 跳过 FM6047 → 锁 ICND2047)
- ✅ ICND2047 硬件确认: 已成品 128×64 1/32 panel, 行管 (ICND3019 NMOS) 跟 FM6124 一样
- ✅ **v30 ICND2047 MVP 跑通 (2026-06-04)**: 8545 → **10919 fps @ FCLK1=72M (+28%)**
  - git commit 79d4932 pushed
  - sequential FSM, 未用 chip 内置 shift-while-display 双缓存
  - 协议 model 误差 0.5% (估算 vs 实测), 时序计算可信
  - 视觉验证待 user 物理 check (frame_count 在跑只证 FSM 工作, 不证 LE 命令字 row counter 同步对)
- ⏳ overlap 改造预测 ~14100 fps @ 72M / ~9750 fps @ 50M (+29%)

# v30 实测数据 (2026-06-04, 16 col / TUNIT=1 / mode 0 SOLID white)

| FCLK1 | DCLK | aclk | fps 实测 | 估算 | 误差 |
|---|---|---|---:|---:|---|
| 50M (spec 内) | 25M | 50M | 7540 | 7575 | -0.5% ✓ |
| **72M** (超 spec 44%) | 36M | 72M | **10919** | 10870 | +0.5% ✓ |

vs v29 FM6124 @ 72M baseline 8545 fps: **+28%**.

# v30 文件清单

- `02_hello_zynq.srcs/sources_1/imports/hdl/icnd2047_panel_seq.v` (583 行)
  module 名 `hub75e_panel_seq_v2` (占位, 让 BD module_ref drop-in 不改)
- `02_hello_zynq.srcs/sources_1/imports/hdl/hub75e_panel_seq.v`
  FM6124 module 改名 `hub75e_panel_seq_v2_fm6124` (avoid name duplicate, 保 git history)
- `tools/build_v30_icnd.tcl` — add icnd2047 file + re-wrap + build
- `tools/v30_test.tcl` — FCLK1=50M + 72M sweep + 测 fps
- BD 完全不动 (FCLK1 BD 75M build-time, runtime mwr SLCR 改 50/72M)
- xci/wrapper 不改 (ports 一致, parameter 多余的 ICND module 接受但忽略)
