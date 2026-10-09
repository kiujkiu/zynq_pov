# -*- coding: utf-8 -*-
"""DR1V90 主控 SoC ↔ GW5A 桥接模块 对接关系表 (v3: 契约 = 20 対 LVDS25 + 边带 4 + JTAG 4, 单端统一 2.5V; 验证板实现映射) —— xlsx 生成脚本

纯标准库 (zipfile 手写 OOXML, 不依赖 openpyxl, 不依赖旧 xlsx 模板)。
用法:
    python3 DR1V90_GW5A对接关系表_mkxlsx.py 输出路径                # 生成 + 源数据核对 + 回读自检; 输出路径必填 (F 步起不再缺省写包内 OUT, 防误覆盖; 要写包内就显式给 OUT 路径)
    python3 DR1V90_GW5A对接关系表_mkxlsx.py --no-verify [输出路径]  # 跳过源数据核对(源文件不在本机时)
    python3 DR1V90_GW5A对接关系表_mkxlsx.py --out=路径              # 同 argv[1] (兼容旧用法)
    python3 DR1V90_GW5A对接关系表_mkxlsx.py --soc-impl=x.json [输出路径]  # 用 JSON (结构见 SOC_IMPL_SPEC) 整体替换内嵌 SoC 侧双面数据; 校验 + 合并断言通过后渲染
输出:
    POV3D_硬件资料包_DR1V90主控与GW5A桥接模块_2026-09-15/03_两模组对接关系/
        DR1V90主控_GW5A桥接模块_对接关系表_2026-09-15.xlsx

【嵌入数据 DATA 的来源 (2026-09-15 一次性抽取, 已交叉核对)】
  dr1_pinmap   pcb/dr1v90_core_v1/05_机读数据/DR1V90GEG484_pinmap.csv (CEP1/CEP2 涉及的 97 个球)
  cep_chain    FS03 硬件手册 §16 表 (手册球位) + FS03 原理图 P17_GPIO / P06_BANK11&33
               (pdftotext -bbox 取坐标: J11/J12 脚号 → CEPx_nP/N → R187~R210 排阻第几路 → BKxx 网 → 管脚名 → 球位)
               结果: 96 个信号脚里 95 个三方一致, 仅 CEP2.7 手册 Y19 ≠ 原理图 Y9
  adc          dr1v90/uplink_tx/soc_prj/uisrc/04_pin/uplink_pin.adc (现役 14 対探针球位; v2 里只作 SoC 侧方案 A "沿用/改动" 的对照)
  ds1200_t26   DS1200_Datasheet_V1.0.pdf §2.8.2 表 2-6 (下拉 2 球 / 上拉 33 球)
  core         发票/发票内容/ACG525-CB-V2-260316-工程源文件/.../ACG525-CORE-V2.SchDoc 连接器页
               (dr1v90/gw5a_loop/tools/schnet.py 几何连通, P1/P2 共 200 脚) + Gowin UBGA324.json (球位/bank/配置复用)
               核对: 核心板原理图 PDF 第 1 页 173 个带网标脚 0 差异 (其余 27 个电源/地脚目视), 第 4 页 165 个网名↔球位 0 差异,
               dr1v90/gw5a_loop/pins_v2.tsv 73 行 0 差异
  soc_extra    pinmap.csv 中 CEP 外 2 球 (K18 / J18, bank32 = FS03 KEY2 / KEY3) —— 光电开关落脚与备选; verify() 复核
  panel_balls  constraints/panel_pins_dr1.adc 与 td_pov fpga_pin.adc 用到的 bank11 31 球 (直驱屏口径; verify() 复核)
  mipi_alias_p2 核心板原理图 PDF 第 1 页 P2.50 / P2.52~60 的 B6_L23~L31 别名 (目视)
  ug985_cfg    UG985_V1.7.2 Pin List UG324 (pdftotext -layout, 行号为该文本行号) 中配置功能列与 UBGA324.json 不同的连接器 IO 脚
               (154 个 IO 脚里 24 脚不同); 本表"配置复用 / GCLK·PLL"显示以 UG985 为准, json 差异逐脚注明; verify() 在 pdftotext 可用时全量复核

【v2 (2026-09-15) 口径】用户决定"直接按目标板做接口": 每面 20 対 = UL_D[17:0] + UL_CHK + UL_CLK, 另加边带 4 根与配置预留 7 位;
  阶段一只用 UL_D[11:0] + UL_CHK + UL_CLK (契约子集)。9 个 sheet: 说明 / 模组间接口契约 / 验证板实现-SoC 侧 (方案 A/B) /
  验证板实现-LED 侧 / 电气与机械约束 / CEP 全表 / 核心板连接器全表 / bank 预算 / 待定事项。分配与核算数字都有 assert。

【v3 (2026-09-15 下午) 口径】用户决定 D1~D7:
  D1 每面 20 対 LVDS25 (UL_D[17:0] + UL_CHK + UL_CLK), 800 Mbps/lane 标称, 100Ω±10%, G-S-S-G, 桥侧端接; 阶段一 14 対
  D2 两面接口完全相同, 各一套连接器
  D3 程序加载 = JTAG 4 根 (TCK/TMS/TDI/TDO), 取代 v2 的 7 位 SSPI/从串配置预留; 桥片位流不得把 JTAG 脚回收成 GPIO; 桥片 flash 焊盘保留 DNP
  D4 边带 4 根 SB_ALIGNED (SoC 侧外部下拉 2.2kΩ, 释放 SB_RSTN 且读到 IDCODE 前不采信) / SB_RSTN (桥侧外部下拉 2.2kΩ) / SB_UART_B2S / SB_UART_S2B
  D5 接口所有单端 (边带 4 + JTAG 4) 统一 2.5V LVCMOS; LED 侧边带放 GW5A 2.5V 组 (VCCIO23 底板设 / VCCIO67 固定),
     JTAG 在 bank10 固定 3.3V ⇒ V2 上 2.5V↔3.3V 固定方向带 Ioff 的双电源转换器; V2 留下载器插座与 SoC JTAG 0Ω/跳线二选一
  D6 晶振在 LED 模组本地、电源不走接口、两模组分开上电 ⇒ SoC 读到桥片 JTAG IDCODE 之前不驱动 LVDS 与边带
  D7 验证期 FS03 同时驱 2 块屏 + 光电开关, 两个 CEP bank 改板 VCCIO 2.5V (改板方案另附/待定)
  v3 合并步 (M): SoC 侧按 D7 双面合并 —— 面 A = CEP1/bank33 20 対, 面 B = CEP2/bank11 20 対, 单端 14 根 (方案 S: 两面共用 TCK/TMS),
     光电开关 K18 (CEP 外); 内嵌 SOC_IMPL (本会话并行流程 P2 的分配), 过 check_soc_impl + soc_merge_asserts 后渲染 sheet3 / sheet6 / sheet8 FS03 行。
  v3 F 步 (审查修正): 单端按 DS1200 §4.2 ADC 复用注 (一面 JTAG 不混用 ADC 复用球) 与"门控与被门控同 bank"重排 (两面 JTAG 整组落 bank33 6 个 ADC 复用球,
     SB_RSTN / SB_ALIGNED / SB_UART_B2S 同在 bank11, SB_UART_S2B 落 D22 / C22); JTAG 静止电平统一为低 (TCK A 口 2.2 kΩ); 改板方案引用更新到 fs03_mod README v2
     与审查 v2 (FS03 先上电最后断电 / 拆 CB-V2 飞线 / V3 闸门测点与净空 / 桥 → DR1 限流); 核心板 flash 镜像前提; 新增待定 adc_se / core_flash。
  v3 G 步 (口径统一, 球位分配不动): 按 consistency_checklist.md §二 与 dr1v90/fs03_mod/README.md v2.2 / V3_design_inputs.md / v2.1 复核统一 ——
     JTAG TCK 静止低 (PULLDOWN + V2 A 口 2.2 kΩ 下拉)、TMS / TDI 静止高 (PULLUP + V2 A 口 22 kΩ 上拉到本地 2.5 V); SB_ALIGNED / SB_UART_B2S V3 串 8.2 kΩ + PULLTYPE NONE
     (ALIGNED 2.2 kΩ 下拉在连接器侧, 未配置 0.643 V); TDO 不串阻 + PULLUP + V2 B 口 10 kΩ 下拉必须, 在位以 IDCODE = 0x0001281B 为准; DR1 → 对端不串阻 (GW5A IHS / 转换器 Ioff);
     闸门 J_TP11 (CEP2.7/8 各串 10 kΩ) + SENSE33 + TP_TDO_A (47 kΩ); J1/J2 开窗 (V3 F1); LDO 模块与 200 mA 引 V3 G2; 下电措辞引 V3 G1; 上电顺序"LED 模组上电"。
"""
import copy
import csv
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
import xml.etree.ElementTree as ET

ROOT = '/mnt/d/claude_workspace/pov3d'
PKG_DIR = os.path.join(ROOT, 'POV3D_硬件资料包_DR1V90主控与GW5A桥接模块_2026-09-15')
OUT_DIR = os.path.join(PKG_DIR, '03_两模组对接关系')
OUT = os.path.join(OUT_DIR, 'DR1V90主控_GW5A桥接模块_对接关系表_2026-09-15.xlsx')
DATE = '2026-09-15'
VERSION = 'v3'

SRC = dict(
    pinmap=ROOT + '/pcb/dr1v90_core_v1/05_机读数据/DR1V90GEG484_pinmap.csv',
    adc=ROOT + '/dr1v90/uplink_tx/soc_prj/uisrc/04_pin/uplink_pin.adc',
    pkg='/mnt/c/Gowin/Gowin_V1.9.12.03_x64/IDE/data/device/GW5A-25A/UBGA324.json',
    tsv=ROOT + '/dr1v90/gw5a_loop/pins_v2.tsv',
    ug985=PKG_DIR + '/02_GW5A桥接FPGA模块_小梅哥ACG525-CORE-V2/01_芯片数据手册/UG985_V1.7.2_GW5A-25器件Pinout手册.pdf',
    pov_adc=ROOT + '/dr1v90/td_pov/soc_prj/uisrc/04_pin/fpga_pin.adc',
    panel_adc=ROOT + '/dr1v90/constraints/panel_pins_dr1.adc',
)

DATA = json.loads(r'''{
 "dr1_pinmap":
  {"A16":[33, "IO_R9P_33", "R9_33", "P", "ADC3P"],
   "A17":[33, "IO_R9N_33", "R9_33", "N", "ADC3N"],
   "A18":[33, "IO_R10P_33", "R10_33", "P", "ADC11P"],
   "A19":[33, "IO_R10N_33", "R10_33", "N", "ADC11N"],
   "A21":[33, "IO_R15P_33", "R15_33", "P", "ADC12P"],
   "A22":[33, "IO_R15N_33", "R15_33", "N", "ADC12N"],
   "AA11":[11, "IO_L8P_11", "L8_11", "P", ""],
   "AA12":[11, "IO_L7P_11", "L7_11", "P", ""],
   "AA4":[11, "IO_L18N_11", "L18_11", "N", ""],
   "AA6":[11, "IO_L14N_11", "L14_11", "N", "GCLKIOC0"],
   "AA7":[11, "IO_L14P_11", "L14_11", "P", "GCLKIOT0"],
   "AA8":[11, "IO_L11N_11", "L11_11", "N", "GCLKIOC3"],
   "AA9":[11, "IO_L11P_11", "L11_11", "P", "GCLKIOT3"],
   "AB1":[11, "IO_L15N_11", "L15_11", "N", ""],
   "AB10":[11, "IO_L9P_11", "L9_11", "P", ""],
   "AB11":[11, "IO_L8N_11", "L8_11", "N", ""],
   "AB12":[11, "IO_L7N_11", "L7_11", "N", ""],
   "AB2":[11, "IO_L15P_11", "L15_11", "P", ""],
   "AB4":[11, "IO_L16N_11", "L16_11", "N", ""],
   "AB5":[11, "IO_L16P_11", "L16_11", "P", ""],
   "AB6":[11, "IO_L17N_11", "L17_11", "N", ""],
   "AB7":[11, "IO_L17P_11", "L17_11", "P", ""],
   "AB9":[11, "IO_L9N_11", "L9_11", "N", ""],
   "B15":[33, "IO_R7N_33", "R7_33", "N", "ADC2N"],
   "B16":[33, "IO_R8P_33", "R8_33", "P", "ADC10P"],
   "B17":[33, "IO_R8N_33", "R8_33", "N", "ADC10N"],
   "B19":[33, "IO_R13P_33", "R13_33", "P", "GCLKIOT1"],
   "B20":[33, "IO_R13N_33", "R13_33", "N", "GCLKIOC1"],
   "B21":[33, "IO_R18P_33", "R18_33", "P", "ADC13P"],
   "B22":[33, "IO_R18N_33", "R18_33", "N", "ADC13N"],
   "C15":[33, "IO_R7P_33", "R7_33", "P", "ADC2P"],
   "C17":[33, "IO_R11P_33", "R11_33", "P", "GCLKIOT3"],
   "C18":[33, "IO_R11N_33", "R11_33", "N", "GCLKIOC3"],
   "C19":[33, "IO_R12N_33", "R12_33", "N", "GCLKIOC2"],
   "C20":[33, "IO_R14N_33", "R14_33", "N", "GCLKIOC0;ADC4N"],
   "C22":[33, "IO_R16N_33", "R16_33", "N", ""],
   "D15":[33, "IO_R3N_33", "R3_33", "N", "ADC1N"],
   "D16":[33, "IO_R2P_33", "R2_33", "P", "ADC8P"],
   "D17":[33, "IO_R2N_33", "R2_33", "N", "ADC8N"],
   "D18":[33, "IO_R12P_33", "R12_33", "P", "GCLKIOT2"],
   "D20":[33, "IO_R14P_33", "R14_33", "P", "GCLKIOT0;ADC4P"],
   "D21":[33, "IO_R17N_33", "R17_33", "N", "ADC5N"],
   "D22":[33, "IO_R16P_33", "R16_33", "P", ""],
   "E15":[33, "IO_R3P_33", "R3_33", "P", "ADC1P"],
   "E16":[33, "IO_R1N_33", "R1_33", "N", "ADC0N"],
   "E18":[33, "IO_R5N_33", "R5_33", "N", "ADC9N"],
   "E19":[33, "IO_R21P_33", "R21_33", "P", "ADC14P"],
   "E20":[33, "IO_R21N_33", "R21_33", "N", "ADC14N"],
   "E21":[33, "IO_R17P_33", "R17_33", "P", "ADC5P"],
   "F16":[33, "IO_R1P_33", "R1_33", "P", "ADC0P"],
   "F17":[33, "IO_R6N_33", "R6_33", "N", ""],
   "F18":[33, "IO_R5P_33", "R5_33", "P", "ADC9P"],
   "F19":[33, "IO_R20N_33", "R20_33", "N", "ADC6N"],
   "F21":[33, "IO_R23P_33", "R23_33", "P", ""],
   "F22":[33, "IO_R23N_33", "R23_33", "N", ""],
   "G15":[33, "IO_R4P_33", "R4_33", "P", ""],
   "G16":[33, "IO_R4N_33", "R4_33", "N", ""],
   "G17":[33, "IO_R6P_33", "R6_33", "P", ""],
   "G19":[33, "IO_R20P_33", "R20_33", "P", "ADC6P"],
   "G20":[33, "IO_R22P_33", "R22_33", "P", "ADC7P"],
   "G21":[33, "IO_R22N_33", "R22_33", "N", "ADC7N"],
   "G22":[33, "IO_R24N_33", "R24_33", "N", "ADC15N"],
   "H19":[33, "IO_R19P_33", "R19_33", "P", ""],
   "H20":[33, "IO_R19N_33", "R19_33", "N", ""],
   "H22":[33, "IO_R24P_33", "R24_33", "P", "ADC15P"],
   "R6":[11, "IO_L19P_11", "L19_11", "P", ""],
   "T4":[11, "IO_L20P_11", "L20_11", "P", ""],
   "T6":[11, "IO_L19N_11", "L19_11", "N", ""],
   "U10":[11, "IO_L6P_11", "L6_11", "P", ""],
   "U11":[11, "IO_L5N_11", "L5_11", "N", ""],
   "U12":[11, "IO_L5P_11", "L5_11", "P", ""],
   "U4":[11, "IO_L20N_11", "L20_11", "N", ""],
   "U5":[11, "IO_L22N_11", "L22_11", "N", ""],
   "U6":[11, "IO_L22P_11", "L22_11", "P", ""],
   "U9":[11, "IO_L6N_11", "L6_11", "N", ""],
   "V10":[11, "IO_L1P_11", "L1_11", "P", ""],
   "V12":[11, "IO_L4P_11", "L4_11", "P", ""],
   "V4":[11, "IO_L21N_11", "L21_11", "N", ""],
   "V5":[11, "IO_L21P_11", "L21_11", "P", ""],
   "V7":[11, "IO_L23P_11", "L23_11", "P", ""],
   "V8":[11, "IO_L2P_11", "L2_11", "P", ""],
   "V9":[11, "IO_L1N_11", "L1_11", "N", ""],
   "W10":[11, "IO_L3N_11", "L3_11", "N", ""],
   "W11":[11, "IO_L3P_11", "L3_11", "P", ""],
   "W12":[11, "IO_L4N_11", "L4_11", "N", ""],
   "W5":[11, "IO_L24N_11", "L24_11", "N", ""],
   "W6":[11, "IO_L24P_11", "L24_11", "P", ""],
   "W7":[11, "IO_L23N_11", "L23_11", "N", ""],
   "W8":[11, "IO_L2N_11", "L2_11", "N", ""],
   "Y10":[11, "IO_L10N_11", "L10_11", "N", ""],
   "Y11":[11, "IO_L10P_11", "L10_11", "P", ""],
   "Y19":[31, "IO_R11P_31", "R11_31", "P", "GCLKIOT3"],
   "Y4":[11, "IO_L18P_11", "L18_11", "P", ""],
   "Y5":[11, "IO_L13N_11", "L13_11", "N", "GCLKIOC1"],
   "Y6":[11, "IO_L13P_11", "L13_11", "P", "GCLKIOT1"],
   "Y8":[11, "IO_L12N_11", "L12_11", "N", "GCLKIOC2"],
   "Y9":[11, "IO_L12P_11", "L12_11", "P", "GCLKIOT2"]}
,
 "cep_chain":
  [["CEP1", 1, "VCC_CEP1", "", "", "", "", "", "", "", ""],
   ["CEP1", 2, "GND", "", "", "", "", "", "", "", ""],
   ["CEP1", 3, "H19", "CEP1_1P", "H19", "R191", "33R", 2, "BK33_L19P", "IO_R19P_33", "H19"],
   ["CEP1", 4, "H20", "CEP1_1N", "H20", "R191", "33R", 1, "BK33_L19N", "IO_R19N_33", "H20"],
   ["CEP1", 5, "G15", "CEP1_2P", "G15", "R187", "33R", 4, "BK33_L4P", "IO_R4P_33", "G15"],
   ["CEP1", 6, "G16", "CEP1_2N", "G16", "R187", "33R", 3, "BK33_L4N", "IO_R4N_33", "G16"],
   ["CEP1", 7, "C17", "CEP1_3P", "C17", "R188", "33R", 1, "BK33_L11P", "IO_R11P_33", "C17"],
   ["CEP1", 8, "C18", "CEP1_3N", "C18", "R188", "33R", 2, "BK33_L11N", "IO_R11N_33", "C18"],
   ["CEP1", 9, "D18", "CEP1_4P", "D18", "R188", "33R", 3, "BK33_L12P", "IO_R12P_33", "D18"],
   ["CEP1", 10, "C19", "CEP1_4N", "C19", "R188", "33R", 4, "BK33_L12N", "IO_R12N_33", "C19"],
   ["CEP1", 11, "B19", "CEP1_5P", "B19", "R189", "33R", 1, "BK33_L13P", "IO_R13P_33", "B19"],
   ["CEP1", 12, "B20", "CEP1_5N", "B20", "R189", "33R", 2, "BK33_L13N", "IO_R13N_33", "B20"],
   ["CEP1", 13, "D22", "CEP1_6P", "D22", "R189", "33R", 3, "BK33_L16P", "IO_R16P_33", "D22"],
   ["CEP1", 14, "C22", "CEP1_6N", "C22", "R189", "33R", 4, "BK33_L16N", "IO_R16N_33", "C22"],
   ["CEP1", 15, "F21", "CEP1_7P", "F21", "R190", "33R", 1, "BK33_L23P", "IO_R23P_33", "F21"],
   ["CEP1", 16, "F22", "CEP1_7N", "F22", "R190", "33R", 2, "BK33_L23N", "IO_R23N_33", "F22"],
   ["CEP1", 17, "G17", "CEP1_8P", "G17", "R190", "33R", 3, "BK33_L6P", "IO_R6P_33", "G17"],
   ["CEP1", 18, "F17", "CEP1_8N", "F17", "R190", "33R", 4, "BK33_L6N", "IO_R6N_33", "F17"],
   ["CEP1", 19, "A16", "CEP1_9P", "A16", "R187", "33R", 2, "BK33_ADC3_L9P", "IO_R9P_33", "A16"],
   ["CEP1", 20, "A17", "CEP1_9N", "A17", "R187", "33R", 1, "BK33_ADC3_L9N", "IO_R9N_33", "A17"],
   ["CEP1", 21, "C15", "CEP1_10P", "C15", "R191", "33R", 4, "BK33_ADC2_L7P", "IO_R7P_33", "C15"],
   ["CEP1", 22, "B15", "CEP1_10N", "B15", "R191", "33R", 3, "BK33_ADC2_L7N", "IO_R7N_33", "B15"],
   ["CEP1", 23, "B16", "CEP1_11P", "B16", "R192", "33R", 2, "BK33_ADC10_L8P", "IO_R8P_33", "B16"],
   ["CEP1", 24, "B17", "CEP1_11N", "B17", "R192", "33R", 1, "BK33_ADC10_L8N", "IO_R8N_33", "B17"],
   ["CEP1", 25, "D20", "CEP1_12P", "D20", "R192", "33R", 3, "BK33_ADC4_L14P", "IO_R14P_33", "D20"],
   ["CEP1", 26, "C20", "CEP1_12N", "C20", "R192", "33R", 4, "BK33_ADC4_L14N", "IO_R14N_33", "C20"],
   ["CEP1", 27, "E21", "CEP1_13P", "E21", "R193", "33R", 2, "BK33_ADC5_L17P", "IO_R17P_33", "E21"],
   ["CEP1", 28, "D21", "CEP1_13N", "D21", "R193", "33R", 1, "BK33_ADC5_L17N", "IO_R17N_33", "D21"],
   ["CEP1", 29, "E19", "CEP1_14P", "E19", "R193", "33R", 4, "BK33_ADC14_L21P", "IO_R21P_33", "E19"],
   ["CEP1", 30, "E20", "CEP1_14N", "E20", "R193", "33R", 3, "BK33_ADC14_L21N", "IO_R21N_33", "E20"],
   ["CEP1", 31, "G20", "CEP1_15P", "G20", "R194", "33R", 2, "BK33_ADC7_L22P", "IO_R22P_33", "G20"],
   ["CEP1", 32, "G21", "CEP1_15N", "G21", "R194", "33R", 1, "BK33_ADC7_L22N", "IO_R22N_33", "G21"],
   ["CEP1", 33, "G19", "CEP1_16P", "G19", "R194", "33R", 3, "BK33_ADC6_L20P", "IO_R20P_33", "G19"],
   ["CEP1", 34, "F19", "CEP1_16N", "F19", "R194", "33R", 4, "BK33_ADC6_L20N", "IO_R20N_33", "F19"],
   ["CEP1", 35, "F18", "CEP1_17P", "F18", "R195", "33R", 1, "BK33_ADC9_L5P", "IO_R5P_33", "F18"],
   ["CEP1", 36, "E18", "CEP1_17N", "E18", "R195", "33R", 2, "BK33_ADC9_L5N", "IO_R5N_33", "E18"],
   ["CEP1", 37, "D16", "CEP1_18P", "D16", "R195", "33R", 4, "BK33_ADC8_L2P", "IO_R2P_33", "D16"],
   ["CEP1", 38, "D17", "CEP1_18N", "D17", "R195", "33R", 3, "BK33_ADC8_L2N", "IO_R2N_33", "D17"],
   ["CEP1", 39, "A21", "CEP1_19P", "A21", "R197", "33R", 2, "BK33_ADC12_L15P", "IO_R15P_33", "A21"],
   ["CEP1", 40, "A22", "CEP1_19N", "A22", "R197", "33R", 1, "BK33_ADC12_L15N", "IO_R15N_33", "A22"],
   ["CEP1", 41, "A18", "CEP1_20P", "A18", "R197", "33R", 4, "BK33_ADC11_L10P", "IO_R10P_33", "A18"],
   ["CEP1", 42, "A19", "CEP1_20N", "A19", "R197", "33R", 3, "BK33_ADC11_L10N", "IO_R10N_33", "A19"],
   ["CEP1", 43, "F16", "CEP1_21P", "F16", "R196", "33R", 1, "BK33_ADC0_L1P", "IO_R1P_33", "F16"],
   ["CEP1", 44, "E16", "CEP1_21N", "E16", "R196", "33R", 2, "BK33_ADC0_L1N", "IO_R1N_33", "E16"],
   ["CEP1", 45, "E15", "CEP1_22P", "E15", "R196", "33R", 3, "BK33_ADC1_L3P", "IO_R3P_33", "E15"],
   ["CEP1", 46, "D15", "CEP1_22N", "D15", "R196", "33R", 4, "BK33_ADC1_L3N", "IO_R3N_33", "D15"],
   ["CEP1", 47, "B21", "CEP1_23P", "B21", "R198", "33R", 4, "BK33_ADC13_L18P", "IO_R18P_33", "B21"],
   ["CEP1", 48, "B22", "CEP1_23N", "B22", "R198", "33R", 3, "BK33_ADC13_L18N", "IO_R18N_33", "B22"],
   ["CEP1", 49, "H22", "CEP1_24P", "H22", "R198", "33R", 1, "BK33_ADC15_L24P", "IO_R24P_33", "H22"],
   ["CEP1", 50, "G22", "CEP1_24N", "G22", "R198", "33R", 2, "BK33_ADC15_L24N", "IO_R24N_33", "G22"],
   ["CEP2", 1, "VCC_CEP2", "", "", "", "", "", "", "", ""],
   ["CEP2", 2, "GND", "", "", "", "", "", "", "", ""],
   ["CEP2", 3, "V12", "CEP2_1P", "V12", "R199", "33R", 1, "BK11_L4P", "IO_L4P_11", "V12"],
   ["CEP2", 4, "W12", "CEP2_1N", "W12", "R199", "33R", 2, "BK11_L4N", "IO_L4N_11", "W12"],
   ["CEP2", 5, "AA12", "CEP2_2P", "AA12", "R199", "33R", 3, "BK11_L7P", "IO_L7P_11", "AA12"],
   ["CEP2", 6, "AB12", "CEP2_2N", "AB12", "R199", "33R", 4, "BK11_L7N", "IO_L7N_11", "AB12"],
   ["CEP2", 7, "Y19", "CEP2_3P", "Y9", "R200", "33R", 1, "BK11_L12P", "IO_L12P_11", "Y9"],
   ["CEP2", 8, "Y8", "CEP2_3N", "Y8", "R200", "33R", 2, "BK11_L12N", "IO_L12N_11", "Y8"],
   ["CEP2", 9, "AA11", "CEP2_4P", "AA11", "R200", "33R", 3, "BK11_L8P", "IO_L8P_11", "AA11"],
   ["CEP2", 10, "AB11", "CEP2_4N", "AB11", "R200", "33R", 4, "BK11_L8N", "IO_L8N_11", "AB11"],
   ["CEP2", 11, "Y11", "CEP2_5P", "Y11", "R201", "33R", 1, "BK11_L10P", "IO_L10P_11", "Y11"],
   ["CEP2", 12, "Y10", "CEP2_5N", "Y10", "R201", "33R", 2, "BK11_L10N", "IO_L10N_11", "Y10"],
   ["CEP2", 13, "AB10", "CEP2_6P", "AB10", "R201", "33R", 3, "BK11_L9P", "IO_L9P_11", "AB10"],
   ["CEP2", 14, "AB9", "CEP2_6N", "AB9", "R201", "33R", 4, "BK11_L9N", "IO_L9N_11", "AB9"],
   ["CEP2", 15, "AA9", "CEP2_7P", "AA9", "R202", "33R", 1, "BK11_L11P", "IO_L11P_11", "AA9"],
   ["CEP2", 16, "AA8", "CEP2_7N", "AA8", "R202", "33R", 2, "BK11_L11N", "IO_L11N_11", "AA8"],
   ["CEP2", 17, "AA7", "CEP2_8P", "AA7", "R202", "33R", 3, "BK11_L14P", "IO_L14P_11", "AA7"],
   ["CEP2", 18, "AA6", "CEP2_8N", "AA6", "R202", "33R", 4, "BK11_L14N", "IO_L14N_11", "AA6"],
   ["CEP2", 19, "Y6", "CEP2_9P", "Y6", "R203", "33R", 1, "BK11_L13P", "IO_L13P_11", "Y6"],
   ["CEP2", 20, "Y5", "CEP2_9N", "Y5", "R203", "33R", 2, "BK11_L13N", "IO_L13N_11", "Y5"],
   ["CEP2", 21, "AB5", "CEP2_10P", "AB5", "R203", "33R", 3, "BK11_L16P", "IO_L16P_11", "AB5"],
   ["CEP2", 22, "AB4", "CEP2_10N", "AB4", "R203", "33R", 4, "BK11_L16N", "IO_L16N_11", "AB4"],
   ["CEP2", 23, "W6", "CEP2_11P", "W6", "R204", "33R", 1, "BK11_L24P", "IO_L24P_11", "W6"],
   ["CEP2", 24, "W5", "CEP2_11N", "W5", "R204", "33R", 2, "BK11_L24N", "IO_L24N_11", "W5"],
   ["CEP2", 25, "Y4", "CEP2_12P", "Y4", "R204", "33R", 3, "BK11_L18P", "IO_L18P_11", "Y4"],
   ["CEP2", 26, "AA4", "CEP2_12N", "AA4", "R204", "33R", 4, "BK11_L18N", "IO_L18N_11", "AA4"],
   ["CEP2", 27, "V5", "CEP2_13P", "V5", "R205", "33R", 1, "BK11_L21P", "IO_L21P_11", "V5"],
   ["CEP2", 28, "V4", "CEP2_13N", "V4", "R205", "33R", 2, "BK11_L21N", "IO_L21N_11", "V4"],
   ["CEP2", 29, "T4", "CEP2_14P", "T4", "R205", "33R", 3, "BK11_L20P", "IO_L20P_11", "T4"],
   ["CEP2", 30, "U4", "CEP2_14N", "U4", "R205", "33R", 4, "BK11_L20N", "IO_L20N_11", "U4"],
   ["CEP2", 31, "AB7", "CEP2_15P", "AB7", "R206", "33R", 4, "BK11_L17P", "IO_L17P_11", "AB7"],
   ["CEP2", 32, "AB6", "CEP2_15N", "AB6", "R206", "33R", 3, "BK11_L17N", "IO_L17N_11", "AB6"],
   ["CEP2", 33, "AB2", "CEP2_16P", "AB2", "R206", "33R", 2, "BK11_L15P", "IO_L15P_11", "AB2"],
   ["CEP2", 34, "AB1", "CEP2_16N", "AB1", "R206", "33R", 1, "BK11_L15N", "IO_L15N_11", "AB1"],
   ["CEP2", 35, "U6", "CEP2_17P", "U6", "R207", "33R", 3, "BK11_L22P", "IO_L22P_11", "U6"],
   ["CEP2", 36, "U5", "CEP2_17N", "U5", "R207", "33R", 4, "BK11_L22N", "IO_L22N_11", "U5"],
   ["CEP2", 37, "R6", "CEP2_18P", "R6", "R207", "33R", 2, "BK11_L19P", "IO_L19P_11", "R6"],
   ["CEP2", 38, "T6", "CEP2_18N", "T6", "R207", "33R", 1, "BK11_L19N", "IO_L19N_11", "T6"],
   ["CEP2", 39, "V7", "CEP2_19P", "V7", "R208", "33R", 2, "BK11_L23P", "IO_L23P_11", "V7"],
   ["CEP2", 40, "W7", "CEP2_19N", "W7", "R208", "33R", 1, "BK11_L23N", "IO_L23N_11", "W7"],
   ["CEP2", 41, "V8", "CEP2_20P", "V8", "R208", "33R", 4, "BK11_L2P", "IO_L2P_11", "V8"],
   ["CEP2", 42, "W8", "CEP2_20N", "W8", "R208", "33R", 3, "BK11_L2N", "IO_L2N_11", "W8"],
   ["CEP2", 43, "V10", "CEP2_21P", "V10", "R209", "33R", 2, "BK11_L1P", "IO_L1P_11", "V10"],
   ["CEP2", 44, "V9", "CEP2_21N", "V9", "R209", "33R", 1, "BK11_L1N", "IO_L1N_11", "V9"],
   ["CEP2", 45, "U10", "CEP2_22P", "U10", "R209", "33R", 4, "BK11_L6P", "IO_L6P_11", "U10"],
   ["CEP2", 46, "U9", "CEP2_22N", "U9", "R209", "33R", 3, "BK11_L6N", "IO_L6N_11", "U9"],
   ["CEP2", 47, "W11", "CEP2_23P", "W11", "R210", "33R", 2, "BK11_L3P", "IO_L3P_11", "W11"],
   ["CEP2", 48, "W10", "CEP2_23N", "W10", "R210", "33R", 1, "BK11_L3N", "IO_L3N_11", "W10"],
   ["CEP2", 49, "U12", "CEP2_24P", "U12", "R210", "33R", 4, "BK11_L5P", "IO_L5P_11", "U12"],
   ["CEP2", 50, "U11", "CEP2_24N", "U11", "R210", "33R", 3, "BK11_L5N", "IO_L5N_11", "U11"]]
,
 "adc":
  [["txclk", "G15", "LVDS18", "IO_R4P_33 (N=G16)"],
   ["tx[0]", "F16", "LVDS18", "IO_R1P_33 (N=E16) 复用 ADC0"],
   ["tx[1]", "D16", "LVDS18", "IO_R2P_33 (N=D17) 复用 ADC8"],
   ["tx[2]", "E15", "LVDS18", "IO_R3P_33 (N=D15) 复用 ADC1"],
   ["tx[3]", "F18", "LVDS18", "IO_R5P_33 (N=E18) 复用 ADC9"],
   ["tx[4]", "G17", "LVDS18", "IO_R6P_33 (N=F17)"],
   ["tx[5]", "C15", "LVDS18", "IO_R7P_33 (N=B15) 复用 ADC2"],
   ["tx[6]", "B16", "LVDS18", "IO_R8P_33 (N=B17) 复用 ADC10"],
   ["tx[7]", "A16", "LVDS18", "IO_R9P_33 (N=A17) 复用 ADC3"],
   ["tx[8]", "A18", "LVDS18", "IO_R10P_33 (N=A19) 复用 ADC11"],
   ["tx[9]", "A21", "LVDS18", "IO_R15P_33 (N=A22) 复用 ADC12"],
   ["tx[10]", "D22", "LVDS18", "IO_R16P_33 (N=C22)"],
   ["tx[11]", "H19", "LVDS18", "IO_R19P_33 (N=H20)"],
   ["tx[12]", "F21", "LVDS18", "IO_R23P_33 (N=F22)"]]
,
 "ds1200_t26":
  {"pulldown": ["D22", "A21"], "pullup": ["E16", "F16", "D17", "D16", "G15", "G16", "G17", "F17", "F18", "E18", "B16", "B17", "C15", "B15", "A18", "A19", "A17", "C22", "B21", "B22", "E21", "D21", "G19", "F19", "H19", "H20", "G20", "G21", "E20", "H22", "G22", "F21", "F22"]}
,
 "core":
  [["P1", 1, "", "VCC3P3", "", "", "", "", "", "", null],
   ["P1", 2, "", "VCC3P3", "", "", "", "", "", "", null],
   ["P1", 3, "", "VCC3P3", "", "", "", "", "", "", null],
   ["P1", 4, "", "VCC3P3", "", "", "", "", "", "", null],
   ["P1", 5, "", "VCCIO23", "", "", "", "", "", "", null],
   ["P1", 6, "", "VCCIO45", "", "", "", "", "", "", null],
   ["P1", 7, "", "VCCIO23", "", "", "", "", "", "", null],
   ["P1", 8, "", "VCCIO45", "", "", "", "", "", "", null],
   ["P1", 9, "", "VCCIO01", "", "", "", "", "", "", null],
   ["P1", 10, "", "VCCIO01", "", "", "", "", "", "", null],
   ["P1", 11, "", "GND", "", "", "", "", "", "", null],
   ["P1", 12, "", "GND", "", "", "", "", "", "", null],
   ["P1", 13, "", "GND", "", "", "", "", "", "", null],
   ["P1", 14, "", "GND", "", "", "", "", "", "", null],
   ["P1", 15, "B4_B29_N", "SD_CMD", "IOB29B", "V9", 4, "N", "GCLKC_11A", "T9", true],
   ["P1", 16, "B4_B35_N", "SD_DATA3", "IOB35B", "T10", 4, "N", "GCLKC_8", "R10", true],
   ["P1", 17, "B4_B52_N", "SD_CLK", "IOB52B", "P12", 4, "N", "D10", "N12", true],
   ["P1", 18, "B4_B35_P", "SD_DATA2", "IOB35A", "R10", 4, "P", "GCLKT_8", "T10", true],
   ["P1", 19, "B4_B33_N", "SD_DATA0", "IOB33B", "V10", 4, "N", "GCLKC_9A/EMCCLK", "U10", true],
   ["P1", 20, "B4_B45_N", "LCD_GPIO0", "IOB45B", "T11", 4, "N", "", "R11", true],
   ["P1", 21, "B4_B33_P", "SD_DATA1", "IOB33A", "U10", 4, "P", "GCLKT_9A/D13/BPLL_T_IN1", "V10", true],
   ["P1", 22, "B4_B45_P", "LCD_GPIO1", "IOB45A", "R11", 4, "P", "", "T11", true],
   ["P1", 23, "B4_B39_N", "GPIO35", "IOB39B", "V11", 4, "N", "", "U11", true],
   ["P1", 24, "B4_B56_N", "LCD_GPIO2", "IOB56B", "V15", 4, "N", "", "U15", true],
   ["P1", 25, "B4_B39_P", "GPIO34", "IOB39A", "U11", 4, "P", "", "V11", true],
   ["P1", 26, "B4_B56_P", "LCD_GPIO3", "IOB56A", "U15", 4, "P", "", "V15", true],
   ["P1", 27, "B4_B50_N", "GPIO33", "IOB50B", "V13", 4, "N", "D12", "U13", true],
   ["P1", 28, "B4_B60_N", "LCD_GPIO4", "IOB60B", "V16", 4, "N", "", "U16", true],
   ["P1", 29, "B4_B50_P", "GPIO32", "IOB50A", "U13", 4, "P", "D11", "V13", true],
   ["P1", 30, "B4_B60_P", "LCD_GPIO5", "IOB60A", "U16", 4, "P", "", "V16", true],
   ["P1", 31, "B3_B65_N", "GPIO31", "IOB65B", "P16", 3, "N", "DOUT", "P15", true],
   ["P1", 32, "B3_B71_N", "LCD_GPIO6", "IOB71B", "U18", 3, "N", "", "U17", true],
   ["P1", 33, "B3_B65_P", "GPIO30", "IOB65A", "P15", 3, "P", "", "P16", true],
   ["P1", 34, "B3_B71_P", "LCD_GPIO7", "IOB71A", "U17", 3, "P", "", "U18", true],
   ["P1", 35, "", "GND", "", "", "", "", "", "", null],
   ["P1", 36, "", "GND", "", "", "", "", "", "", null],
   ["P1", 37, "B3_B77_N", "GPIO29", "IOB77B", "P18", 3, "N", "", "P17", true],
   ["P1", 38, "B3_B73_N", "LCD_GPIO8", "IOB73B", "T18", 3, "N", "", "T17", true],
   ["P1", 39, "B3_B77_P", "GPIO28", "IOB77A", "P17", 3, "P", "", "P18", true],
   ["P1", 40, "B3_B73_P", "LCD_GPIO9", "IOB73A", "T17", 3, "P", "", "T18", true],
   ["P1", 41, "B3_B79_N", "GPIO27", "IOB79B", "N18", 3, "N", "", "N17", true],
   ["P1", 42, "B3_B69_N", "LCD_GPIO10", "IOB69B", "N14", 3, "N", "", "M14", true],
   ["P1", 43, "B3_B79_P", "GPIO26", "IOB79A", "N17", 3, "P", "", "N18", true],
   ["P1", 44, "B3_B69_P", "LCD_GPIO11", "IOB69A", "M14", 3, "P", "", "N14", true],
   ["P1", 45, "B3_B83_N", "GPIO25", "IOB83B", "L18", 3, "N", "", "L17", true],
   ["P1", 46, "B3_B75_N", "LCD_GPIO12", "IOB75B", "N16", 3, "N", "GCLKC_6B", "N15", true],
   ["P1", 47, "B3_B83_P", "GPIO24", "IOB83A", "L17", 3, "P", "", "L18", true],
   ["P1", 48, "B3_B75_P", "LCD_GPIO13", "IOB75A", "N15", 3, "P", "GCLKT_6B", "N16", true],
   ["P1", 49, "B3_B85_N", "GPIO23", "IOB85B", "K18", 3, "N", "", "K17", true],
   ["P1", 50, "B3_B81_N", "LCD_GPIO14", "IOB81B", "M18", 3, "N", "", "M16", true],
   ["P1", 51, "B3_B85_P", "GPIO22", "IOB85A", "K17", 3, "P", "", "K18", true],
   ["P1", 52, "B3_B81_P", "LCD_GPIO15", "IOB81A", "M16", 3, "P", "", "M18", true],
   ["P1", 53, "B3_B89_N", "GPIO21", "IOB89B", "H18", 3, "N", "GCLKC_7", "H17", true],
   ["P1", 54, "B3_B91_N", "LCD_GPIO16", "IOB91B", "L16", 3, "N", "GCLKC_6A", "L15", true],
   ["P1", 55, "B3_B89_P", "GPIO20", "IOB89A", "H17", 3, "P", "GCLKT_7/BPLL_T_IN0", "H18", true],
   ["P1", 56, "B3_B91_P", "LCD_GPIO17", "IOB91A", "L15", 3, "P", "GCLKT_6A", "L16", true],
   ["P1", 57, "", "GND", "", "", "", "", "", "", null],
   ["P1", 58, "", "GND", "", "", "", "", "", "", null],
   ["P1", 59, "B2_R31_N", "GPIO19", "IOR31B", "L13", 2, "N", "GCLKC_4/RPLL1_C_FB1", "L12", true],
   ["P1", 60, "B3_B67_N", "LCD_GPIO18", "IOB67B", "M13", 3, "N", "", "L14", true],
   ["P1", 61, "B2_R31_P", "GPIO18", "IOR31A", "L12", 2, "P", "GCLKT_4/RPLL1_T_IN0", "L13", true],
   ["P1", 62, "B3_B67_P", "LCD_GPIO19", "IOB67A", "L14", 3, "P", "", "M13", true],
   ["P1", 63, "B2_R29_N", "GPIO17", "IOR29B", "K13", 2, "N", "", "K12", true],
   ["P1", 64, "B3_B87_P", "LCD_GPIO20", "IOB87A", "J16", 3, "P", "", "", true],
   ["P1", 65, "B2_R29_P", "GPIO16", "IOR29A", "K12", 2, "P", "", "K13", true],
   ["P1", 66, "B2_R24_P", "LCD_GPIO21", "IOR24A", "H15", 2, "P", "", "", true],
   ["P1", 67, "B2_R26_N", "GPIO15", "IOR26B", "K14", 2, "N", "", "J13", true],
   ["P1", 68, "B2_R5_N", "LCD_GPIO22", "IOR5B", "G13", 2, "N", "", "H12", true],
   ["P1", 69, "B2_R26_P", "GPIO14", "IOR26A", "J13", 2, "P", "", "K14", true],
   ["P1", 70, "B2_R5_P", "LCD_GPIO23", "IOR5A", "H12", 2, "P", "", "G13", true],
   ["P1", 71, "B2_R33_N", "GPIO13", "IOR33B", "K16", 2, "N", "GCLKC_5/RPLL1_C_FB0", "K15", true],
   ["P1", 72, "B2_R14_N", "LCD_GPIO24", "IOR14B", "F16", 2, "N", "ADCOTEST", "F15", true],
   ["P1", 73, "B2_R33_P", "GPIO12", "IOR33A", "K15", 2, "P", "GCLKT_5/RPLL1_T_IN1", "K16", true],
   ["P1", 74, "B2_R14_P", "LCD_GPIO25", "IOR14A", "F15", 2, "P", "", "F16", true],
   ["P1", 75, "B2_R18_N", "GPIO11", "IOR18B", "H14", 2, "N", "", "H13", true],
   ["P1", 76, "B2_R16_N", "LCD_GPIO26", "IOR16B", "E18", 2, "N", "", "E16", true],
   ["P1", 77, "B2_R18_P", "GPIO10", "IOR18A", "H13", 2, "P", "", "H14", true],
   ["P1", 78, "B2_R16_P", "LCD_GPIO27", "IOR16A", "E16", 2, "P", "", "E18", true],
   ["P1", 79, "", "GND", "", "", "", "", "", "", null],
   ["P1", 80, "", "GND", "", "", "", "", "", "", null],
   ["P1", 81, "B2_R20_N", "GPIO9", "IOR20B", "F18", 2, "N", "", "F17", true],
   ["P1", 82, "B1_T91_N", "BEEP", "IOT91B", "A16", 1, "N", "RPLL0_C_FB0", "B16", true],
   ["P1", 83, "B2_R20_P", "GPIO8", "IOR20A", "F17", 2, "P", "", "F18", true],
   ["P1", 84, "B1_T91_P", "KEY0", "IOT91A", "B16", 1, "P", "RPLL0_T_IN1", "A16", true],
   ["P1", 85, "B2_R22_N", "GPIO7", "IOR22B", "G18", 2, "N", "", "G16", true],
   ["P1", 86, "B1_T87_N", "KEY1", "IOT87B", "A15", 1, "N", "", "C15", true],
   ["P1", 87, "B2_R22_P", "GPIO6", "IOR22A", "G16", 2, "P", "", "G18", true],
   ["P1", 88, "B1_T87_P", "KEY2", "IOT87A", "C15", 1, "P", "", "A15", true],
   ["P1", 89, "B2_R12_N", "GPIO5", "IOR12B", "D18", 2, "N", "ADCINCLK", "D17", true],
   ["P1", 90, "B1_T89_N", "LED1", "IOT89B", "C14", 1, "N", "", "D14", true],
   ["P1", 91, "B2_R12_P", "GPIO4", "IOR12A", "D17", 2, "P", "", "D18", true],
   ["P1", 92, "B1_T89_P", "LED0", "IOT89A", "D14", 1, "P", "RPLL0_T_FB1", "C14", true],
   ["P1", 93, "B2_R7_N", "GPIO3", "IOR7B", "G14", 2, "N", "", "F14", true],
   ["P1", 94, "", "FPGA_TDO", "", "", "", "", "", "", null],
   ["P1", 95, "B2_R7_P", "GPIO2", "IOR7A", "F14", 2, "P", "", "G14", true],
   ["P1", 96, "", "FPGA_TDI", "", "", "", "", "", "", null],
   ["P1", 97, "B2_R9_N", "GPIO1", "IOR9B", "C18", 2, "N", "MCKTEST", "C17", true],
   ["P1", 98, "", "FPGA_TMS", "", "", "", "", "", "", null],
   ["P1", 99, "B2_R9_P", "GPIO0", "IOR9A", "C17", 2, "P", "", "C18", true],
   ["P1", 100, "", "FPGA_TCK", "", "", "", "", "", "", null],
   ["P2", 1, "B7_T15_P", "I2S_DACDAT", "IOT15A", "E3", 7, "P", "", "E1", true],
   ["P2", 2, "B0_T58_P", "LED2", "IOT58A", "B9", 0, "P", "GCLKT_1/TPLL_T_IN2", "A9", true],
   ["P2", 3, "B7_T15_N", "ENET0_RX_DV", "IOT15B", "E1", 7, "N", "", "E3", true],
   ["P2", 4, "B0_T58_N", "LED3", "IOT58B", "A9", 0, "N", "GCLKC_1/TPLL_C_FB0", "B9", true],
   ["P2", 5, "B7_T7_P", "ENET0_RX_DATA0", "IOT7A", "G3", 7, "P", "", "G1", true],
   ["P2", 6, "B7_T17_P", "FPGA_SEG_DIO", "IOT17A", "F4", 7, "P", "", "F3", true],
   ["P2", 7, "B7_T7_N", "ENET0_RX_DATA1", "IOT7B", "G1", 7, "N", "", "G3", true],
   ["P2", 8, "B7_T17_N", "FPGA_SEG_RCLK", "IOT17B", "F3", 7, "N", "", "F4", true],
   ["P2", 9, "B7_T25_P", "ENET0_RX_DATA2", "IOT25A", "F6", 7, "P", "", "F5", true],
   ["P2", 10, "B7_T1_P", "FPGA_SEG_SCLK", "IOT1A", "H4", 7, "P", "GCLKT_15/LPLL0_T_IN0", "H3", true],
   ["P2", 11, "B7_T25_N", "ENET0_RX_DATA3", "IOT25B", "F5", 7, "N", "", "F6", true],
   ["P2", 12, "B7_T1_N", "I2S_ADCDAT", "IOT1B", "H3", 7, "N", "GCLKC_15", "H4", true],
   ["P2", 13, "B7_T23_P", "ENET0_MDIO", "IOT23A", "E4", 7, "P", "", "D3", true],
   ["P2", 14, "B7_T3_P", "ENET0_RX_CLK", "IOT3A", "L5", 7, "P", "GCLKT_16", "K5", true],
   ["P2", 15, "B7_T23_N", "ENET0_MDC", "IOT23B", "D3", 7, "N", "", "E4", true],
   ["P2", 16, "B7_T3_N", "I2S_BCLK", "IOT3B", "K5", 7, "N", "GCLKC_16", "L5", true],
   ["P2", 17, "B7_T27_P", "ENET0_TX_EN", "IOT27A", "C2", 7, "P", "", "C1", true],
   ["P2", 18, "B7_T9_P", "ENET0_INT_N", "IOT9A", "H7", 7, "P", "", "G6", true],
   ["P2", 19, "B7_T27_N", "ENET0_GTX_CLK", "IOT27B", "C1", 7, "N", "", "C2", true],
   ["P2", 20, "B7_T9_N", "ENET0_RESET", "IOT9B", "G6", 7, "N", "", "H7", true],
   ["P2", 21, "", "GND", "", "", "", "", "", "", null],
   ["P2", 22, "", "GND", "", "", "", "", "", "", null],
   ["P2", 23, "B7_T19_P", "ENET0_TX_DATA0", "IOT19A", "D2", 7, "P", "", "D1", true],
   ["P2", 24, "B7_T13_P", "I2S_ADCLRC", "IOT13A", "J7", 7, "P", "", "J6", true],
   ["P2", 25, "B7_T19_N", "ENET0_TX_DATA1", "IOT19B", "D1", 7, "N", "", "D2", true],
   ["P2", 26, "B7_T13_N", "I2S_MCLK", "IOT13B", "J6", 7, "N", "", "J7", true],
   ["P2", 27, "B7_T11_P", "ENET0_TX_DATA2", "IOT11A", "F2", 7, "P", "", "F1", true],
   ["P2", 28, "B7_T21_P", "AUD_I2C_SCL", "IOT21A", "L7", 7, "P", "", "K6", true],
   ["P2", 29, "B7_T11_N", "ENET0_TX_DATA3", "IOT11B", "F1", 7, "N", "", "F2", true],
   ["P2", 30, "B7_T21_N", "I2S_DACLRC", "IOT21B", "K6", 7, "N", "", "L7", true],
   ["P2", 31, "B6_L3_CK_P", "", "IOL3A", "H2", 6, "P", "GCLKT_14/LPLL0_T_IN2", "H1", true],
   ["P2", 32, "B7_T5_N", "AUD_I2C_SDA", "IOT5B", "H5", 7, "N", "", "", true],
   ["P2", 33, "B6_L3_CK_N", "", "IOL3B", "H1", 6, "N", "GCLKC_14/LPLL0_C_FB0", "H2", true],
   ["P2", 34, "B6_L7_N", "", "IOL7B", "J1", 6, "N", "", "", true],
   ["P2", 35, "B6_L12_P", "", "IOL12A", "K2", 6, "P", "", "K1", true],
   ["P2", 36, "B6_L5_CK_P", "LT_2P5_CLK_P", "IOL5A", "K4", 6, "P", "GCLKT_13/LPLL0_T_IN1", "K3", true],
   ["P2", 37, "B6_L12_N", "", "IOL12B", "K1", 6, "N", "", "K2", true],
   ["P2", 38, "B6_L5_CK_N", "LT_2P5_CLK_N", "IOL5B", "K3", 6, "N", "GCLKC_13/LPLL0_C_FB1", "K4", true],
   ["P2", 39, "B6_L14_P", "LT_2P5_2_P", "IOL14A", "L2", 6, "P", "LPLL1_T_IN0", "L1", true],
   ["P2", 40, "B6_L9_P", "LT_2P5_1_P", "IOL9A", "L4", 6, "P", "", "L3", true],
   ["P2", 41, "B6_L14_N", "LT_2P5_2_N", "IOL14B", "L1", 6, "N", "", "L2", true],
   ["P2", 42, "B6_L9_N", "LT_2P5_1_N", "IOL9B", "L3", 6, "N", "", "L4", true],
   ["P2", 43, "", "GND", "", "", "", "", "", "", null],
   ["P2", 44, "", "GND", "", "", "", "", "", "", null],
   ["P2", 45, "B6_L18_P", "LT_2P5_3_P", "IOL18A", "N2", 6, "P", "", "N1", true],
   ["P2", 46, "B6_L16_P", "", "IOL16A", "M3", 6, "P", "", "M1", true],
   ["P2", 47, "B6_L18_N", "LT_2P5_3_N", "IOL18B", "N1", 6, "N", "", "N2", true],
   ["P2", 48, "B6_L16_N", "", "IOL16B", "M1", 6, "N", "", "M3", true],
   ["P2", 49, "B6_L21_P", "LT_2P5_0_P", "IOL21A", "P2", 6, "P", "", "P1", true],
   ["P2", 50, "MIPI_RX_CLK_P", "", "M0_CKP", "L6", "MIPI", "P", "", "", null],
   ["P2", 51, "B6_L21_N", "LT_2P5_0_N", "IOL21B", "P1", 6, "N", "", "P2", true],
   ["P2", 52, "MIPI_RX_CLK_N", "", "M0_CKN", "M5", "MIPI", "N", "", "", null],
   ["P2", 53, "MIPI_RX_D0_P", "", "M0_D0P", "T2", "MIPI", "P", "", "", null],
   ["P2", 54, "MIPI_RX_D2_P", "", "M0_D2P", "N4", "MIPI", "P", "", "", null],
   ["P2", 55, "MIPI_RX_D0_N", "", "M0_D0N", "T1", "MIPI", "N", "", "", null],
   ["P2", 56, "MIPI_RX_D2_N", "", "M0_D2N", "N3", "MIPI", "N", "", "", null],
   ["P2", 57, "MIPI_RX_D1_P", "", "M0_D1P", "U2", "MIPI", "P", "", "", null],
   ["P2", 58, "MIPI_RX_D3_P", "", "M0_D3P", "P4", "MIPI", "P", "", "", null],
   ["P2", 59, "MIPI_RX_D1_N", "", "M0_D1N", "U1", "MIPI", "N", "", "", null],
   ["P2", 60, "MIPI_RX_D3_N", "", "M0_D3N", "P3", "MIPI", "N", "", "", null],
   ["P2", 61, "B5_B24_P", "HDMI_CEC", "IOB24A", "M8", 5, "P", "", "N8", true],
   ["P2", 62, "B5_B14_P", "SCL", "IOB14A", "N6", 5, "P", "SSPI_CLK", "P7", true],
   ["P2", 63, "B5_B24_N", "HDMI_HPD", "IOB24B", "N8", 5, "N", "", "M8", true],
   ["P2", 64, "B5_B14_N", "SDA", "IOB14B", "P7", 5, "N", "CLKHOLD_N/SSI3", "N6", true],
   ["P2", 65, "", "GND", "", "", "", "", "", "", null],
   ["P2", 66, "", "GND", "", "", "", "", "", "", null],
   ["P2", 67, "B5_B4_P", "USB_RXDP_P", "IOB4A", "N5", 5, "P", "D08/SDA", "P6", true],
   ["P2", 68, "B5_B8_P", "EEPROM_IIC_SCL", "IOB8A", "R3", 5, "P", "D05/SO/SSI1", "T3", true],
   ["P2", 69, "B5_B4_N", "USB_RXDP_N", "IOB4B", "P6", 5, "N", "D09/SCL/LPLL1_C_FB0", "N5", true],
   ["P2", 70, "B5_B8_N", "EEPROM_IIC_SDA", "IOB8B", "T3", 5, "N", "D06", "R3", true],
   ["P2", 71, "B5_B2_P", "HDMI_SDA", "IOB2A", "T4", 5, "P", "", "", true],
   ["P2", 72, "B5_B12_P", "DVI_TX2_P", "IOB12A", "R5", 5, "P", "GCLKT_10B/D07/SSPI_WPN/SSI2", "T5", true],
   ["P2", 73, "B5_B18_N", "HDMI_SCL", "IOB18B", "P8", 5, "N", "", "", true],
   ["P2", 74, "B5_B12_N", "DVI_TX2_N", "IOB12B", "T5", 5, "N", "GCLKC_10B/RDWR_B/LPLL1_C_IN1", "R5", true],
   ["P2", 75, "B5_B10_P", "USB_DXP_P", "IOB10A", "U5", 5, "P", "D03/SSPI_CS_N", "V5", true],
   ["P2", 76, "B5_B16_P", "DVI_TX1_P", "IOB16A", "T6", 5, "P", "", "V6", true],
   ["P2", 77, "B5_B10_N", "USB_DXP_N", "IOB10B", "V5", 5, "N", "D04/SI/SSI0", "U5", true],
   ["P2", 78, "B5_B16_N", "DVI_TX1_N", "IOB16B", "V6", 5, "N", "", "T6", true],
   ["P2", 79, "B5_B20_P", "USB_TERM_RXD_P", "IOB20A", "U7", 5, "P", "", "V7", true],
   ["P2", 80, "B5_B6_P", "DVI_TX0_P", "IOB6A", "R7", 5, "P", "", "T7", true],
   ["P2", 81, "B5_B20_N", "USB_TERM_RXD_N", "IOB20B", "V7", 5, "N", "", "U7", true],
   ["P2", 82, "B5_B6_N", "DVI_TX0_N", "IOB6B", "T7", 5, "N", "", "R7", true],
   ["P2", 83, "B5_B22_P", "UART_RXD", "IOB22A", "U8", 5, "P", "", "V8", true],
   ["P2", 84, "B5_B26_P", "DVI_CLK_P", "IOB26A", "M10", 5, "P", "GCLKT_9B", "N9", true],
   ["P2", 85, "B5_B22_N", "UART_TXD", "IOB22B", "V8", 5, "N", "", "U8", true],
   ["P2", 86, "B5_B26_N", "DVI_CLK_N", "IOB26B", "N9", 5, "N", "GCLKC_9B", "M10", true],
   ["P2", 87, "", "GND", "", "", "", "", "", "", null],
   ["P2", 88, "", "GND", "", "", "", "", "", "", null],
   ["P2", 89, "", "GND", "", "", "", "", "", "", null],
   ["P2", 90, "B4_B31_P", "M_GPIO_0", "IOB31A", "R8", 4, "P", "GCLKT_10A/D14", "T8", true],
   ["P2", 91, "", "GND", "", "", "", "", "", "", null],
   ["P2", 92, "B4_B31_N", "M_GPIO_1", "IOB31B", "T8", 4, "N", "GCLKC_10A/D15/BPLL_C_FB0", "R8", true],
   ["P2", 93, "B4_B43_P", "USB_RXDN_P", "IOB43A", "T12", 4, "P", "", "V12", true],
   ["P2", 94, "B4_B48_P", "USB_PULLUP_EN", "IOB48A", "M11", 4, "P", "", "N11", true],
   ["P2", 95, "B4_B43_N", "USB_RXDN_N", "IOB43B", "V12", 4, "N", "", "T12", true],
   ["P2", 96, "B4_B48_N", "MIPI_PWDN", "IOB48B", "N11", 4, "N", "", "M11", true],
   ["P2", 97, "", "VCCIO67", "", "", "", "", "", "", null],
   ["P2", 98, "B4_B41_P", "MIPI_SCLK", "IOB41A", "N10", 4, "P", "", "P11", true],
   ["P2", 99, "", "VCCIO67", "", "", "", "", "", "", null],
   ["P2", 100, "B4_B41_N", "MIPI_SDAT", "IOB41B", "P11", 4, "N", "", "N10", true]]
,
 "mipi_alias_p2":
  {"50": "B6_L27_P", "52": "B6_L27_N", "53": "B6_L23_P", "55": "B6_L23_N", "57": "B6_L25_P", "59": "B6_L25_N", "54": "B6_L29_P", "56": "B6_L29_N", "58": "B6_L31_P", "60": "B6_L31_N"}
,
 "ug985_cfg":
  {"IOB33B":["V10", "GCLKC_9A/EMCCLK/BPLL_C_IN1", 1369],
   "IOB89B":["H18", "GCLKC_7/BPLL_C_IN0", 1454],
   "IOR31B":["L13", "GCLKC_4/RPLL1_C_IN0/RPLL1_C_FB1", 1528],
   "IOR31A":["L12", "GCLKT_4/RPLL1_T_IN0/RPLL1_T_FB1", 1525],
   "IOR33B":["K16", "GCLKC_5/RPLL1_C_IN1/RPLL1_C_FB0", 1534],
   "IOR14B":["F16", "", 1497],
   "IOR33A":["K15", "GCLKT_5/RPLL1_T_IN1/RPLL1_T_FB0", 1531],
   "IOT91B":["A16", "RPLL0_C_IN1/RPLL0_C_FB0", 1671],
   "IOT91A":["B16", "RPLL0_T_IN1/RPLL0_T_FB0", 1668],
   "IOR12B":["D18", "", 1495],
   "IOT89B":["C14", "RPLL0_C_FB1", 1666],
   "IOR9B":["C18", "", 1544],
   "IOT58A":["B9", "GCLKT_1/TPLL_T_IN2/TPLL_T_FB0", 1622],
   "IOT58B":["A9", "GCLKC_1/TPLL_C_IN2/TPLL_C_FB0", 1625],
   "IOT1B":["H3", "GCLKC_15/LPLL0_C_IN0", 1567],
   "IOL3A":["H2", "GCLKT_14/LPLL0_T_IN2/LPLL0_T_FB0", 1480],
   "IOL3B":["H1", "GCLKC_14/LPLL0_C_IN2/LPLL0_C_FB0", 1483],
   "IOL5A":["K4", "GCLKT_13/LPLL0_T_IN1/LPLL0_T_FB1", 1486],
   "IOL5B":["K3", "GCLKC_13/LPLL0_C_IN1/LPLL0_C_FB1", 1489],
   "IOL14B":["L1", "LPLL1_C_IN0", 1472],
   "IOB4A":["N5", "D08/LPLL1_T_FB0", 1396],
   "IOB4B":["P6", "D09/LPLL1_C_FB0", 1397],
   "IOB12A":["R5", "GCLKT_10B/D07/SSPI_WPN/SSI2/LPLL1_T_IN1", 1337],
   "IOB31A":["R8", "GCLKT_10A/D14/BPLL_T_FB0", 1360]}

}''')

# =============================================================================
# 0. 查表
# =============================================================================
PM = DATA['dr1_pinmap']                       # ball -> [bank, name, pair, pol, alt]
PD = set(DATA['ds1200_t26']['pulldown'])
PU = set(DATA['ds1200_t26']['pullup'])
CHAIN = [dict(zip(['conn', 'pin', 'manual', 'net', 'label', 'res', 'rval', 'rch', 'bknet', 'io', 'ball'], r))
         for r in DATA['cep_chain']]
CEP_BY_BALL = {c['ball']: c for c in CHAIN if c['ball']}
CEP_BY_PIN = {(c['conn'], c['pin']): c for c in CHAIN}
CORE = [dict(zip(['conn', 'pin', 'net', 'alias', 'fpga', 'ball', 'bank', 'pol', 'cfg', 'mate', 'true'], r))
        for r in DATA['core']]
CORE_BY_NET = {c['net']: c for c in CORE if c['net']}
MIPI_ALIAS = DATA['mipi_alias_p2']

PAIR_BALLS = {}
for _b, (_bank, _name, _pair, _pol, _alt) in PM.items():
    if _pair:
        PAIR_BALLS.setdefault(_pair, {})[_pol] = _b


def dr1_mate(b):
    pair, pol = PM[b][2], PM[b][3]
    return PAIR_BALLS[pair]['N' if pol == 'P' else 'P']


def pwr_state(b):
    if b in PD:
        return '下拉到 GND'
    if b in PU:
        return '上拉到 VCCIO'
    return '随 HSWAPEN'


def pair_pwr(pb, nb):
    sp, sn = pwr_state(pb), pwr_state(nb)
    if sp == sn:
        if sp == '随 HSWAPEN':
            return 'DR1 上电~90 ms: P/N 均随 HSWAPEN(K16), 不受表 2-6 固定', False
        return f'DR1 上电~90 ms: P/N 均{sp}(表 2-6), 对端差分≈0', False
    return f'DR1 上电~90 ms 劈开対: P 端{sp} / N 端{sn}(表 2-6) ⇒ 对端看到稳定假差分电平', True


def alt_split(alt):
    toks = [t for t in (alt or '').split(';') if t]
    return '/'.join(t for t in toks if t.startswith('GCLK')), '/'.join(t for t in toks if t.startswith('ADC'))


VG = {0: 'VCCIO01', 1: 'VCCIO01', 2: 'VCCIO23', 3: 'VCCIO23', 4: 'VCCIO45', 5: 'VCCIO45', 6: 'VCCIO67', 7: 'VCCIO67'}
VG_NOTE = {
    'VCCIO01': '1.5V 固定(核心板 VCC1P5 经 FB4, bank0/1 挂 DDR3)',
    'VCCIO23': '建议 3.3V(底板经 P1.5/7 供)',
    'VCCIO45': '3.3V 固定(底板经 P1.6/8 供, 但不可选: 核心板 MSPI 启动 flash / 配置上拉 / 50M 时钟都在 VCC3P3)',
    'VCCIO67': '2.5V 固定(核心板 VCC2P5 经 FB3)',
}

# 配置复用口径 = 原厂 UG985 V1.7.2 Pin List UG324 (嵌入 core.cfg 仍是 IDE UBGA324.json 原值, 供 verify 核对 json)。
# 两者在连接器 154 个 IO 脚里有 24 脚不同 (DATA['ug985_cfg']): json 独有 MCKTEST/ADCINCLK/ADCOTEST (UG985 修订记录 v1.3.1 删除) 与
# IOB4A/IOB4B 的 SDA/SCL; UG985 独有 20 脚的 PLL IN/FB 复用 (如 IOB33B BPLL_C_IN1、IOB4A LPLL1_T_FB0)。Gowin 工具按 json 判双用途脚。
UG985_CFG = DATA['ug985_cfg']
UG985_REV_DROPPED = ('MCKTEST', 'ADCINCLK', 'ADCOTEST')


def ug_cfg(c):
    """UG985 口径的配置功能字符串 (c = CORE 记录)"""
    if c['fpga'] in UG985_CFG:
        assert UG985_CFG[c['fpga']][0] == c['ball'], c['fpga']
        return UG985_CFG[c['fpga']][1]
    return c['cfg'] or ''


def cfg_diff(c):
    """(json 独有, UG985 独有) 的配置功能 token"""
    jt = [t for t in (c['cfg'] or '').split('/') if t]
    ut = [t for t in ug_cfg(c).split('/') if t]
    return [t for t in jt if t not in ut], [t for t in ut if t not in jt]


def gw_cfg_split(cfg):
    toks = [t for t in (cfg or '').split('/') if t]
    clk = [t for t in toks if re.match(r'^(GCLK|[TBLR]PLL)', t)]
    return '/'.join(clk), '/'.join(t for t in toks if t not in clk)


def cfg_diff_note(c):
    jo, uo = cfg_diff(c)
    out = []
    if jo:
        out.append(f"IDE UBGA324.json 另列 {'/'.join(jo)}, UG985 V1.7.2 无" +
                   (' (UG985 修订记录 v1.3.1 删除) ⇒ 按普通 IO' if set(jo) <= set(UG985_REV_DROPPED) else ' ⇒ 本表不计; Gowin 工具按 json 判双用途脚'))
    if uo:
        out.append(f"UG985 V1.7.2 另列 {'/'.join(uo)}, IDE json 无")
    return '; '.join(out)


def cfg_cell(c, cfg, gclk):
    s = ' · '.join(x for x in (cfg, gclk) if x) or '—'
    d = cfg_diff_note(c)
    return s + (f' (UG985 口径; {d})' if d else '')


_UG_DIFF_PINS = [c for c in (dict(zip(['conn', 'pin', 'net', 'alias', 'fpga', 'ball', 'bank', 'pol', 'cfg', 'mate', 'true'], r)) for r in DATA['core'])
                 if c['net'] and c['fpga'].startswith('IO') and c['fpga'] in UG985_CFG]
UG_JSON_ONLY = sorted(c['fpga'] for c in _UG_DIFF_PINS if cfg_diff(c)[0])
UG_UG985_ONLY = sorted(c['fpga'] for c in _UG_DIFF_PINS if cfg_diff(c)[1])
assert len(_UG_DIFF_PINS) == len(UG985_CFG) == 24 and UG_JSON_ONLY == ['IOB4A', 'IOB4B', 'IOR12B', 'IOR14B', 'IOR9B'] and len(UG_UG985_ONLY) == 20, \
    (len(_UG_DIFF_PINS), UG_JSON_ONLY, len(UG_UG985_ONLY))


# =============================================================================
# 1. 契约 (目标板口径, 与芯片无关)
#    用户 2026-09-15 决定: "直接按目标板做接口" —— 每面 20 対 = UL_D[17:0] (18 数据 lane) + UL_CHK (校验 lane) + UL_CLK
#    阶段一 (8-bit, 现役 13-lane RTL) 只用 UL_D[11:0] + UL_CHK + UL_CLK = 14 対 (契约子集); 阶段二全用
# =============================================================================
VG_NOTE = {
    'VCCIO01': '1.5V 固定(核心板 VCC1P5 经 FB4, bank0/1 挂 DDR3)',
    'VCCIO23': '2.5V(V2 底板经 P1.5/7 供, 用户 09-15 D5 定; 本规划作下行 ELVDS 组 + 边带 SoC→桥 输入 2 根, 与官方 CB-V2 底板的 3.3V 不同)',
    'VCCIO45': '3.3V 固定(底板经 P1.6/8 供但不可选: 核心板 MSPI 启动 flash / 配置上拉 / 50M 时钟都在 VCC3P3; 本规划作上行接收组)',
    'VCCIO67': '2.5V 固定(核心板 VCC2P5 经 FB3; 本规划作下行 ELVDS 组 + 边带 桥→SoC 输出 2 根)',
}
PART = {'IOT': 'Top', 'IOB': 'Bottom', 'IOL': 'Left', 'IOR': 'Right'}


def part_of(fpga):
    return PART.get((fpga or '')[:3], '—')


_pairs = {}
for _c in CORE:
    if _c['net'] and not _c['net'].startswith('MIPI'):
        _pairs.setdefault(re.sub(r'_[PN]$', '', _c['net']), []).append(_c)
FULL = {k: v for k, v in _pairs.items() if len(v) == 2}
HALF = {k: v for k, v in _pairs.items() if len(v) == 1}
CORE_BY_PIN = {(c['conn'], c['pin']): c for c in CORE}


def base_of(net):
    return re.sub(r'_[PN]$', '', net)


# ---- 契约 20 対的逻辑序 (建议脚序): 阶段一 14 対连续且时钟居中, UL_D[14:12] / UL_D[17:15] 分在两端
PAIR_ORDER = ['D12', 'D13', 'D14', 'D0', 'D1', 'D2', 'D3', 'D4', 'D5', 'CLK', 'CHK',
              'D6', 'D7', 'D8', 'D9', 'D10', 'D11', 'D15', 'D16', 'D17']
PH1_KEYS = set(['D%d' % i for i in range(12)] + ['CHK', 'CLK'])
PH2_ONLY = ['D%d' % i for i in range(12, 18)]
assert len(PAIR_ORDER) == 20 and set(PAIR_ORDER) == PH1_KEYS | set(PH2_ONLY)
assert [j for j, k in enumerate(PAIR_ORDER) if k in PH1_KEYS] == list(range(3, 17))
CPOS = {k: (3 * j + 2, 3 * j + 3) for j, k in enumerate(PAIR_ORDER)}
DIFF_GND = [3 * j + 1 for j in range(21)]
PH1_SPAN = (CPOS['D0'][0] - 1, CPOS['D11'][1] + 1)        # 阶段一连同两端地的位置范围


def sname(k):
    return {'CLK': 'UL_CLK', 'CHK': 'UL_CHK'}.get(k) or f'UL_D[{k[1:]}]'


SB = [
    dict(pos=62, name='SB_ALIGNED', dir='桥 → SoC', cls='边带·握手',
         role='训练握手回传: 桥片全部 lane 相位找到 (st_all_aligned) → SoC 发端 rx_all_aligned; 发端见其连续稳定 TRAIN_HOLD = 64 拍才退出训练; '
              '不能用 st_link_up 代替 (要收到帧头才置位, 帧头只在净荷态发 ⇒ 死锁)',
         rtl='uplink_rx_top.st_all_aligned → uplink_tx_frame.rx_all_aligned', rate='准静态电平', ph1='用 (没有它 uplink_tx_frame 停在训练态)',
         ex='SoC 模组侧外部下拉 2.2 kΩ (已定 D4): 桥片未配置 / 配置中 / 配置失败 / 桥模组未上电时读"未对齐" —— GW5A 配置前及配置过程中所有 GPIO 默认弱上拉 '
            '(UG304 §3.3; 25K 弱上拉为 Medium 档, UG714-1.0.6 PUDC_B 注[1]), 只靠 SoC 片内弱下拉则两边强弱相近、电平不定, 可能读成已对齐; SoC 侧该输入不设片内上拉; '
            'SoC 在释放 SB_RSTN 且读到桥片 JTAG IDCODE 之前不采信 (已定 D4); 算式见 sheet5 «e:sideband_level»。'
            'SoC 模组侧如果串限流电阻, 2.2 kΩ 下拉必须放在串阻的连接器侧, 片内上拉禁用 —— 下拉若放在串阻与 SoC 焊盘之间会分压 (串 8.2 kΩ 时高电平只有约 0.5 V), 恒读"未对齐" '
            '(验证板 V3: 串 8.2 kΩ, 桥片未配置时焊盘 0.643 V < VIL 0.7 V, 余 57 mV ⇒ 桥模组侧 SB_RSTN 为低时不驱高, sheet5 «e:sideband_level»)'),
    dict(pos=63, name='SB_RSTN', dir='SoC → 桥', cls='边带·复位',
         role='桥片用户逻辑复位, 低有效 (不是重配置): SoC 未配置完 / 未读到桥片 IDCODE / 上行未开始发训练码之前按住桥片, 防止桥片在上电假电平上对齐',
         rtl='(SoC 侧待新增 bridge_rstn 输出) → eg4_bridge_top.rstn_pin', rate='准静态电平', ph1='用',
         ex='低有效; 桥模组侧外部下拉 2.2 kΩ (已定 D4): SoC 模组未上电 / 未驱动 / 配置中时桥片处于复位 (DR1 配置中 HSWAPEN = 0 用户 IO 弱上拉 IPU ≤153 µA @VCCIO 2.5V, '
            'DS1200 表 3-9: 2.2 kΩ 上 ≤0.34 V < GW5A LVCMOS25 VIL 0.7 V; «e:sideband_level»); 桥侧 RTL 两级同步 + 去毛刺 (建议)'),
    dict(pos=65, name='SB_UART_B2S', dir='桥 → SoC', cls='边带·回读',
         role='状态回读 UART (桥 TX → SoC RX): st_link_up / st_retrain_req / st_crc_err / st_phase_err / st_fifo_ovf / st_fifo_udf / st_fifo_level 等',
         rtl='(桥侧 UART TX 待定义, 替换 eg4_bridge_top 的 dbg_st 占位) → (SoC 侧 UART RX 待定义)', rate='UART 115200 8N1 (建议)', ph1='用',
         ex='空闲高 (桥侧 TX 驱动); SoC 侧 RX 不要求片内上拉 —— SoC 模组侧串 kΩ 级限流电阻时禁用片内上拉 (验证板 V3 串 8.2 kΩ, 开上拉则低电平过不了 VIL), SoC 读到桥片 IDCODE 之前不采信 RX; 桥片在 SB_RSTN 为低期间不把 TX 驱高 (建议, 验证期按强制执行: SoC 模组未上电时 SB_RSTN 被桥侧下拉为低, 桥片 RTL 与桥片 flash / 自测镜像都要满足, '
            '否则 TX 空闲 2.5V 经 33 Ω 灌进未上电 DR1 bank 钳位二极管, mA 级 ≫ DS1200 表 3-8 每 I/O 直流 350 µA, «e:powerup»)'),
    dict(pos=66, name='SB_UART_S2B', dir='SoC → 桥', cls='边带·回读',
         role='命令 / 参数下发 UART (SoC TX → 桥 RX), 可选; 状态回读至少要 SB_UART_B2S 一根',
         rtl='(SoC 侧 UART TX 待定义) → (桥侧 UART RX 待定义)', rate='UART 115200 8N1 (建议)', ph1='可选',
         ex='空闲高; 桥侧 RX 建议片内弱上拉; SoC 读到 IDCODE 前不驱动 (D6)'),
]
# ---- JTAG 4 根 (D3: 程序加载; D5: 契约面 2.5V, GW5A bank10 固定 3.3V ⇒ V2 电平转换)
#      core_pin = ACG525-CORE-V2 P1 脚号 (核心板原理图 p1 渲染图: 94 TDO / 96 TDI / 98 TMS / 100 TCK);
#      ball / fpga = 核心板原理图 p3 U1I Bank10 (A17 IOR1A/TCK, B18 IOR3A/TMS, D15 IOR1B/TDI, D16 IOR3B/TDO), verify() 再对 UBGA324.json CFG 字段
JTAG = [
    dict(pos=68, name='JTAG_TCK', dir='SoC → 桥', tap='TCK', core_pin=100, ball='A17', fpga='IOR1A', shift='2.5V → 3.3V',
         role='JTAG 时钟: 桥片位流加载 (写 SRAM) 与 IDCODE 在位检测',
         pull='V2: 转换器 A 口 (2.5V 侧) 下拉 2.2 kΩ + B 口 (3.3V 侧) 下拉 4.7 kΩ (建议; SoC 未上电 / 未驱动 / 配置中 / 下载器拔下时 TCK 静止为低: '
              'SoC 若像 DR1 配置期弱上拉 ≤153 µA @2.5V (DS1200 表 3-9), 2.2 kΩ 上 ≤0.34 V < 转换器 VIL 0.7 V, 10 kΩ 则最坏 1.53 V 不定; SoC 驱高负载 2.5 V / 2.2 kΩ = 1.14 mA); '
              'GW5A 侧 TCK 为输入、无片内上拉 (UG714 表 3-5), 不下拉则悬空'),
    dict(pos=70, name='JTAG_TMS', dir='SoC → 桥', tap='TMS', core_pin=98, ball='B18', fpga='IOR3A', shift='2.5V → 3.3V',
         role='JTAG 模式选择',
         pull='V2: 转换器 A 口 (2.5V 侧) 上拉 22 kΩ 到 V2 本地 2.5 V (建议; SoC 未上电 / 未驱动 / 配置中时转换器输入不悬空, TMS = 1)。静止电平约定 TCK 为低、TMS / TDI 为高: '
              'TMS / TDI 上拉与 SoC 配置期弱上拉同向 (DR1: E20 表 2-6 强制上拉、A16 / E19 随 HSWAPEN = 0 弱上拉), 电平确定; TAP 只在 TCK 上升沿动, TCK 被下拉住 ⇒ SoC 未驱动期间 TAP 不动; '
              'SoC 每次开始访问先发 ≥5 个 TMS = 1 的 TCK 复位 TAP, 不依赖上电态; 反灌: SoC IO 岛未上电时一只上拉经 22 kΩ + 33 Ω 注入 (2.625 − 0.5) / 22.03 kΩ = 96 µA; 验证板两面共用 TMS 时两只并联 11 kΩ, (2.625 − 0.5) / 11.03 kΩ = 193 µA; 均 ≤ DS1200 表 3-8 350 µA '
              '(桥模组 SoC 侧接电源的上拉须 ≥6.07 kΩ, 转换器输入不得带 bus-hold); SoC 驱低负载 2.5 V / 22 kΩ = 0.11 mA (共用 TMS 2.5 V / 11 kΩ = 0.23 mA);'
              'GW5A 侧 TMS 片内弱上拉 (UG714 表 3-5) 被转换器 B 口输出覆盖, 不起作用'),
    dict(pos=71, name='JTAG_TDI', dir='SoC → 桥', tap='TDI', core_pin=96, ball='D15', fpga='IOR1B', shift='2.5V → 3.3V',
         role='JTAG 数据入 (位流数据)',
         pull='V2: 转换器 A 口 (2.5V 侧) 上拉 22 kΩ 到 V2 本地 2.5 V (建议; 静止为高, 静止电平约定同 JTAG_TMS; 反灌 (2.625 − 0.5) / 22.03 kΩ = 96 µA ≤350 µA, SoC 驱低负载 0.11 mA); GW5A 侧 TDI 片内弱上拉 (UG714 表 3-5) 被转换器 B 口输出覆盖, 不起作用'),
    dict(pos=72, name='JTAG_TDO', dir='桥 → SoC', tap='TDO', core_pin=94, ball='D16', fpga='IOR3B', shift='3.3V → 2.5V',
         role='JTAG 数据出 (IDCODE / 状态寄存器回读)',
         pull='V2: 转换器 B 口 (3.3V 侧) 下拉 10 kΩ (必须; TDO 只在 Shift-DR / Shift-IR 驱动, 其余时间高阻, 下拉使 A 口输出确定为低 ⇒ TAP 不在移位态时不向 SoC 驱高; '
              'SoC 未上电或其 IO 岛掉电时 TCK 停 (被下拉)、TAP 进不了 Shift ⇒ TDO 为低 —— SoC 侧不在 TDO 上串限流电阻时的直流保护前提, 残余风险为 JTAG 访问进行中 SoC IO 岛掉电, 暴露窗口只在访问进行中 (位流加载约数秒, 另有 IDCODE 轮询); '
              '为此 SoC 每次 JTAG 访问结束都发 ≥5 个 TMS = 1 让 TAP 回到 Test-Logic-Reset ⇒ 静止时桥片 TDO 高阻、被 B 口下拉、转换器输出低, 无注入; '
              '验证期 FS03 先上电、最后断电, 访问中 FS03 掉电属违规场景, 接受此风险; 目标板 TDO 转换器带 OE 待定 «d:tdo_oe»); '
              'SoC 侧弱上拉 (建议): 桥模组未上电时转换器 Ioff 高阻, 读到全 1 只作"不在位"提示; 判定桥模组在位以 IDCODE 精确等于桥片 IDCODE (GW5A-25: 0x0001281B) 为准'),
]
JTAG_TCK_RATE = ('TCK ≤10 MHz (建议; 依据待定: 连接器 / 电平转换器 / 线长与 SoC 侧 JTAG 实现均未定, 取保守值); 上限参考 UG714 表 3-7 Tj_clk ≥10 ns (≤100 MHz)、'
                 'Tj_dvld TCK→TDO ≤3.0 ns。⚠ 冲突: UG714-1.0.6 (scratchpad 副本, 本包为 1.0.1 无此注) §3.4.1 注与表 3-7 注[1] "A 版本芯片 TCK 不得低于 15 MHz, 其他版本无最低频率" '
                 '—— 桥片若为 GW5A-25 A 版, ≤10 MHz 不可用 («d:bridge_ver»)')
SB_GND = [64, 67, 69, 73]
TOTAL_POS = 73
SB_POS = {s['name']: s['pos'] for s in SB}
JTAG_POS = {j['name']: j['pos'] for j in JTAG}
SE_ALL = SB + JTAG
assert sorted(DIFF_GND + [p for k in PAIR_ORDER for p in CPOS[k]] + [s['pos'] for s in SE_ALL] + SB_GND) == list(range(1, TOTAL_POS + 1))
assert [j['tap'] for j in JTAG] == ['TCK', 'TMS', 'TDI', 'TDO'] and all((j['dir'] == '桥 → SoC') == (j['tap'] == 'TDO') for j in JTAG)
assert all((j['dir'] == '桥 → SoC') == (j['shift'] == '3.3V → 2.5V') for j in JTAG)         # 转换方向 = 信号方向
_SE_NAME = {s['pos']: s['name'] for s in SE_ALL}


def se_group_note(pos):
    lo, hi = pos, pos
    while lo - 1 in _SE_NAME:
        lo -= 1
    while hi + 1 in _SE_NAME:
        hi += 1
    assert lo - 1 in DIFF_GND + SB_GND and hi + 1 in DIFF_GND + SB_GND, pos
    if lo == hi:
        return f'单独成组, 两侧为地 (位置 {lo - 1} / {hi + 1})'
    mates = [f'{p} {_SE_NAME[p]}' for p in (pos - 1, pos + 1) if lo <= p <= hi]
    return (f'单端组 {"/".join(str(p) for p in range(lo, hi + 1))}: 组内相邻不夹地 (与 {"、".join(mates)} 直接相邻); '
            f'组两侧为地 (位置 {lo - 1} / {hi + 1}); 每 2~3 根单端夹 1 根地')


assert se_group_note(62).startswith('单端组 62/63') and se_group_note(66).startswith('单端组 65/66') and se_group_note(68).startswith('单独成组') \
    and se_group_note(71).startswith('单端组 70/71/72'), (se_group_note(68), se_group_note(71))
assert _SE_NAME[68] == 'JTAG_TCK' and 67 in SB_GND and 69 in SB_GND        # TCK 单独成组, 两侧为地

# ---- 速率与占用 (bridge_defs.vh §1 载荷 9.003 Gbps/面; §2 SYNC beat 开销 126/128)
PAYLOAD_GBPS_8 = 9.003
SYNC_EFF = 126 / 128


def occ(nl, mbps, bits=8):
    return PAYLOAD_GBPS_8 * bits / 8 / (nl * mbps / 1000.0 * SYNC_EFF)


OCC = {r: round(occ(18, r) * 100, 1) for r in (800, 700, 600)}
OCC12 = round(occ(18, 800, 12) * 100, 1)
OCC_NOW = round(occ(12, 800) * 100, 1)
assert OCC == {800: 63.5, 700: 72.6, 600: 84.7} and OCC12 == 95.3 and OCC_NOW == 95.3, (OCC, OCC12, OCC_NOW)
N_DIV = [n for n in range(1, 73) if (2 * n) % 3 == 0 and 72 % (2 * n) == 0]          # 只凭"2N 被 3 整除且整除 72"
N_MIN = math.ceil(PAYLOAD_GBPS_8 * 1000 / (800 * SYNC_EFF))                          # 带宽下限 @800 Mbps
assert N_DIV == [3, 6, 9, 12, 18, 36] and N_MIN == 12 and [n for n in N_DIV if N_MIN <= n < 36] == [12, 18], (N_DIV, N_MIN)
# 边带下拉算式 (sheet5 E25 文字里的数字): DS1103 表 3-16 IPU Weak/Medium/Strong; DS1200 表 3-9 IPU 最大 @3.3V; VIL 0.8 V
assert abs(50e-6 * 2200 - 0.11) < 1e-9 and abs(150e-6 * 2200 - 0.33) < 1e-9 and abs(150e-6 * 4700 - 0.705) < 1e-9 \
    and abs(192e-6 * 2200 - 0.4224) < 1e-9 and abs(192e-6 * 4700 - 0.9024) < 1e-9 and 400e-6 * 2000 <= 0.8 + 1e-12 and abs(3.3 / 2200 - 1.5e-3) < 1e-9
# v3 2.5V 边带算式 (sheet5 sideband_level): DS1200 表 3-9 IPU @2.5V 上限 153 µA; Strong 400 µA; LVCMOS25 VIL 0.7 V; 驱动负载; VCCIO ±5 % 直连
assert abs(153e-6 * 2200 - 0.3366) < 1e-9 and abs(400e-6 * 2200 - 0.88) < 1e-9 and 400e-6 * 1500 <= 0.6 + 1e-12 and abs(2.5 / 2200 - 1.136e-3) < 1e-6 \
    and 2.625 < 2.375 + 0.3 and 2.5 - 0.4 > 1.7 and 3.3 > 2.5 + 0.3
# G 步 (与 FS03 改板 README v2.2 / V3_design_inputs.md 统一口径) 文字里的数字:
#   JTAG: TCK 下拉 (两面并联 1.1 kΩ), TMS / TDI 22 kΩ 上拉到 V2 本地 2.5 V (TDI 单只: 反灌 96 µA / 驱低 0.11 mA; 共用 TMS 两只并联 11 kΩ: 反灌 193 µA / 驱低 0.23 mA;
#         一面未上电分压 1.25 V); 上拉阻值 ≥6.07 kΩ
_RS, _RC = 8200 + 33, 22000 + 33
assert round(153e-6 * 1100, 2) == 0.17 and abs(2.5 / 1100 - 2.273e-3) < 1e-6 and round((2.625 - 0.5) / _RC * 1e6) == 96 and round(2.5 / 22000 * 1e3, 2) == 0.11 \
    and round((2.625 - 0.5) / (11000 + 33) * 1e6) == 193 and round(2.5 / 11000 * 1e3, 2) == 0.23 and 2.5 * 22 / (22 + 22) == 1.25 \
    and round((2.625 - 0.5) / 350e-6 / 1e3, 2) == 6.07 and 22000 / 2 >= 6070 and (2.625 - 0.5) / (11000 + 33) <= 350e-6
#   SB_ALIGNED 串 8.2 kΩ + 2.2 kΩ 下拉在连接器侧: 注入 258~282 µA; 高电平 1.728 V (余 28 mV); 桥片未配置 (150 + 30) µA × 2.2 kΩ = 0.396 V → 焊盘 0.643 V (余 57 mV); 配置期 0.87~1.60 V; 分压约 0.5 V
assert round((2.625 - 0.5) / _RS * 1e6) == 258 and round((2.625 - 0.3) / _RS * 1e6) == 282 and round(1.975 - 30e-6 * _RS, 3) == 1.728 and round((1.975 - 30e-6 * _RS - 1.7) * 1e3) == 28 \
    and round(180e-6 * 2200, 3) == 0.396 and round(180e-6 * 2200 + 30e-6 * _RS, 3) == 0.643 and round((0.7 - 180e-6 * 2200 - 30e-6 * _RS) * 1e3) == 57 \
    and round(83e-6 * (_RS + 2200), 2) == 0.87 and round(153e-6 * (_RS + 2200), 2) == 1.60 and round(1.975 * 2.2 / (2.2 + 8.2), 1) == 0.4 and round(2.5 * 2.2 / (2.2 + 8.2), 1) == 0.5
#   SB_UART_B2S 串 8.2 kΩ: NONE 低电平 0.647 V; PULLUP 1.66 V; PULLUP 允许串阻 ≤1.93 kΩ; 115200 bps τ 165 ns / 过门限 679 ns / 7.8 %; SB_RSTN 误串 0.44 V
_tau = _RS * 20e-12
assert round(0.4 + 30e-6 * _RS, 3) == 0.647 and round(0.4 + 153e-6 * _RS, 2) == 1.66 and round((0.3 / 153e-6 - 33) / 1e3, 2) == 1.93 and round(_tau * 1e9) == 165 \
    and round(_tau * math.log(1.728 / 0.028) * 1e9) == 679 and round(1e6 / 115200, 2) == 8.68 and round(679e-9 * 115200 * 100, 1) == 7.8 and round(2.1 * 2.2 / (2.2 + 8.23), 2) == 0.44
#   串阻区间 6.04~9.13 kΩ; DR1 VCCIO 闸门窗下限 2.40 ⇒ 对端 VOH ≤2.565 V (2.625 超 60 mV); 下电 τ = 1 kΩ × (10 + 1 + 7 × 0.1) µF = 11.7 ms; 注 3 焊盘处 33 Ω × 20 pF 10-90 % 摆率约 1.4 V/ns; CB-V2 飞线注入
assert round(((2.625 - 0.5) / 350e-6 - 33) / 1e3, 2) == 6.04 and round(((1.975 - 1.7) / 30e-6 - 33) / 1e3, 2) == 9.13 and round(2.40 + 0.165, 3) == 2.565 \
    and round((2.625 - 2.565) * 1e3) == 60 and round(1e3 * (10 + 1 + 7 * 0.1) * 1e-6 * 1e3, 1) == 11.7 and round(0.8 * 2.5 / (2.2 * 33 * 20e-12) / 1e9, 1) == 1.4 \
    and round((3.3 - 2.5 - 0.6) / 33 * 1e3, 1) == 6.1 and round(2.5 / 3.3, 2) == 0.76 and round(2.0 / 3.3, 2) == 0.61
del _RS, _RC, _tau


def fifo_peak(nl, mbps, dclk=150.0):
    """bridge_defs.vh §6 通式的峰值项: DR1 满速突发一帧 1728 字槽, tx 按 dclk 匀速吃 ⇒ 链路快于 tx 时的积压 (字槽, 估算)"""
    t_tx = 1920 * 8 / dclk                                  # µs, 屏吃完一帧
    t_link = 1728 * 72 * 8 / (nl * mbps * SYNC_EFF)         # µs, 链路送完一帧
    return max(0.0, 1728 * (1 - t_link / t_tx))


FIFO = {r: round(fifo_peak(18, r)) for r in (800, 700, 600)}
assert FIFO == {800: 543, 700: 374, 600: 148}, FIFO
# DR1 输入推荐上限 (sheet5 dr1_vi): DS1200 表 3-4 VI ≤ VCCIO+0.165; 2.5V ±5 % 反向最坏超; 允许公差 t ≤ 0.165 / 5 = 3.3 %
assert 2.5 < 2.5 + 0.165 and 2.5 * 1.05 > 2.5 * 0.95 + 0.165 and abs(0.165 / 5 - 0.033) < 1e-12 and 2.5 * 1.033 <= 2.5 * 0.967 + 0.165 + 1e-9

# =============================================================================
# 2. 验证板实现 —— SoC 侧 (DR1V90 on FS03): 方案 A (CEP1/bank33) 与 方案 B (CEP2/bank11)
# =============================================================================
CUR = {}                                                     # 现役 uplink_pin.adc: 契约键 -> (信号, 差分对)
for _sig, _ball, _std, _cmt in DATA['adc']:
    _k = 'CLK' if _sig == 'txclk' else ('CHK' if _sig == 'tx[12]' else 'D' + _sig[3:-1])
    CUR[_k] = (_sig, PM[_ball][2])
assert len(CUR) == 14
CUR_SIG_BY_PAIR = {v[1]: v[0] for v in CUR.values()}

B33_PAIRS = sorted({v[2] for v in PM.values() if v[0] == 33}, key=lambda p: int(p[1:-3]))
SPLIT33 = [p for p in B33_PAIRS if pair_pwr(PAIR_BALLS[p]['P'], PAIR_BALLS[p]['N'])[1]]
assert len(B33_PAIRS) == 24 and SPLIT33 == ['R9_33', 'R15_33', 'R16_33', 'R21_33'], SPLIT33


def is_gclk_pair(pair):
    return 'GCLK' in PM[PAIR_BALLS[pair]['P']][4]


A_MAP = {'D0': 'R1_33', 'D1': 'R2_33', 'D2': 'R3_33', 'D3': 'R5_33', 'D4': 'R6_33', 'D5': 'R7_33', 'D6': 'R8_33',
         'D7': 'R4_33', 'D8': 'R10_33', 'D9': 'R11_33', 'D10': 'R13_33', 'D11': 'R19_33', 'CHK': 'R23_33', 'CLK': 'R12_33',
         'D12': 'R14_33', 'D13': 'R17_33', 'D14': 'R18_33', 'D15': 'R20_33', 'D16': 'R22_33', 'D17': 'R24_33'}
assert sorted(A_MAP.values()) == sorted(p for p in B33_PAIRS if p not in SPLIT33) and is_gclk_pair(A_MAP['CLK'])
A_KEEP = sorted(k for k in CUR if CUR[k][1] == A_MAP[k])
A_MOVE = sorted(k for k in CUR if CUR[k][1] != A_MAP[k])
A_NEWBALL = [k for k in PAIR_ORDER if A_MAP[k] not in CUR_SIG_BY_PAIR]
assert A_MOVE == ['CLK', 'D10', 'D7', 'D9'] and len(A_KEEP) == 10 and len(A_NEWBALL) == 9, (A_MOVE, A_KEEP, A_NEWBALL)
A_NEW_PH1 = [A_MAP[k] for k in A_NEWBALL if k in PH1_KEYS]
A_UP = [p for p in A_MAP.values() if pwr_state(PAIR_BALLS[p]['P']) == pwr_state(PAIR_BALLS[p]['N']) == '上拉到 VCCIO']
A_FREE = sorted((p for p in A_MAP.values() if pwr_state(PAIR_BALLS[p]['P']) == pwr_state(PAIR_BALLS[p]['N']) == '随 HSWAPEN'),
                key=lambda p: int(p[1:-3]))
assert len(A_UP) == 15 and A_FREE == ['R3_33', 'R11_33', 'R12_33', 'R13_33', 'R14_33'], (len(A_UP), A_FREE)

CEP2_PAIRS = [PM[c['ball']][2] for c in CHAIN if c['conn'] == 'CEP2' and c['pin'] >= 3 and c['pin'] % 2 == 1]
L12 = PM[CEP_BY_PIN[('CEP2', 7)]['ball']][2]
B_CAND = [p for p in CEP2_PAIRS if p != L12]
B_SEQ = ['D0', 'D1', 'D2', 'D3', 'D4', 'D5', 'CLK', 'CHK', 'D6', 'D7', 'D8', 'D9', 'D10', 'D11'] + PH2_ONLY
B_MAP = dict(zip(B_SEQ, B_CAND))
B_SPARE = B_CAND[20:]
assert len(CEP2_PAIRS) == 24 and L12 == 'L12_11' and len(B_CAND) == 23 and B_MAP['CLK'] == 'L14_11' and is_gclk_pair('L14_11')
assert all(pwr_state(PAIR_BALLS[p][x]) == '随 HSWAPEN' for p in B_CAND for x in 'PN')

SB_A = {'SB_ALIGNED': ('CEP2', 3), 'SB_RSTN': ('CEP2', 4), 'SB_UART_B2S': ('CEP2', 5), 'SB_UART_S2B': ('CEP2', 6)}
SB_B = {'SB_RSTN': ('CEP1', 13), 'SB_UART_S2B': ('CEP1', 14), 'SB_ALIGNED': ('CEP1', 39), 'SB_UART_B2S': ('CEP1', 40)}
assert pwr_state(CEP_BY_PIN[SB_B['SB_RSTN']]['ball']) == '下拉到 GND'
assert pwr_state(CEP_BY_PIN[SB_B['SB_UART_S2B']]['ball']) == '上拉到 VCCIO'
assert {PM[CEP_BY_PIN[v]['ball']][2] for v in SB_B.values()} <= set(SPLIT33)
assert all(PM[CEP_BY_PIN[v]['ball']][0] == 11 for v in SB_A.values())

# =============================================================================
# 2b. SoC 侧双面实现 (D7) —— SOC_IMPL
#     内嵌数据 = 本会话并行流程 P2 的 FS03 双面分配 (面 A = CEP1/bank33, 面 B = CEP2/bank11, 单端方案 S = 两面共用 TCK/TMS, 光电开关 K18);
#     运行时 --soc-impl=文件.json (同结构) 可整体替换。渲染 sheet3 / sheet6 / sheet8 前必须过 check_soc_impl 与 soc_merge_asserts。
# =============================================================================
SOC_IMPL_SPEC = r'''
SOC_IMPL = {
  "source": str,                      # 产出流程 / 日期 / 依据文件
  "rework": str,                      # 两个 CEP bank 改 2.5V 的改板方案引用 (D7); 未定写 "待定 ..."
  "faces": {"A": FACE, "B": FACE},    # D2 两面契约相同; D7 验证期两面同时用 (A = CEP1/bank33, B = CEP2/bank11)
  "spin_sync": SE,                    # 光电开关 (转子索引) 输入; 不属契约, 验证板专有; 合并断言要求已分配 (D7)
  "reserved": [{"balls": [球位], "via": str, "use": str, "status": 状态}],   # 可选: CEP 上布线到位但未分配的脚
  "plan": [[项目, 正文, 状态], ...],  # 可选: sheet3 末尾"规划"行 (排布理由 / 预算 / 风险), 正文可含 «e:» / «d:» 引用
  "notes": [str, ...]
}
FACE = {
  "cep": "CEP1" | "CEP2", "bank": 33 | 11, "vccio": 2.5, "rework": str,
  "pairs": {契约键: {"P": 球位, "N": 球位, "status": 状态, "note": str}},
          # 契约键 = PAIR_ORDER 全部 20 个; P/N 须为 pinmap 同一差分対且极性正确; 不得用 bank33 上电劈开対 (SPLIT33);
          # CLK 须落 GCLK 対; L12_11 (CEP2.7/8) 未 toggle 确认前不得用
  "sideband": {"SB_ALIGNED" | "SB_RSTN" | "SB_UART_B2S" | "SB_UART_S2B": SE},
  "jtag":     {"JTAG_TCK" | "JTAG_TMS" | "JTAG_TDI" | "JTAG_TDO": SE}
}
SE = {
  "ball": 球位 | null, "via": str,    # via = 物理引出点 ("CEP1.13" / "KEY2 焊盘" ...)
  "vccio": 2.5 | 3.3 | 1.8,           # 契约面单端必须 2.5V (D5), 不是 2.5 时必须填 level_shift; CEP 球须与所在 bank 那一面的 vccio 一致
  "level_shift": null | str,
  "shared_with": null | "A" | "B",    # 验证板上两面共用同一 DR1 球 (V3 上分叉到两个连接器): 每个连接器仍各有该信号 (D2 不变),
                                      # 但两面不能并发; 两面同名信号须互指, note 必填
  "pull": null | str,                 # SoC 模组侧外部上下拉; SB_ALIGNED 必须写 2.2 kΩ 下拉 (D4)
  "iostd": str, "pulltype": str, "por": str,   # 可选: .adc IOSTANDARD / 驱动, PULLTYPE 建议, 上电固定态影响
  "bank": int, "pin": str,            # CEP 外的球 (如 spin_sync) 必填; CEP 球由内嵌 pinmap 查
  "status": 状态, "note": str
}
'''
SE_KEYS_SB = [s['name'] for s in SB]
SE_KEYS_JTAG = [j['name'] for j in JTAG]
SE_BY_NAME = {s['name']: s for s in SE_ALL}
SE_POS = {s['name']: s['pos'] for s in SE_ALL}
# CEP 外球位 (pinmap.csv 原值, verify() 核对): 光电开关落脚 K18 = KEY2, 备选 J18 = KEY3 (FS03 原理图 p16)
SOC_EXTRA = {'K18': [32, 'IO_R7N_32', 'R7_32', 'N', ''], 'J18': [32, 'IO_R7P_32', 'R7_32', 'P', '']}
# 直驱屏约束用到的 bank11 球 (constraints/panel_pins_dr1.adc 与 td_pov fpga_pin.adc 相同, verify() 核对); D7 改 2.5V 后这块 FS03 不再直驱 3.3V 屏
PANEL_BALLS = {'AA11', 'AA12', 'AA4', 'AA6', 'AA7', 'AA8', 'AA9', 'AB12', 'AB1', 'AB4', 'AB5', 'AB6', 'AB9', 'R6', 'T4', 'T6', 'U5', 'U6', 'V5', 'V7', 'V8',
               'W12', 'W5', 'W6', 'W7', 'W8', 'Y10', 'Y4', 'Y5', 'Y6', 'Y9'}
SOC_POV_SPIN = 'W6'          # 现役 spin_sync_i (td_pov fpga_pin.adc:35 / panel_pins_dr1.adc:35, LVCMOS33), verify() 核对
CUR_SIG_BY_BALL = {}
for _k, (_sig, _pr) in CUR.items():
    CUR_SIG_BY_BALL[PAIR_BALLS[_pr]['P']] = _sig + ' P'
    CUR_SIG_BY_BALL[PAIR_BALLS[_pr]['N']] = _sig + ' N'
assert len(PANEL_BALLS) == 31 and all(PM[b][0] == 11 for b in PANEL_BALLS) and SOC_POV_SPIN in PANEL_BALLS


def soc_pair_rel(f, k, pair):
    """契约键 k 落 pair 时与现役 uplink_pin.adc (bank33 14 対探针) 的关系"""
    if PM[PAIR_BALLS[pair]['P']][0] != 33:
        return '新 (现役 LVDS 探针全在 bank33; bank11 无 LVDS 先例)', 'new'
    if k in CUR:
        sig, old = CUR[k]
        if old == pair:
            return f'沿用: 现役 {sig} 同一対 {pair}, 改名 {sname(k)}; LVDS18 → LVDS25', 'keep'
        why = '上电劈开対' if old in SPLIT33 else '非 GCLK 対'
        tail = f' (该対现役为 {CUR_SIG_BY_PAIR[pair]})' if pair in CUR_SIG_BY_PAIR else ' (新球位)'
        return f'改动: 现役 {sig} 在 {old} ({why}) → 挪到 {pair}{tail}', 'move'
    if pair in CUR_SIG_BY_PAIR:
        return f'新增 (阶段二): {pair} 现役为 {CUR_SIG_BY_PAIR[pair]}', 'move'
    return f'新增 (阶段二): {pair} 现役未用', 'new'


def cep_col(ball):
    return (CEP_BY_BALL[ball]['pin'] + 1) // 2


def fmt_cols(cols):
    cols, out, i = sorted(set(cols)), [], 0
    while i < len(cols):
        j = i
        while j + 1 < len(cols) and cols[j + 1] == cols[j] + 1:
            j += 1
        out.append(f'c{cols[i]}' if i == j else f'c{cols[i]}~c{cols[j]}')
        i = j + 1
    return '、'.join(out)


SOC_REWORK = ('改板方案见 dr1v90/fs03_mod/README.md v2.2 (两个 bank 都改, 未实施): J1 / J2 各一路: 肖特基 + TPS73625DBVR + 0.2 Ω 采样 + 10 µF + 1 kΩ 泄放; '
              '插座小板 (方案 P) 或引线直焊 (方案 S); 每 bank 设计 200 mA, > 300 mA 停 (V3_design_inputs.md G2); V3 设计输入见 dr1v90/fs03_mod/V3_design_inputs.md; '
              '硬规则: FS03 先上电、最后断电, SW1 拨 JTAG 并拔 TF 卡, 物理拆除 CEP1 上 CB-V2 JTAG 飞线后 CEP 全空才上电, 不从 CEP pin1 取电; '
              '独立审查 v2 = 0 critical / 3 major / 7 minor, v2.1 已给落实做法 (M1 带电读数改预插测试线 / M2 V3 闸门测点 J_TP11 + SENSE33 + TP_TDO_A / M3 插座小板·地线双线 + V3 对端 → DR1 串阻); '
              'v2.1 复核 (R3, v2.2 已落实) 另提 J_TP 改电阻隔离、焊后断电阻值检查')
_POR_RSTN = ('bank11 不在表 2-6: 配置期随 HSWAPEN (FS03 = 0 ⇒ 弱上拉 ≤153 µA @2.5V) × 桥侧 V2 2.2 kΩ 下拉 ≤0.34 V < GW5A VIL 0.7 V ⇒ 默认复位 (期望行为); '
             '配置后读到该面 IDCODE 前 RTL 保持低 (D6); 与本面 SB_ALIGNED / SB_UART_B2S 同在 bank11 ⇒ bank11 岛掉电 (J1 模块未装 / 松脱 / 失地) 时 SB_RSTN 同时被拉低, 桥片门控随之生效; '
             'V3 上不得串阻、不得加上下拉 (误串 8.2 kΩ: 2.1 V × 2.2 / (2.2 + 8.23) = 0.44 V < VIH 1.7 V, 桥片永远复位)')
_POR_AL = ('输入; V3 紧贴 CEP 母座串 8.2 kΩ, 2.2 kΩ 下拉在串阻的连接器侧; PULLTYPE NONE。配置期 DR1 弱上拉 83~153 µA 经 8.23 kΩ + 2.2 kΩ 为 0.87~1.60 V (不定), 此时 SoC 不采信, 无害; '
           '配置后桥片未配置 (弱上拉 ≤150 µA) 时: 下拉节点 (150 + 30) µA × 2.2 kΩ = 0.396 V (30 µA = DR1 输入漏电, 同样流过下拉), 焊盘 0.396 + 30 µA × 8.233 kΩ = 0.643 V < VIL 0.7 V (余 57 mV) ⇒ 读"未对齐"; '
           '余量紧 ⇒ SB_RSTN 为低时 V2 侧不驱高; 桥片驱高时最坏 1.975 − 30 µA × 8.233 kΩ = 1.728 V ≥ VIH 1.7 V (余 28 mV, 按手册极限值; µA 级负载下实际 VOH ≈ VCCIO); '
           '岛掉电注入 (2.625 − 0.3~0.5) / 8.233 kΩ = 258~282 µA ≤ 表 3-8 350 µA; 释放 SB_RSTN 且读到 IDCODE 前不采信 (D4)')
_POR_B2S = ('输入; V3 紧贴 CEP 母座串 8.2 kΩ; PULLTYPE NONE, 禁止 PULLUP (PULLUP 时被驱动为低也只到 0.4 + 153 µA × 8.233 kΩ = 1.66 V > VIL 0.7 V, 恒读 1; 要开 PULLUP 串阻只能 ≤1.93 kΩ, 就放弃了 DC 350 µA 保护); '
            'NONE 时被驱动为低最坏 0.4 + 30 µA × 8.233 kΩ = 0.647 V < 0.7 V; 115200 bps: τ = 8.233 kΩ × 20 pF (估) = 165 ns, 过门限最坏 679 ns, 占位宽 8.68 µs 的 7.8 %; '
            '岛掉电注入 258 µA ≤350 µA; 桥模组未上电时 RX 空闲电平不定, 读到 IDCODE 之前 SoC 不采信 RX, 无害; 与本面 SB_RSTN 同在 bank11 (门控同 bank)')
_POR_S2B_TAIL = ('PULLTYPE NONE ⇒ 配置后到读到 IDCODE 前 RTL 三态期间不留 DR1 弱上拉 (空闲高由桥侧 RX 片内弱上拉给); 直连桥片 2.5V 脚 (无转换器), '
                 '桥模组未上电时只有配置期 (≤90 ms) 弱上拉 ≤153 µA 经其钳位二极管注入 (< 表 3-8 350 µA; 按 FS03 先上电的顺序不出现, «d:soc_inject»); '
                 'V3 上不得串阻、不得加上下拉: DR1 驱高进未上电 GW5A VCCIO23 球靠 GW5A 热插拔特性 DS1103 表 3-8 IHS ≤150 µA (印刷页 50) 满足每 IO 350 µA («e:powerup»)')
_POR_S2B_A = 'D22 表 2-6 强制下拉 ⇒ 配置期为低 (UART break), 此时桥片被 SB_RSTN 按在复位、RX 不采, 无害; ' + _POR_S2B_TAIL
_POR_S2B_B = 'C22 表 2-6 强制上拉 ⇒ 配置期空闲高; ' + _POR_S2B_TAIL
_POR_TCK = ('TCK 静止为低: A21 表 2-6 强制下拉 + 每面 V2 A 口 2.2 kΩ 下拉 (两面共用 ⇒ 两只并联 1.1 kΩ: 弱上拉 153 µA × 1.1 kΩ = 0.17 V; DR1 驱高负载 2.27 mA < 8 mA) ⇒ 配置期 TCK 为低, TAP 不动; '
            '配置后 PULLTYPE PULLDOWN, 与 V2 下拉同向; 进 V2 转换器 A 口, V2 未上电时靠转换器 Ioff (最大值待 V2 选型核, «d:jtag_shift_part»), V3 不串阻')
_POR_TMS = ('TMS 静止为高: E20 表 2-6 配置期强制上拉 + 每面 V2 A 口 22 kΩ 上拉到 V2 本地 2.5 V ⇒ 与配置期状态一致; 配置后 PULLTYPE PULLUP; SoC 首次访问 JTAG 前仍先发 ≥5 个 TMS = 1 的 TCK 复位 TAP, 不依赖上电态, '
            '每次访问结束也发 ≥5 个 TMS = 1 让 TAP 回到 Test-Logic-Reset; '
            '两面共用: 两只上拉并联 11 kΩ, DR1 驱低灌 2.5 V / 11 kΩ = 0.23 mA; 一面 LED 模组未上电时 TMS 被分压到约 1.25 V (不定区), 此时 TCK ≤0.17 V 无沿, TAP 不动, 无害; '
            'bank33 岛未上电时两只并联反灌 (2.625 − 0.5) / 11.03 kΩ = 193 µA ≤350 µA (≥6.07 kΩ ✓); '
            '进 V2 转换器 A 口, V2 未上电时靠 Ioff, V3 不串阻')
_POR_TDI = ('TDI 静止为高: A16 / E19 随 HSWAPEN (FS03 = 0 ⇒ 配置期弱上拉) + V2 A 口 22 kΩ 上拉到 V2 本地 2.5 V ⇒ 与配置期状态一致 (TCK 被下拉住, TAP 不动); '
            '配置后 PULLTYPE PULLUP; bank33 岛未上电时上拉反灌 (2.625 − 0.5) / 22.03 kΩ = 96 µA ≤350 µA, DR1 驱低灌 2.5 V / 22 kΩ = 0.11 mA; 进 V2 固定方向带 Ioff 转换器 A 口, V3 不串阻')
_POR_TDO = ('面 A A17 表 2-6 强制上拉 / 面 B A22 随 HSWAPEN (FS03 = 0 同为弱上拉); PULLUP ⇒ 桥模组未上电 (转换器 Ioff 高阻) 时读到全 1, 只作"不在位"提示; 在位以 IDCODE 精确等于 0x0001281B 为准; '
            'V3 不贴串阻 (0402 位默认 0 Ω); DC 保护靠: bank33 掉电 ⇒ TCK 停 ⇒ TAP 不在 Shift ⇒ TDO 高阻 ⇒ 被 V2 B 口 10 kΩ 下拉 (必须) ⇒ 转换器输出低, 不向 DR1 驱高; '
            '残余风险: JTAG 访问进行中 bank33 掉电, TDO 可能停在高; 暴露窗口只在访问中 (加载约数秒 + IDCODE 轮询), SoC 每次访问结束发 ≥5 个 TMS = 1 回 Test-Logic-Reset, 静止时无注入; '
            '验证期访问中 FS03 掉电属违规场景, 接受 («d:soc_inject»; 目标板 «d:tdo_oe»)')
_OUT8, _OUT4, _IN = 'LVCMOS25 输出 8 mA SLOW', 'LVCMOS25 输出 4 mA SLOW', 'LVCMOS25 输入'
_PD_AL = ('V3 贴 2.2 kΩ 下拉到地 (契约 SoC 侧外部下拉, D4), 放在串阻的连接器侧; V3 紧贴 CEP 母座串 8.2 kΩ (1 %, 0402) 限流 (改板审查 v2 M3(c), README v2.2 §5.12.2; '
          '下拉若放在串阻与 CEP 母座之间会分压, 8.2 kΩ 时高电平只有约 0.5 V)')
_SHARE_NOTE = ('两面共用: V3 上紧贴 CEP1 引出点分叉到两个连接器, 每支路留 0402 串阻位 (默认 0 Ω, 实测改 22~33 Ω), 分叉 SI 先低速验再升到契约 TCK; 每个连接器仍各 4 根 JTAG (契约 D2 不变); '
               '两面 V2 的上下拉按并联核算 (TCK 下拉 2.2 kΩ ∥ 2.2 kΩ = 1.1 kΩ, TMS 上拉 22 kΩ ∥ 22 kΩ = 11 kΩ); '
               '两个 TAP 同步走状态, 不访问的一面 TDI 保持 1 (BYPASS), 两面不能并发; 一面 JTAG 短路拖垮两面 («e:jtag_share»)')
# (面, 信号, 球, IOSTANDARD / 驱动, PULLTYPE, SoC 侧外部上下拉, 上电态影响, 共用对面)
SOC_SE_TABLE = [
    ('A', 'SB_ALIGNED', 'U10', _IN, 'NONE (禁用片内上拉)', _PD_AL, _POR_AL, None),
    ('A', 'SB_RSTN', 'W11', _OUT8, 'PULLDOWN 或 NONE (禁 PULLUP)', None, _POR_RSTN, None),
    ('A', 'SB_UART_B2S', 'U12', _IN, 'NONE (禁用片内上拉)', None, _POR_B2S, None),
    ('A', 'SB_UART_S2B', 'D22', _OUT4, 'NONE', None, _POR_S2B_A, None),
    ('A', 'JTAG_TCK', 'A21', _OUT8, 'PULLDOWN', None, _POR_TCK, 'B'),
    ('A', 'JTAG_TMS', 'E20', _OUT8, 'PULLUP', None, _POR_TMS, 'B'),
    ('A', 'JTAG_TDI', 'A16', _OUT8, 'PULLUP', None, _POR_TDI, None),
    ('A', 'JTAG_TDO', 'A17', _IN, 'PULLUP', None, _POR_TDO, None),
    ('B', 'SB_ALIGNED', 'U9', _IN, 'NONE (禁用片内上拉)', _PD_AL, _POR_AL, None),
    ('B', 'SB_RSTN', 'W10', _OUT8, 'PULLDOWN 或 NONE (禁 PULLUP)', None, _POR_RSTN, None),
    ('B', 'SB_UART_B2S', 'U11', _IN, 'NONE (禁用片内上拉)', None, _POR_B2S, None),
    ('B', 'SB_UART_S2B', 'C22', _OUT4, 'NONE', None, _POR_S2B_B, None),
    ('B', 'JTAG_TCK', 'A21', _OUT8, 'PULLDOWN', None, _POR_TCK, 'A'),
    ('B', 'JTAG_TMS', 'E20', _OUT8, 'PULLUP', None, _POR_TMS, 'A'),
    ('B', 'JTAG_TDI', 'E19', _OUT8, 'PULLUP', None, _POR_TDI, None),
    ('B', 'JTAG_TDO', 'A22', _IN, 'PULLUP', None, _POR_TDO, None),
]
# F 步重排 (取代 P2 初排: SB_RSTN D22 / A21, UART W11 / W10 / U12 / U11, TCK A22, TMS C22, TDO_B E20): 见 规划·单端 的三条约束
ADC_BALLS = {b for b in PM if alt_split(PM[b][4])[1]}
SOC_SPIN = dict(ball='K18', bank=32, pin='IO_R7N_32', via='CEP 外: FS03 KEY2 焊盘 (K2 非公共端 / R172 下端 / C245 上端同网, 原理图 p16)', vccio=3.3,
                level_shift=None, shared_with=None, pull='板上 R172 2.2 kΩ 上拉 VCC_3V3 + C245 0.1 µF 到地 (原理图 p16)',
                iostd='LVCMOS33 输入 (bank32 VCCO = VCC_3V3 固定, 不受 J1 / J2 改板影响)', pulltype='NONE (板上已有 2.2 kΩ)',
                por='输入, 上电态无害; 按下 KEY2 = 假索引 (可拆 K2)', status='建议 (电平已核; 传感器输出类型与 C245 去留待定)',
                note='开集电极输出: 直接接, 用 R172 上拉 3.3V (勿再上拉 5V); 推挽 3.3V: 串 100 Ω; 推挽 5V: 不许直连, 加 74LVC1G17 @3.3V; '
                     'C245 与 R172 成 RC = 220 µs, 拖慢上升沿 (到 VIH 2.0 V 约 205 µs) ⇒ 建议拆 C245 («d:spin_sensor»); 备选同构脚 J18 (KEY3, R176 / C246); '
                     '传感器 3.3V 供电: 旧屏排线 / 接口板下线后另取 —— 从 LDO 插座小板 (或方案 S 引线) J1 路 D1 (肖特基) 之前的独立焊盘引出, 串 0.1 A 自恢复保险丝 (紧贴取电点), 供电线与地线单独走线、各占端子, 不经 V3 '
                     '(改板方案 README v2.2 §5.8 步骤 5, V3_design_inputs.md E3, 审查 v2 m4); 不取 D1 之后的 VIN_L、CEP pin1、J5 USB_VDD33')
SOC_RESERVED = dict(balls=[PAIR_BALLS[L12]['P'], PAIR_BALLS[L12]['N']], via='CEP2.7 / CEP2.8',
                    use=f'预留 {L12} (未分配, 不作信号): V3 J_TP11 闸门测点 —— CEP2.7 / CEP2.8 ({PAIR_BALLS[L12]["P"]} / {PAIR_BALLS[L12]["N"]}) 各串 10 kΩ (紧贴 CEP 母座) 再引到排针 J_TP11, 不接 FPC; '
                        'bank11 加载前闸门: 弱上拉读 ≈VCCIO_11 (10 MΩ 表误差约 0.1 %), 判 2.40~2.60 V; 位流不用它, 运行中仍有效 (改板审查 v2 M2, v2.1 复核 major 3; dr1v90/fs03_mod/V3_design_inputs.md B 组, README v2.2 §5.12.1)。'
                        '若启用 Error-8221 顶替 (用它顶替面 B 一个报错的 LVDS 対, 须先 toggle): V3 改版、闸门改 SENSE11。JTAG 分配不得占用 CEP2.7 / CEP2.8, 否则 J_TP11 失效; '
                        '也不作面 B 独立 JTAG 的 TCK / TMS (bank11 非 ADC 球, 与面 B TDI / TDO 的 ADC 复用球混用, 违反 DS1200 §4.2 注 1, «d:adc_se»); 光电备选已被 K18 取代',
                    status='待定 (CEP2.7 手册 Y19 / 原理图 Y9, toggle 未验)')
assert abs(2.2e3 * 0.1e-6 - 220e-6) < 1e-12 and round(-220 * math.log(1 - 2.0 / 3.3)) == 205 and round(1e6 / (15 * 360)) == 185


def _soc_plan_builtin(impl):
    fa, fb = impl['faces']['A'], impl['faces']['B']
    ses = [(f, n, se) for f in 'AB' for g in ('sideband', 'jtag') for n, se in impl['faces'][f][g].items()]
    n_se = len({se['ball'] for _f, _n, se in ses})
    split_io, spare_io, l12_io = 2 * len(SPLIT33), 2 * len(B_SPARE), 2
    avail = split_io + spare_io
    need = [('S 两面共用 TCK / TMS、光电放 CEP 外 [本表]', n_se), ('S+ 共用 TCK / TMS、光电也上 CEP', n_se + 1), ('I JTAG 两面独立、光电 CEP 外', n_se + 2),
            ('I+ JTAG 两面独立、光电上 CEP', n_se + 3)]
    bud = '; '.join(f'{nm} = {n} → 余 {avail - n} (有 L12 余 {avail + l12_io - n})' for nm, n in need)
    clk_a, clk_b = PM[fa['pairs']['CLK']['P']][2], PM[fb['pairs']['CLK']['P']][2]
    ph1_a = fmt_cols(cep_col(fa['pairs'][k]['P']) for k in PH1_KEYS)
    ph1_b = fmt_cols(cep_col(fb['pairs'][k]['P']) for k in PH1_KEYS)
    moves = '; '.join(f'{CUR[k][0]} {CUR[k][1]} → {A_MAP[k]}' for k in A_MOVE)
    cep1_se_cols = fmt_cols(cep_col(se['ball']) for _f, _n, se in ses if CEP_BY_BALL[se['ball']]['conn'] == 'CEP1')
    spin_who = next((f'{f}.{sname(k)}_{pol}' for f in 'AB' for k in PAIR_ORDER for pol in 'PN' if impl['faces'][f]['pairs'][k][pol] == SOC_POV_SPIN), '—')
    SE33_ = sorted({PAIR_BALLS[p][x] for p in SPLIT33 for x in 'PN'})
    bench_pins = {'TCK': 4, 'TMS': 5, 'TDO': 15, 'TDI': 18}
    bench_txt = ' / '.join(f"{t} CEP1.{p} = {CEP_BY_PIN[('CEP1', p)]['ball']}" for t, p in bench_pins.items())
    tdo_ball = CEP_BY_PIN[('CEP1', bench_pins['TDO'])]['ball']
    tdo_hit = next((f'面 A {sname(k)}_{pol}' for k in PAIR_ORDER for pol in 'PN' if fa['pairs'][k][pol] == tdo_ball), '本表未用')
    return [
        ('规划·前提 (改板)',
         '本 sheet 全部分配以两个 CEP bank VCCIO 都改 2.5V 为前提 (D7 已定要改): DR1 2.5V bank 才能发 LVDS25, 同 bank 单端为 LVCMOS25, 与契约电平一致, V3 上 0 路电平转换。'
         f'{SOC_REWORK}。改后: ① J1 / J2 不再是 3.3V / 1.8V 跳帽档, 这块 FS03 不能再直驱 3.3V 屏; 以下工程与改后状态互斥、不得原样加载 (改板方案 README v2.2 §5.2 / §8): '
         'td_pov fpga_pin.adc 与 constraints/panel_pins_dr1.adc (bank11 LVCMOS33 × 31, 含 spin_sync_i W6)、td_panel / dclk_probe (bank11 LVCMOS33)、'
         'td_arb / td_lz4eng / td_lz4sys (seed_in = W6 LVCMOS33)、td_ramprobe (bank11 LVCMOS33 × 1)、uplink_tx 探针 (bank33 LVDS18)、'
         'jtag_load 台架 (jtag_cep1_pins.adc bank33 LVCMOS33 × 4 + jtag_gpio_pin.adc bank11 × 2); '
         '② 位流 IO 标准须与 VCCIO 一致 (UG1210 p13: 错配可能损坏器件); 加载前闸门每次在本次上电周期内、LED 模组未上电时读: V3 插上前量 CEP 脚预插测试线 (bank33 表 2-6 上拉球、bank11 弱上拉球 ≈2.5 V), 不量模块输出; '
         'V3 插上后读 J_TP11 (bank11) + SENSE33 (bank33 主判据) + TP_TDO_A (bank33 辅判据) (见 规划·V3); '
         f'③ 动手前 (改板方案 README v2.2 阶段 −1): SW1 拨 JTAG 并拔 TF 卡 (防 FSBL 自动加载 pov.bit); 物理拆除 CEP1 上的 CB-V2 JTAG 飞线 ({bench_txt} → CB-V2 P5), CEP1 / CEP2 全空后才上电 —— '
         f'线若留着, GW5A TDO 3.3V 经 33 Ω 进 CEP1.{bench_pins["TDO"]} = {tdo_ball} (本表 {tdo_hit}), 超 DS1200 表 3-1 绝对最大 VCCIO+0.3 = 2.8 V, 注入约 (3.3 − 2.5 − 0.6) / 33 Ω ≈ 6 mA ≫ 表 3-8 的 350 µA; '
         'jtag_load 台架位流 (bank33 LVCMOS33) 不得在 2.5V 状态下加载; ④ 上电 FS03 先、断电 FS03 最后 (见 规划·上电与门控) («d:fs03_25v»)。',
         '待定 (改板方案 v2.2 未实施、V3 未画; D7 要改本身已定)'),
        ('规划·面 A (CEP1 / bank33)',
         f'bank33 24 対去上电劈开 {len(SPLIT33)} 対 ({", ".join(SPLIT33)}) = 20 対, 全用 ⇒ LVDS 余量 0; 转发时钟 {clk_a} ({PM[PAIR_BALLS[clk_a]["P"]][4]}); 阶段一 14 対在 CEP1 {ph1_a}。'
         f'与现役 uplink_pin.adc (14 対 LVDS18 探针): 沿用 {len(A_KEEP)} 対、改动 {len(A_MOVE)} 对 ({moves})、新球位 {len(A_NEWBALL)} 对 (阶段一 {", ".join(A_NEW_PH1)}); '
         '14 条 IOSTANDARD 全改 LVDS25 —— 该 .adc 由 tools/gen_uplink_adc.py 生成 (改生成脚本; 文件头"J2 跳 1.8V"注释作废); 现役探针 uplink_tx_top.v 发 200 MHz, 契约 400 MHz, 新 .adc 配新顶层。'
         f'上电 ~90 ms: {len(A_UP)} 対 P/N 同上拉 (差分≈0)、{len(A_FREE)} 対随 HSWAPEN ({", ".join(A_FREE)}) ⇒ 桥片由 SB_RSTN 门控。',
         '建议 (未经 TD)'),
        ('规划·面 B (CEP2 / bank11)',
         f'bank11 24 対去 {L12} (CEP2.7/8: 手册 Y19 / 原理图 Y9, 未 toggle) = 23 対, 用 20, 余 {len(B_SPARE)} 対 ({", ".join(B_SPARE)}) 全部改作两面单端 ⇒ LVDS 余量 0, '
         f'能顶替 Error-8221 的只剩 {L12} (须先 toggle); 转发时钟 {clk_b} ({PM[PAIR_BALLS[clk_b]["P"]][4]}); 阶段一 14 対在 CEP2 {ph1_b} (c4 为预留 {L12})。'
         '20 対全是新球位; bank11 不在表 2-6, 上电随 HSWAPEN (K16 = 0 弱上拉)。旁证: td_panel 工程 bank11 AB10 / V12 PackReg = DDRX1 (LVCMOS33 单端 ODDR), 不等于 ODDRx2 + LVDS25 合法。'
         f'CEP2 现为直驱屏 50 针排线 (bank11 {len(PANEL_BALLS)} 球, 含 spin_sync_i {SOC_POV_SPIN}), D7 后下线。',
         '建议 (未经 TD)'),
        ('规划·单端 (方案 S)',
         f'单端 {n_se} 球 = bank33 劈开対 {split_io} + bank11 余量対 {spare_io}, 刚好用尽: 两面各 8 根 (边带 4 + JTAG 4), JTAG_TCK / JTAG_TMS 两面共用 1 球 ⇒ 16 − 2 = {n_se}。'
         f'排布三条约束 (F 步按审查重排, 取代 P2 初排): ① DS1200 §4.2 ADC 复用注 (LVCMOS 模式): 同一接口功能单元里 ADC 复用球与其他 PL 球不可混用 —— bank33 的 {split_io} 个单端球里 '
         f'{len([b for b in SE33_ if b in ADC_BALLS])} 个是 ADC 复用 ({" / ".join(b for b in SE33_ if b in ADC_BALLS)}), 只有 {" / ".join(b for b in SE33_ if b not in ADC_BALLS)} 不是, bank11 全不是 ⇒ '
         '两面 JTAG (共用后 6 球) 整组落这 6 个 ADC 复用球, 边带与 UART 全落非 ADC 球; '
         '② 门控与被门控同 bank: 每面桥 → SoC 的 SB_ALIGNED / SB_UART_B2S 与该面 SB_RSTN 同在 bank11 (CEP2 c23 / c24 / c25) ⇒ bank11 岛掉电 (J1 模块未装 / 松脱 / 失地) 时 SB_RSTN 同时被桥侧 2.2 kΩ 拉低, '
         '桥片门控随之生效; JTAG_TDO 与 TCK 同在 bank33: bank33 掉电 ⇒ TCK 停 ⇒ TAP 不在 Shift ⇒ TDO 高阻 ⇒ 被 V2 B 口 10 kΩ 下拉 (必须) ⇒ 转换器输出低 (残余风险: 移位中途掉电); '
         'V3 串 8.2 kΩ 的慢沿输入 (SB_ALIGNED / SB_UART_B2S) 必须落非 ADC 球, 现排布在 bank11 已满足; '
         '③ 运行期翻转的 SB_UART_B2S 放 CEP2 c25, 与最近的 LVDS 列 c22 (面 B UL_D[17], 阶段一不用) 隔 c23 SB_ALIGNED / c24 SB_RSTN 两列静态线; 可选的 SB_UART_S2B 只剩 bank33 的 D22 / C22 '
         '(CEP1 c7, 夹在面 A UL_D[10] c6 与 UL_CHK c8 之间, 运行期翻转 ⇒ 4 mA SLOW; 串扰不可接受时停用 S2B)。'
         f'CEP1 单端列 {cep1_se_cols}。JTAG 同列对面搭配: TCK A21 ↔ TDO_B A22 (TDO 在 TCK 下降沿变、由 V2 转换器低阻驱动; TCK 不与 TMS / TDI 同列相邻), TMS E20 ↔ TDI_B E19, TDI_A A16 ↔ TDO_A A17。'
         '上电态: TCK = A21 表 2-6 强制下拉 ⇒ 配置期 TAP 不动; 两面 SB_RSTN 在 bank11 弱上拉 × 桥侧 2.2 kΩ ≤0.34 V ⇒ 默认复位 (不再依赖表 2-6 强制下拉球); FS03 HSWAPEN = 0 ⇒ "随 HSWAPEN" 球配置期同为弱上拉。'
         '代价 (待安路确认 «d:adc_se»): ① TCK / TMS / TDI 是 ADC 复用球作 LVCMOS 输出 (注原文只写"可作复用 I/O 输入端口"); ② TDO 是 ADC 复用输入, 注 3 的摆率按对端驱动器设置理解 (V2 快速 CMOS 转换器满足), '
         '是否指焊盘处待确认; bank33 非 ADC 单端球只有 C22 / D22, 无可挪位置。'
         '上下拉: TCK 静止低 (A21 强制下拉 + V2 A 口 2.2 kΩ 下拉, PULLDOWN), TMS / TDI 静止高 (V2 A 口 22 kΩ 上拉到 V2 本地 2.5 V, PULLUP), TDO PULLUP + V2 B 口 10 kΩ 下拉 (必须)。'
         'V3 走线: 两面的 SB_ALIGNED / SB_RSTN / SB_UART_B2S 从 CEP2 引出, 两面 JTAG (含 TCK / TMS 分支) 与 SB_UART_S2B 从 CEP1 引出, 两排针区之间交叉, 下有完整地参考、不与 LVDS 邻层平行。',
         '建议 (电平已核; ADC 复用注未决; 未经 TD)'),
        ('规划·脚数预算',
         f'CEP 上可作单端 = 劈开対 {split_io} + bank11 余量 {spare_io} = {avail} (+ {L12} 待 toggle {l12_io} = {avail + l12_io})。{bud}。两面 LVDS 余量都是 0。'
         '并行流程 wf_3cee62db research:fs03 初版按两 bank 1.8V、每面 7 根单端算 ("双面差 1 / V3 上 14 路转换"); 其 fix 步已把 jtag_load/fs03_io/cep_budget.py 改为 v3 口径 '
         '(每面出 5 / 入 3 = 8 根、2.5V、SoC 侧 0 路转换), 重算双面 17 需求 / 14 可用 / 余 −3 (CEP2.7/8 验过后 −1), 与本表 I+ 一致; 本表采用 S = 14 → 余 0。'
         'I / I+ 另受 ADC 复用注约束: 面 B 独立 JTAG 须整组落 ADC 复用球或整组落非 ADC 球, 用 L12 作面 B TCK / TMS 会混用 ⇒ 须再重排; '
         f'且 {L12} (CEP2.7 / CEP2.8) 现作 V3 J_TP11 闸门测点, JTAG 分配不得占用, 否则 J_TP11 失效。',
         '建议'),
        ('规划·JTAG 两面共用 TCK / TMS',
         '在 V3 上分叉到两个连接器, 每个连接器仍各 4 根 JTAG ⇒ 契约 (D2 两面相同) 不变, 属验证板实现选择。风险 (待验): ① 分叉后走两根不同长度电缆 (SI; 先低速验再升到契约 TCK, 每支路留 0402 串阻位);'
         '② 一面 JTAG 短路拖垮两面; ③ 两个 TAP 同步走状态, 不访问的一面 TDI 保持 1 (BYPASS), 两面不能异步并发 —— SoC 侧 JTAG 主机 (openFPGALoader / 位敲服务端) 按"两套 TDI / TDO 轮流用"实现; '
         f'④ 运行期重载某面位流时 CEP1 {cep1_se_cols} 上 JTAG 翻转, 与面 A lane 相邻, 面 A 可能出 CRC 错并重训; ⑤ 两面 V2 上下拉并联: TCK 下拉 1.1 kΩ (DR1 8 mA 档驱高负载 2.27 mA), '
         'TMS 上拉 22 kΩ ∥ 22 kΩ = 11 kΩ (DR1 驱低灌 0.23 mA; bank33 岛掉电时反灌 193 µA ≤350 µA); 一面 LED 模组未上电时 TMS 被分压到约 1.25 V, 此时 TCK ≤0.17 V 无沿, TAP 不动。'
         f'不共用 (方案 I) 原想用 {L12} (Y9 / Y8) 作面 B TCK / TMS, 但它们是 bank11 非 ADC 球, 与面 B TDI / TDO (bank33 ADC 复用球) 混用, 违反 DS1200 §4.2 注 1 ⇒ 须整组重排, 暂不可用。'
         '不采用"JTAG 菊花链 + 共用 SB_RSTN" (破坏两面独立, 一面坏整条链断) («e:jtag_share»)。',
         '建议 (待验)'),
        ('规划·光电开关',
         f'现役 spin_sync_i = {SOC_POV_SPIN} (IO_L24P_11, CEP2.23, LVCMOS33, 无 PULLTYPE; td_pov fpga_pin.adc:35 / constraints/panel_pins_dr1.adc:35), 经 CEP2 → 50 针排线 → 接口板 → 传感器; '
         f'RTL angle_tracker 用上升沿 (并行流程 P2 读 RTL, 本表未复核)。双面后必须挪: {SOC_POV_SPIN} = {spin_who}, 且 bank11 改 2.5V 后 3.3V 传感器电平超 DR1 输入上限。'
         '新位置 K18 (KEY2, bank32 VCCO = VCC_3V3 固定; 原理图 p16 渲染图核: R172 2.2 kΩ 上拉 VCC_3V3、C245 0.1 µF 到地、按键 K2 到公共端); pov.bit 不占 K18 / J18。'
         '接法按传感器输出类型 (未知 «d:spin_sensor»): 开集电极直接接, 用 R172 上拉 (勿再上拉 5V); 推挽 3.3V 串 100 Ω; 推挽 5V 不许直连, 加 74LVC1G17 @3.3V。'
         'C245: RC = 220 µs 拖慢上升沿 (到 VIH 2.0 V 约 205 µs), 900 RPM (15 rps) × 360 片一片约 185 µs ⇒ 建议拆; 按 KEY2 = 假索引 ⇒ 可拆 K2; 飞线焊在转子上要机械固定。'
         '传感器 3.3V 供电: 旧屏排线 / 接口板下线后没有着落 ⇒ 从 LDO 插座小板 (或方案 S 引线) J1 路 D1 (肖特基) 之前的独立焊盘引出, 串 0.1 A 自恢复保险丝 (紧贴取电点), 供电线与地线单独走线、各占端子; '
         '信号、地、电源都不经 V3 (改板方案 README v2.2 §5.8 步骤 5, V3_design_inputs.md E3, 审查 v2 m4); 不取 D1 之后的 VIN_L (约 2.9 V)、CEP pin1、J5 USB_VDD33。'
         '备选: J18 (KEY3, R176 / C246 同构); CEP2.7 (Y9) 已作 V3 J_TP11 闸门测点, 不再作光电备选; MIPI CAM_* (bank31 1.8V, 要 FPC 转接) 不推荐; LED 脚 / HDMI / PS MIO 否决 (并行流程 research:fs03 / P2) («e:spin_sync»)。',
         '建议 (传感器类型与 C245 待定)'),
        ('规划·V3 转接板 (SoC 侧)',
         'V3 是无源板: 不放稳压器、电平转换器与接电源的上拉 (单端全在 2.5V bank); TCK / TMS 分叉 + 每支路 0402 串阻位; 不接 CEP pin1 (电压 3.3V / 5V 未实测 «d:cep_pin1»); '
         '两个排针都做 G-P-N-G 地排 (sheet5 «e:fs03_gnd»), 开窗边缘放 J_GND 供插座小板第二根地线; J12 相对 J11 转 180° (pin1 在右), 布局镜像。'
         'V3 设计输入以 dr1v90/fs03_mod/V3_design_inputs.md 与 README v2.2 §5.12 为准, 本表口径: '
         f'① 加载前闸门测点 (M2; V3 插上后 CEP1.4 / CEP2.4 被占): bank11 = J_TP11: CEP2.7 / CEP2.8 ({PAIR_BALLS[L12]["P"]} / {PAIR_BALLS[L12]["N"]}) 各串 10 kΩ 紧贴 CEP 母座再引到排针, 不接 FPC, 判 2.40~2.60 V; '
         'bank33 主判据 = SENSE33 (LDO 插座小板或 J2.2 根部经 10 kΩ 隔离直接引到板外端子排, 不经 V3; 判 2.40~2.60 V); '
         f'bank33 辅判据 = TP_TDO_A (CEP1.{CEP_BY_BALL[fa["jtag"]["JTAG_TDO"]["ball"]]["pin"]} = {fa["jtag"]["JTAG_TDO"]["ball"]}, 面 A JTAG_TDO, 加载前表 2-6 强制上拉): 47 kΩ 隔离电阻贴在 TDO 线分叉点、桩线 ≤1 mm (不用 0 Ω), '
         '只在 LED 模组未上电时读 (V2 转换器 Ioff 高阻, 读数 ≈VCCIO; LED 模组上电后 TDO 被 V2 下拉, 读数无效); '
         f'不设 TP_TDO_B: CEP1.{CEP_BY_BALL[fa["jtag"]["JTAG_TMS"]["ball"]]["pin"]} = {fa["jtag"]["JTAG_TMS"]["ball"]} 是两面共用 JTAG_TMS; JTAG 分配不得占用 CEP2.7 / CEP2.8, 否则 J_TP11 失效; '
         '测试线断电时预插、上电后手不碰板 (M1); '
         '② 机械 (m5): V3 在 J1 / J2 插接件上方开窗, 窗口尺寸按 V3_design_inputs.md F1 (每边比插接件大 ≥1.0 mm); 不开窗时 V3 底面在该区净空 ≥ 插接件总高 + 2 mm (F2); '
         '备选: 拆成 CEP1 / CEP2 两块小板经线缆互连 (边带与 JTAG 要跨板); 插上后实物量间隙 ≥0.5 mm (F3); '
         '③ 对端 → DR1 单端线 (M3(c)): 两面 SB_ALIGNED / SB_UART_B2S 紧贴 CEP 母座串 8.2 kΩ (1 %, 0402), SB_ALIGNED 的 2.2 kΩ 下拉放在串阻的连接器侧, DR1 两者 PULLTYPE = NONE '
         '(注入 258~282 µA ≤350 µA; ALIGNED 高电平最坏 1.728 V, 桥片未配置 0.643 V; B2S 低电平最坏 0.647 V, 115200 bps 过门限占位宽 7.8 %; 算式见 sheet5 «e:sideband_level»); '
         'JTAG_TDO 不贴串阻 (0402 位默认 0 Ω), DR1 PULLUP, V2 B 口 10 kΩ 下拉必须, DC 保护靠 TAP 自门控 (见 规划·单端), 残余风险 = 移位中途掉电; '
         '④ DR1 → 对端 (SB_RSTN / SB_UART_S2B / TCK / TMS / TDI) 不串阻、不加上下拉 (依据见 sheet5 «e:powerup»)。',
         '建议 (审查 v2 M2 / m5 / M3(c) 与 v2.1 复核的 V3 设计输入; 外形方案待 V3 画图)'),
        ('规划·上电与门控',
         '【硬规则】验证期上下电顺序 (改板方案 README v2.2 §5.7, 本表按强制执行): FS03 上电 → 闸门 (J_TP11、SENSE33、TP_TDO_A) → 加载 LVDS25 位流 (位流内 LVDS / SB_RSTN / SB_UART_S2B 保持不使能) '
         '→ LED 模组 (V2 + 核心板 + V1) 上电 → SoC 轮询 IDCODE (不设失败超时, 只上报) → 读到后使能该面; 断电: LED 模组先断, FS03 最后断电 (V3 是无源板, 不单独上电); CEP 上任何连接全断电插拔。'
         '在位判据: IDCODE 精确等于 0x0001281B; TDO PULLUP 读到全 1 只作"不在位"提示。'
         '理由: 反方向 (LED 模组先上电、FS03 未上电或 bank 岛掉电) 时, 桥 → SoC 单端被驱高即经 33 Ω 灌进 DR1 bank 钳位二极管, mA 级 (受驱动能力限定) ≫ DS1200 表 3-8 每 I/O 直流 350 µA, '
         '并经钳位管 → ADJ 岛 → LDO 抬 VCC_3V3 (改板模块的肖特基反向阻断 + 1 kΩ 泄放是第二道防线, 不替代顺序)。'
         '对 LED 模组的强制要求: SoC 未上电 / SB_RSTN 为低时 SB_ALIGNED / SB_UART_B2S 输出低或高阻 —— 桥片 RTL 与核心板 flash 里的任何镜像都要满足 (sheet4 规划·核心板 flash); JTAG_TDO 由 V2 B 口下拉 + 无 TCK 不进 Shift 保证为低。'
         f'DR1 侧: 上电 → 加载完成最坏 ~90 ms: 面 A {len(A_UP)} 対 P/N 同上拉、{len(A_FREE)} 対随 HSWAPEN; 面 B 20 対随 HSWAPEN; 单端上电态见各行。'
         '桥片由 SB_RSTN 门控 (每面 SB_RSTN 与本面 SB_ALIGNED / SB_UART_B2S 同在 bank11 + 桥侧 V2 2.2 kΩ)。配置后 RTL 在读到该面 IDCODE 前不使能该面 LVDS / SB_RSTN / SB_UART_S2B (D6)。'
         'D6 管不到配置期: DR1 弱上拉 (≤153 µA @2.5V / 球, < 350 µA) 经 LVDS 与直连的 SB_UART_S2B 灌入未上电 LED 模组, GW5A 未上电 IO 注入容限未查 («d:soc_inject»); 按上面的顺序 LED 模组晚于 FS03 加载完成上电, 这段注入不出现。',
         '建议 (上下电顺序出自改板方案 v2.2 硬规则, 用户未确认, 验证期按强制执行; GW5A 注入容限未查; 门控规则见 D6)'),
    ]


def _soc_impl_builtin():
    def se_rec(f, name, ball, iostd, pulltype, pull, por, shared):
        c = CEP_BY_BALL[ball]
        note = []
        if shared:
            note.append(_SHARE_NOTE)
        if name == 'SB_RSTN':
            note.append('2.2 kΩ 下拉只贴在桥侧 V2 (契约 D4); SoC 侧 (V3) 不得串阻、不得加上下拉')
        if name == 'SB_UART_S2B':
            note.append('V3 上不得串阻、不得加上下拉 (直连 GW5A VCCIO23 球, 靠 GW5A IHS ≤150 µA)')
        if name in ('SB_ALIGNED', 'SB_UART_B2S'):
            note.append('V3 串 8.2 kΩ 的慢沿输入必须落非 ADC 球 (本线在 bank11, 满足 DS1200 §4.2 注 3 的前提)')
        if PM[ball][2] in SPLIT33:
            note.append(f'借上电劈开対 {PM[ball][2]} 的单端')
        elif PM[ball][2] in B_SPARE:
            note.append(f'借 bank11 余量対 {PM[ball][2]} 的单端')
        st = '建议 (电平与上电态已核; 未经 TD / 未上板)'
        if ball in ADC_BALLS:
            adc = alt_split(PM[ball][4])[1]
            if iostd == _IN:
                note.append(f'{adc} 复用球作 LVCMOS25 输入: DS1200 §4.2 注 3 原文"对端器件的驱动要求使用 FAST 配置或 slew rate > 3.3V/ns", 按对端驱动器设置理解 —— '
                            'V2 JTAG 转换器是快速 CMOS 输出, 满足; 若按焊盘处摆率理解, 仅 FS03 板上 33 Ω × 约 20 pF 就只有约 1.4 V/ns, 任何方案都不满足, 故不可能是此意 (待安路确认, «d:adc_se»); '
                            'V3 在此线不贴串阻 (0402 位默认 0 Ω); bank33 非 ADC 单端球只有 C22 / D22, 无可挪位置')
            else:
                note.append(f'{adc} 复用球作 LVCMOS25 输出: DS1200 §4.2 注原文只写"可作复用 I/O 输入端口使用", 输出是否允许待安路 / TD 确认 («d:adc_se»)')
            note.append('本面 JTAG 4 根整组落 ADC 复用球, 不与非 ADC 球混用 (注 1); TCK ≤10 MHz (A 版 ≥15 MHz) 均 < 30 MHz (注 2)')
            st = '建议 (电平与上电态已核; ADC 复用注未决 «d:adc_se»; 未经 TD / 未上板)'
        return dict(ball=ball, via=f"{c['conn']}.{c['pin']}", vccio=2.5, level_shift=None, shared_with=shared, pull=pull,
                    iostd=iostd, pulltype=pulltype, por=por, status=st, note='; '.join(note))

    def face(f, cep, bank, mp, rework):
        pairs = {}
        for k in PAIR_ORDER:
            rel, kind = soc_pair_rel(f, k, mp[k])
            if kind == 'keep':
                st = '建议 (沿用现役球位; 整份 .adc 需重跑 TD)'
            elif kind == 'move':
                st = '建议 (球位现役在用、角色改; 需重跑 TD)' if mp[k] in CUR_SIG_BY_PAIR else '建议 (改动; 新球位需 TD 试综合)'
            else:
                st = '建议 (新球位, 未经 TD)'
            pairs[k] = dict(P=PAIR_BALLS[mp[k]]['P'], N=PAIR_BALLS[mp[k]]['N'], status=st, note=rel)
        rows = [r for r in SOC_SE_TABLE if r[0] == f]
        return dict(cep=cep, bank=bank, vccio=2.5, rework=rework, pairs=pairs,
                    sideband={r[1]: se_rec(*r) for r in rows if r[1].startswith('SB_')},
                    jtag={r[1]: se_rec(*r) for r in rows if r[1].startswith('JTAG_')})

    impl = dict(source='本会话并行流程 P2 (FS03 双面分配, 2026-09-15; 依据 pinmap.csv / FS03 原理图 p5·p16·p17 / DS1200 表 2-6 / cep_pin_table.tsv / uplink_pin.adc / td_pov fpga_pin.adc)',
                rework=SOC_REWORK,
                faces=dict(A=face('A', 'CEP1', 33, A_MAP, 'J2 → ADJ_BANK33 改 2.5V (改板方案待定)'), B=face('B', 'CEP2', 11, B_MAP, 'J1 → ADJ_BANK11 改 2.5V (改板方案待定)')),
                spin_sync=dict(SOC_SPIN), reserved=[dict(SOC_RESERVED)], plan=[], notes=[])
    impl['plan'] = [list(x) for x in _soc_plan_builtin(impl)]
    return impl


def check_soc_impl(impl):
    """按 SOC_IMPL_SPEC 校验; 返回问题列表 (空 = 通过)。bank / 差分对检查只对内嵌 pinmap 的 97 个 CEP 球。"""
    bad, owners = [], {}

    def st_ok(who, s):
        if not str(s or '').startswith(('已定', '建议', '待定')):
            bad.append(f'{who}: status 须以 已定/建议/待定 开头')

    def use(ball, who, kind, face=None, name=None, shared=None):
        if ball is not None:
            owners.setdefault(ball, []).append(dict(who=who, kind=kind, face=face, name=name, shared=shared))

    if impl is None:
        return bad
    faces = impl.get('faces') or {}
    if not set(faces) <= {'A', 'B'} or not faces:
        bad.append(f'faces 须为 A / B: {sorted(faces)}')
    bank_vccio = {}
    for f, face in sorted(faces.items()):
        if face.get('vccio') != 2.5:
            bad.append(f'面 {f}: vccio 须为 2.5 (D7)')
        if face.get('bank') in bank_vccio:
            bad.append(f'面 {f}: bank{face.get("bank")} 与另一面重复')
        bank_vccio[face.get('bank')] = face.get('vccio')
    for f, face in sorted(faces.items()):
        pairs = face.get('pairs') or {}
        if set(pairs) != set(PAIR_ORDER):
            bad.append(f'面 {f}: pairs 键须为契约 20 対')
        for k, pr in sorted(pairs.items()):
            p, n = pr.get('P'), pr.get('N')
            st_ok(f'面 {f} {k}', pr.get('status'))
            if p not in PM or n not in PM or PM[p][3] != 'P' or PM[n][3] != 'N' or PM[p][2] != PM[n][2]:
                bad.append(f'面 {f} {k}: {p}/{n} 不是同一差分対 P/N')
                continue
            pair = PM[p][2]
            if PM[p][0] != face.get('bank'):
                bad.append(f'面 {f} {k}: {p} 在 bank{PM[p][0]} ≠ face.bank')
            if pair in SPLIT33:
                bad.append(f'面 {f} {k}: {pair} 为上电劈开対 (DS1200 表 2-6)')
            if pair == L12:
                bad.append(f'面 {f} {k}: {pair} = CEP2.7/8, 未 toggle 确认')
            if k == 'CLK' and not is_gclk_pair(pair):
                bad.append(f'面 {f} CLK: {pair} 不是 GCLK 対')
            use(p, f'{f}.{k}_P', 'pair')
            use(n, f'{f}.{k}_N', 'pair')
        for grp, keys in (('sideband', SE_KEYS_SB), ('jtag', SE_KEYS_JTAG)):
            d = face.get(grp) or {}
            if set(d) != set(keys):
                bad.append(f'面 {f}: {grp} 键须为 {keys}')
            for name, se in sorted(d.items()):
                st_ok(f'面 {f} {name}', se.get('status'))
                if se.get('vccio') != 2.5 and not se.get('level_shift'):
                    bad.append(f'面 {f} {name}: 契约单端须 2.5V (D5), vccio = {se.get("vccio")} 且无 level_shift')
                b = se.get('ball')
                if b is None and not se.get('via'):
                    bad.append(f'面 {f} {name}: ball 与 via 都空')
                if b in PM:
                    if PM[b][0] not in bank_vccio:
                        bad.append(f'面 {f} {name}: {b} 在 bank{PM[b][0]}, 不在两面的 CEP bank')
                    elif se.get('vccio') != bank_vccio[PM[b][0]]:
                        bad.append(f'面 {f} {name}: vccio {se.get("vccio")} ≠ {b} 所在 bank{PM[b][0]} 的 {bank_vccio[PM[b][0]]}')
                if se.get('shared_with') and not se.get('note'):
                    bad.append(f'面 {f} {name}: shared_with 须在 note 写明')
                use(b, f'{f}.{name}', 'se', f, name, se.get('shared_with'))
        sa = (face.get('sideband') or {}).get('SB_ALIGNED')
        if sa is not None and not ('下拉' in str(sa.get('pull') or '') and '2.2' in str(sa.get('pull') or '')):
            bad.append(f'面 {f} SB_ALIGNED: 缺 SoC 侧外部下拉 2.2 kΩ (D4)')
        jb = [se.get('ball') for se in (face.get('jtag') or {}).values() if se.get('ball') in PM]
        if len({b in ADC_BALLS for b in jb}) > 1:
            bad.append(f'面 {f} JTAG: ADC 复用球与非 ADC 球混用 {sorted(jb)} (DS1200 §4.2 注 1)')
        sbd, jtd = face.get('sideband') or {}, face.get('jtag') or {}
        gbank = {n: PM[sbd[n]['ball']][0] for n in ('SB_RSTN', 'SB_ALIGNED', 'SB_UART_B2S') if (sbd.get(n) or {}).get('ball') in PM}
        if len(set(gbank.values())) > 1:
            bad.append(f'面 {f}: SB_RSTN 与本面 SB_ALIGNED / SB_UART_B2S 不同 bank {gbank} (门控须同 bank)')
        tb = [PM[(jtd.get(n) or {}).get('ball')][0] for n in ('JTAG_TCK', 'JTAG_TDO') if (jtd.get(n) or {}).get('ball') in PM]
        if len(set(tb)) > 1:
            bad.append(f'面 {f}: JTAG_TDO 与 JTAG_TCK 不同 bank (TDO 靠同 bank TCK 自门控)')
    ss = impl.get('spin_sync')
    if ss is not None:
        st_ok('spin_sync', ss.get('status'))
        if ss.get('ball') and ss['ball'] not in PM and not (ss.get('bank') and ss.get('pin')):
            bad.append('spin_sync: CEP 外的球须填 bank / pin')
        use(ss.get('ball'), 'spin_sync', 'spin')
    for i, r in enumerate(impl.get('reserved') or []):
        st_ok(f'reserved[{i}]', r.get('status'))
        for b in r.get('balls') or []:
            use(b, f'reserved[{i}]', 'rsv')
    for ball, lst in owners.items():
        if len(lst) == 1:
            if lst[0]['shared']:
                bad.append(f"{lst[0]['who']}: shared_with = {lst[0]['shared']}, 但对面没有同球同名信号")
            continue
        a, z = lst[0], lst[-1]
        ok = (len(lst) == 2 and a['kind'] == z['kind'] == 'se' and a['name'] == z['name'] and a['face'] != z['face']
              and a['shared'] == z['face'] and z['shared'] == a['face'])
        if not ok:
            bad.append(f"{lst[1]['who']}: 球 {ball} 已被 {lst[0]['who']} 使用" + (f' (另有 {len(lst) - 2} 处)' if len(lst) > 2 else ''))
    return bad


def soc_merge_asserts(impl):
    """合并断言 (渲染前必须通过; 失败抛 AssertionError): 两面各 20 対且时钟落 GCLK、LVDS 不占劈开対、CEP IO 无重复分配、光电开关已分配。返回汇总"""
    assert impl is not None, 'SOC_IMPL 为空: D7 双面数据未合并'
    faces = impl.get('faces') or {}
    assert set(faces) == {'A', 'B'}, f'须两面 A / B 同时实现 (D7): {sorted(faces)}'
    cep_owner = {}

    def own(ball, who):
        assert ball in CEP_BY_BALL, f'{who}: {ball} 不在 FS03 CEP 排针上'
        c = CEP_BY_BALL[ball]
        key = (c['conn'], c['pin'])
        assert cep_owner.get(key, who) == who, f'CEP IO 重复分配: {c["conn"]}.{c["pin"]} ({ball}) = {cep_owner.get(key)} 与 {who}'
        cep_owner[key] = who

    lvds, clk, se_balls, shared = 0, {}, set(), set()
    for f in ('A', 'B'):
        face = faces[f]
        prs = {k: PM[v['P']][2] for k, v in face['pairs'].items()}
        assert len(prs) == 20 and set(prs) == set(PAIR_ORDER) and len(set(prs.values())) == 20, f'面 {f}: 须 20 対且互不相同'
        assert is_gclk_pair(prs['CLK']), f'面 {f}: 转发时钟 {prs["CLK"]} 不在 GCLK 対'
        assert not set(prs.values()) & set(SPLIT33), f'面 {f}: LVDS 占了上电劈开対 {sorted(set(prs.values()) & set(SPLIT33))}'
        assert L12 not in prs.values(), f'面 {f}: LVDS 占了未 toggle 的 {L12}'
        for k, v in face['pairs'].items():
            for pol in 'PN':
                own(v[pol], f'{f}.{sname(k)}_{pol}')
                lvds += 1
        clk[f] = prs['CLK']
        for grp, keys in (('sideband', SE_KEYS_SB), ('jtag', SE_KEYS_JTAG)):
            for name in keys:
                se = face[grp][name]
                assert se.get('ball'), f'面 {f} {name}: 未分配球位'
                assert se.get('vccio') == 2.5 and not se.get('level_shift'), f'面 {f} {name}: 须落改 2.5V 的 CEP bank 直连 (D5 / D7)'
                own(se['ball'], f'AB.{name}' if se.get('shared_with') else f'{f}.{name}')
                se_balls.add(se['ball'])
                if se.get('shared_with'):
                    shared.add(name)
    rsv = [b for r in impl.get('reserved') or [] for b in r['balls']]
    for b in rsv:
        own(b, 'RSV')
    ss = impl.get('spin_sync')
    assert ss and ss.get('ball'), '光电开关 (spin_sync) 未分配 (D7)'
    if ss['ball'] in CEP_BY_BALL:
        own(ss['ball'], 'SPIN_SYNC')
    else:
        assert ss.get('bank') and ss.get('pin'), '光电开关落 CEP 外时须给 bank / pin'
    cep_io = sum(1 for c in CHAIN if c['ball'])
    return dict(lvds=lvds, se_balls=len(se_balls), shared=sorted(shared), rsv=len(rsv), cep_used=len(cep_owner), cep_io=cep_io, clk=clk,
                spin=ss['ball'], se_avail=cep_io - lvds - len(rsv))


def _soc_impl_demo():
    """结构自测用样例 (不输出): 面 A = bank33 20 対, 面 B = bank11 20 対, 单端全部待定占位"""
    def se(via):
        return dict(ball=None, via=via, vccio=2.5, level_shift=None, shared_with=None, pull=None, status='待定 (demo)', note='')

    def face(cep, bank, mp):
        sb = {k: se('待定') for k in SE_KEYS_SB}
        sb['SB_ALIGNED']['pull'] = '下拉 2.2 kΩ @V3'
        return dict(cep=cep, bank=bank, vccio=2.5, rework='待定',
                    pairs={k: dict(P=PAIR_BALLS[mp[k]]['P'], N=PAIR_BALLS[mp[k]]['N'], status='建议 (demo)', note='') for k in PAIR_ORDER},
                    sideband=sb, jtag={k: se('待定') for k in SE_KEYS_JTAG})
    return dict(source='demo', faces=dict(A=face('CEP1', 33, A_MAP), B=face('CEP2', 11, B_MAP)), spin_sync=None, notes=[])


_demo = _soc_impl_demo()
assert check_soc_impl(_demo) == [], check_soc_impl(_demo)
_demo['faces']['B']['pairs']['D0']['P'], _demo['faces']['B']['pairs']['D0']['N'] = _demo['faces']['B']['pairs']['D0']['N'], _demo['faces']['B']['pairs']['D0']['P']
_demo['faces']['A']['pairs']['D1'] = dict(_demo['faces']['A']['pairs']['D0'])
_demo['faces']['A']['jtag']['JTAG_TCK']['vccio'] = 3.3
_errs = check_soc_impl(_demo)
assert len(_errs) == 4 and any('不是同一差分対' in e for e in _errs) and any('已被' in e for e in _errs) and any('JTAG_TCK' in e for e in _errs), _errs
del _demo, _errs

# ---- 内嵌数据: 校验 + 合并断言 + 与 P2 分配的逐项一致性
SOC_IMPL_BUILTIN = _soc_impl_builtin()
assert check_soc_impl(SOC_IMPL_BUILTIN) == [], check_soc_impl(SOC_IMPL_BUILTIN)
SOC_SUM = soc_merge_asserts(SOC_IMPL_BUILTIN)
assert (SOC_SUM['lvds'], SOC_SUM['se_balls'], SOC_SUM['shared'], SOC_SUM['rsv'], SOC_SUM['cep_used'], SOC_SUM['cep_io'], SOC_SUM['se_avail']) == \
    (80, 14, ['JTAG_TCK', 'JTAG_TMS'], 2, 96, 96, 14), SOC_SUM                                   # CEP 96 个 IO 全部分配 (含预留 2)
assert SOC_SUM['clk'] == {'A': 'R12_33', 'B': 'L14_11'}
_se = [(f, n, se) for f in 'AB' for g in ('sideband', 'jtag') for n, se in SOC_IMPL_BUILTIN['faces'][f][g].items()]
assert {se['ball'] for _f, _n, se in _se} == {PAIR_BALLS[p][x] for p in SPLIT33 + B_SPARE for x in 'PN'}   # 单端 = 劈开対 8 + bank11 余量 6
SE33 = sorted({PAIR_BALLS[p][x] for p in SPLIT33 for x in 'PN'})
assert {b for b in SE33 if b in ADC_BALLS} == {'A16', 'A17', 'A21', 'A22', 'E19', 'E20'} and not {PAIR_BALLS[p][x] for p in B_SPARE for x in 'PN'} & ADC_BALLS
assert {se['ball'] for _f, n, se in _se if n.startswith('JTAG')} == {b for b in SE33 if b in ADC_BALLS}   # 两面 JTAG 6 球 = bank33 全部 ADC 复用单端球 (注 1 不混用)
assert not any(se['ball'] in ADC_BALLS for _f, n, se in _se if n.startswith('SB_'))                      # 边带 / UART 不落 ADC 复用球
assert {se['ball'] for _f, n, se in _se if n == 'JTAG_TCK'} <= PD                                         # TCK 落强制下拉球 ⇒ 配置期 TAP 不动
assert all(PM[f_[n]['ball']][0] == 11 for f_ in (SOC_IMPL_BUILTIN['faces'][x]['sideband'] for x in 'AB') for n in ('SB_RSTN', 'SB_ALIGNED', 'SB_UART_B2S'))  # 门控同 bank
assert all(CEP_BY_BALL[se['ball']]['conn'] == 'CEP1' for _f, n, se in _se if n.startswith('JTAG') or n == 'SB_UART_S2B')
assert all(CEP_BY_BALL[se['ball']]['conn'] == 'CEP2' and CEP_BY_BALL[se['ball']]['pin'] >= 45 for _f, n, se in _se if n in ('SB_ALIGNED', 'SB_RSTN', 'SB_UART_B2S'))
assert [{cep_col(se['ball']) for _f, n, se in _se if n == x} for x in ('SB_ALIGNED', 'SB_RSTN', 'SB_UART_B2S', 'SB_UART_S2B')] == [{23}, {24}, {25}, {7}]
assert [PM[PAIR_BALLS[p]['P']][2] for p in (A_MAP['D10'], A_MAP['CHK'])] == ['R13_33', 'R23_33'] and [cep_col(PAIR_BALLS[A_MAP[k]]['P']) for k in ('D10', 'CHK')] == [6, 8]
_j = {(f, n): se['ball'] for f, n, se in _se}
assert (_j[('A', 'JTAG_TCK')], _j[('B', 'JTAG_TDO')], _j[('A', 'JTAG_TMS')], _j[('B', 'JTAG_TDI')], _j[('A', 'JTAG_TDI')], _j[('A', 'JTAG_TDO')]) == ('A21', 'A22', 'E20', 'E19', 'A16', 'A17')
assert all(dr1_mate(a) == b for a, b in (('A21', 'A22'), ('E20', 'E19'), ('A16', 'A17'))) and 'A17' in PU and CEP_BY_BALL['A17']['pin'] == 20
# CB-V2 JTAG 台架飞线 (wf_3cee62db research:fs03 选脚表): CEP1.4 / 5 / 15 / 18 → P5; 改 2.5V 前必须物理拆除
BENCH_CEP1 = {'TCK': 4, 'TMS': 5, 'TDO': 15, 'TDI': 18}
assert [CEP_BY_PIN[('CEP1', p)]['ball'] for p in BENCH_CEP1.values()] == ['H20', 'G15', 'F21', 'F17']
BENCH_HIT = {t: next(f'{sname(k)}_{pol}' for k in PAIR_ORDER for pol in 'PN' if SOC_IMPL_BUILTIN['faces']['A']['pairs'][k][pol] == CEP_BY_PIN[('CEP1', p)]['ball'])
             for t, p in BENCH_CEP1.items()}
assert BENCH_HIT['TDO'] == 'UL_CHK_P', BENCH_HIT
assert cep_col(PAIR_BALLS[B_MAP['D17']]['P']) == 22 and SOC_IMPL_BUILTIN['reserved'][0]['balls'] == ['Y9', 'Y8']
assert SOC_SPIN['ball'] not in CEP_BY_BALL and SOC_SPIN['ball'] in SOC_EXTRA and SOC_EXTRA[SOC_SPIN['ball']][:2] == [SOC_SPIN['bank'], SOC_SPIN['pin']]
# 校验器 / 合并断言的反例自测
_bad = copy.deepcopy(SOC_IMPL_BUILTIN)
_bad['faces']['B']['jtag']['JTAG_TDI']['ball'] = _bad['faces']['A']['pairs']['D0']['P']          # 单端撞 LVDS 球, 且冒充共用
_bad['faces']['B']['jtag']['JTAG_TDI']['shared_with'] = 'A'
_bad['faces']['A']['jtag']['JTAG_TMS']['shared_with'] = None                                     # 共用不互指
_bad['faces']['A']['sideband']['SB_ALIGNED']['pull'] = None
_errs = check_soc_impl(_bad)
assert any('F16' in e and '已被' in e for e in _errs) and any('JTAG_TMS' in e for e in _errs) and any('SB_ALIGNED' in e for e in _errs), _errs
_bad = copy.deepcopy(SOC_IMPL_BUILTIN)                                                           # F 步新规则反例: JTAG 混用 ADC 球 / 门控不同 bank
_fa = _bad['faces']['A']
_fa['jtag']['JTAG_TDI']['ball'], _fa['sideband']['SB_UART_S2B']['ball'] = _fa['sideband']['SB_UART_S2B']['ball'], _fa['jtag']['JTAG_TDI']['ball']
_fa['sideband']['SB_RSTN']['ball'], _fa['sideband']['SB_UART_S2B']['ball'] = _fa['sideband']['SB_UART_S2B']['ball'], _fa['sideband']['SB_RSTN']['ball']
_errs = check_soc_impl(_bad)
assert any('混用' in e for e in _errs) and any('同 bank' in e for e in _errs), _errs
del _fa
_bad = copy.deepcopy(SOC_IMPL_BUILTIN)
_bad['spin_sync'] = None
try:
    soc_merge_asserts(_bad)
    raise RuntimeError('合并断言未拦住: 光电开关未分配')
except AssertionError as _e:
    assert '光电开关' in str(_e)
del _se, _bad, _errs
SOC_IMPL = SOC_IMPL_BUILTIN

# =============================================================================
# 3. 验证板实现 —— LED 侧 (GW5A on ACG525-CORE-V2): 上行放 VCCIO45 (3.3V 固定, bank4/5 = Bottom)
# =============================================================================
def grp_pairs(g):
    return sorted(k for k, v in FULL.items() if VG[v[0]['bank']] == g)


def grp_half(g):
    return sorted(k + '_' + v[0]['pol'] for k, v in HALF.items() if VG[v[0]['bank']] == g)


V01, V23, V45, V67 = (grp_pairs(g) for g in ('VCCIO01', 'VCCIO23', 'VCCIO45', 'VCCIO67'))
assert (len(V01), len(V23), len(V45), len(V67)) == (4, 26, 22, 21)
assert (grp_half('VCCIO23'), grp_half('VCCIO45'), grp_half('VCCIO67')) == (
    ['B2_R24_P', 'B3_B87_P'], ['B4_B29_N', 'B4_B52_N', 'B5_B18_N', 'B5_B2_P'], ['B6_L7_N', 'B7_T5_N'])

GW_MAP = {'CLK': 'B4_B33', 'D0': 'B4_B35', 'D1': 'B4_B39', 'D2': 'B4_B45', 'D3': 'B4_B50', 'D4': 'B4_B56', 'D5': 'B4_B60',
          'D6': 'B4_B31', 'D7': 'B4_B43', 'D8': 'B4_B48', 'D9': 'B4_B41',
          'D10': 'B5_B26', 'D11': 'B5_B22', 'CHK': 'B5_B6',
          'D12': 'B5_B20', 'D13': 'B5_B16', 'D14': 'B5_B24', 'D15': 'B5_B14', 'D16': 'B5_B4', 'D17': 'B5_B10'}
GW_SPARE = ['B5_B8', 'B5_B12']
assert sorted(list(GW_MAP.values()) + GW_SPARE) == V45
V45_HALF_FREE = grp_half('VCCIO45')              # v2 放边带的 4 个半対单脚; v3 空置 (3.3V 组, 不能放 2.5V 边带)
# ---- 边带 (D5: GW5A 2.5V 组)。建议分配:
#   桥 → SoC 的两根输出 (SB_ALIGNED / SB_UART_B2S) 放 VCCIO67 的 2 个半対单脚 —— VCCIO67 由核心板固定 2.5V, 不随 V2 的 VCCIO23 选择变,
#       即使 V2 把 VCCIO23 跳到 3.3V 跑官方自测, 也不会有 3.3V 输出进 DR1 2.5V bank (DS1200 表 3-1 输入上限 VCCIO+0.3 = 2.8V);
#   SoC → 桥 的两根输入 (SB_RSTN / SB_UART_S2B) 放 VCCIO23 的 B3_B71 (原"隔离対", 紧邻上行 P1.30): 准静态的 SB_RSTN 放紧邻上行的 P1.32,
#       UART 放 P1.34 (两侧 P1.32 / P1.36 GND) —— 隔离位不浪费, 也不占下行対 / 下行半対以外的资源
GW_SB = {'SB_ALIGNED': 'B7_T5_N', 'SB_UART_B2S': 'B6_L7_N', 'SB_RSTN': 'B3_B71_N', 'SB_UART_S2B': 'B3_B71_P'}
SB_25_GROUPS = ('VCCIO23', 'VCCIO67')
assert set(GW_SB) == {s['name'] for s in SB}
assert all(VG[CORE_BY_NET[n]['bank']] in SB_25_GROUPS for n in GW_SB.values()), '边带必须全部落 2.5V 组 (D5)'
assert all(VG[CORE_BY_NET[GW_SB[s['name']]]['bank']] == 'VCCIO67' for s in SB if s['dir'] == '桥 → SoC'), '桥→SoC 输出须在固定 2.5V 的 VCCIO67'
assert not set(GW_SB.values()) & {f'{b}_{p}' for b in GW_MAP.values() for p in 'PN'} and not set(GW_SB.values()) & set(V45_HALF_FREE)
assert all(not ug_cfg(CORE_BY_NET[n]) for n in GW_SB.values()), '边带脚不得带配置复用'
assert 'GCLKT' in CORE_BY_NET['B4_B33_P']['cfg'] and 'BPLL_T_IN' in CORE_BY_NET['B4_B33_P']['cfg']
assert all(part_of(FULL[b][0]['fpga']) == 'Bottom' for b in GW_MAP.values())
GW_PH1_BANK = {}
for _k in PH1_KEYS:
    GW_PH1_BANK[FULL[GW_MAP[_k]][0]['bank']] = GW_PH1_BANK.get(FULL[GW_MAP[_k]][0]['bank'], 0) + 1
assert GW_PH1_BANK == {4: 11, 5: 3}, GW_PH1_BANK
# 核心板自己占用的 bank4/5 球 (原理图 p4: flash / MODE / READY / DONE / RECONFIG_N / 50M) 均不在连接器上
CORE_OWN_BALLS = ['V3', 'R13', 'T13', 'R15', 'T14', 'V14', 'T15', 'N12', 'U3', 'V17', 'V2', 'T9']
assert not ({c['ball'] for c in CORE if c['ball']} & set(CORE_OWN_BALLS))
# 连接器对内脚序: P1 每対 N 小脚号 / P 大脚号, P2 相反 (73 个完整対全核)
for _k, _v in FULL.items():
    _pp = next(x for x in _v if x['pol'] == 'P')
    _nn = next(x for x in _v if x['pol'] == 'N')
    assert _pp['conn'] == _nn['conn'] and abs(_pp['pin'] - _nn['pin']) == 2 and ((_nn['pin'] < _pp['pin']) == (_pp['conn'] == 'P1')), _k
PN_NOTE = {'P1': 'P1 对内 N 小脚号 / P 大脚号', 'P2': 'P2 对内 P 小脚号 / N 大脚号'}
UL_P1 = [k for k in PAIR_ORDER if CORE_BY_NET[GW_MAP[k] + '_P']['conn'] == 'P1']
assert UL_P1 == ['D0', 'D1', 'D2', 'D3', 'D4', 'D5', 'CLK'], UL_P1
MIPI_PINS = sorted((c['conn'], c['pin']) for c in CORE if c['net'].startswith('MIPI'))
JTAG_PINS = sorted((c['conn'], c['pin']) for c in CORE if c['alias'].startswith('FPGA_T'))
assert MIPI_PINS == [('P2', 50)] + [('P2', p) for p in range(52, 61)] and JTAG_PINS == [('P1', p) for p in (94, 96, 98, 100)], (MIPI_PINS, JTAG_PINS)
# JTAG 四脚: 契约信号 → 核心板 P1 脚号 → 网名 FPGA_Txx (无 FPGA IO 网, 走 bank10 专用脚), 且四脚两两不同、恰为 JTAG_PINS
assert sorted(('P1', j['core_pin']) for j in JTAG) == JTAG_PINS
assert all(CORE_BY_PIN[('P1', j['core_pin'])]['alias'] == 'FPGA_' + j['tap'] and not CORE_BY_PIN[('P1', j['core_pin'])]['net'] for j in JTAG), 'JTAG 四脚与核心板 P1 不符'
assert {j['tap']: (j['core_pin'], j['ball']) for j in JTAG} == {'TDO': (94, 'D16'), 'TDI': (96, 'D15'), 'TMS': (98, 'B18'), 'TCK': (100, 'A17')}
N_IO = sum(1 for c in CORE if c['net'] and c['fpga'].startswith('IO'))
V45_JSON_ONLY = [(k, t) for k, t in ((k, [t for x in FULL[k] for t in cfg_diff(x)[0]]) for k in V45) if t]
assert N_IO == 154 and V45_JSON_ONLY == [('B5_B4', ['SDA', 'SCL'])], (N_IO, V45_JSON_ONLY)

UL_NET = {f'{b}_{p}': k for k, b in GW_MAP.items() for p in 'PN'}
SB_NET = {v: k for k, v in GW_SB.items()}


def cfg_pairs(keys):
    out = []
    for k in keys:
        toks = set()
        for x in FULL[k]:
            _, o = gw_cfg_split(ug_cfg(x))
            toks |= {t for t in o.split('/') if t}
        if toks:
            out.append((k, sorted(toks)))
    return out


def clk_pairs(keys):
    out = []
    for k in keys:
        toks = []
        for x in FULL[k]:
            cl, _ = gw_cfg_split(ug_cfg(x))
            toks += [t for t in cl.split('/') if re.match(r'^(GCLKT|[TBLR]PLL\d?_T_IN)', t)]
        if toks:
            out.append((k, toks))
    return out


V45_CFG = cfg_pairs(V45)
UL_CFG = [k for k, _ in V45_CFG if k in GW_MAP.values()]
assert len(V45_CFG) == 8 and len(UL_CFG) == 6 and all(k in UL_CFG or k in GW_SPARE for k, _ in V45_CFG)


def gw_neigh(conn, pin):
    """同排 ±2 与对排 (n ↔ n±1) 上的非上行、非地脚"""
    own = CORE_BY_PIN[(conn, pin)]
    out = []
    face = pin + 1 if pin % 2 == 1 else pin - 1
    for q, rel in ((pin - 2, '同排'), (pin + 2, '同排'), (face, '对排')):
        c = CORE_BY_PIN.get((conn, q))
        if not c:
            continue
        if not c['net']:
            if c['alias'] != 'GND':
                out.append(f'{conn}.{q} {rel} {c["alias"]}')
            continue
        if c['net'] in UL_NET or base_of(c['net']) == base_of(own['net']):
            continue
        net = c['net']
        if net in SB_NET:
            tag = f'边带 {SB_NET[net]}'
        elif net.startswith('MIPI'):
            tag = 'MIPI 硬核, 不用'
        elif base_of(net) in GW_SPARE:
            tag = 'VCCIO45 空置対'
        elif base_of(net) in DOWN_GUARD:
            tag = '隔离対, 不作下行'
        else:
            tag = {'VCCIO23': '下行候选 2.5V', 'VCCIO67': '下行候选 2.5V', 'VCCIO01': 'VCCIO01 1.5V, 不用', 'VCCIO45': 'VCCIO45'}[VG[c['bank']]]
        out.append(f'{conn}.{q} {rel} {net} ({tag})')
    return out


DOWN_GUARD = set()
for _b in GW_MAP.values():
    for _p in 'PN':
        _c = CORE_BY_NET[f'{_b}_{_p}']
        for _q in (_c['pin'] - 2, _c['pin'] + 2, _c['pin'] + 1 if _c['pin'] % 2 else _c['pin'] - 1):
            _x = CORE_BY_PIN.get((_c['conn'], _q))
            if _x and _x['net'] and not _x['net'].startswith('MIPI') and _x['bank'] in (2, 3, 6, 7):
                DOWN_GUARD.add(base_of(_x['net']))
DOWN_GUARD = sorted(DOWN_GUARD)
assert DOWN_GUARD == ['B3_B65', 'B3_B71'], DOWN_GUARD
SB_PAIRS = sorted({base_of(n) for n in GW_SB.values() if base_of(n) in FULL})      # 边带占用的完整対 (两脚都用)
SB_HALF = sorted(n for n in GW_SB.values() if base_of(n) in HALF)                   # 边带占用的半対单脚
GUARD_ONLY = [k for k in DOWN_GUARD if k not in SB_PAIRS]                            # 仍作隔离、不接的対
assert SB_PAIRS == ['B3_B71'] and all(f'{b}_{p}' in GW_SB.values() for b in SB_PAIRS for p in 'PN') and set(SB_PAIRS) <= set(DOWN_GUARD)
assert SB_HALF == ['B6_L7_N', 'B7_T5_N'] and GUARD_ONLY == ['B3_B65'], (SB_HALF, GUARD_ONLY)

DOWN_PAIRS = [k for k in V23 + V67 if k not in DOWN_GUARD]
DOWN_HALF = [h for h in grp_half('VCCIO23') + grp_half('VCCIO67') if h not in GW_SB.values()]
assert not set(SB_PAIRS) & set(DOWN_PAIRS) and DOWN_HALF == ['B2_R24_P', 'B3_B87_P'], DOWN_HALF     # 边带不占下行対
DOWN_TB = [k for k in DOWN_PAIRS if FULL[k][0]['bank'] in (3, 7)]       # 剔除 B2 / B6 后仍可做差分的
DOWN_B26 = [k for k in DOWN_PAIRS if FULL[k][0]['bank'] in (2, 6)]


def need(diff, singles, pairs, halves):
    split = math.ceil(max(0, singles - halves) / 2)
    used = diff + split
    return used, pairs - used, split


NA = need(37, 9, len(DOWN_PAIRS), len(DOWN_HALF))
NB = need(48, 9, len(DOWN_PAIRS), len(DOWN_HALF))
NC = (37, len(DOWN_TB) - 37)
ND = (48, len(DOWN_TB) - 48)
NA_V2 = need(37, 9, len(DOWN_PAIRS), 4)            # v2 (边带在 VCCIO45, 4 个 2.5V 半対都给下行) 的核算 A, 供对比
assert NA_V2 == (40, 5, 3)
assert (len(DOWN_PAIRS), len(DOWN_HALF), NA, NB, len(DOWN_TB), NC, ND) == (45, 2, (41, 4, 4), (52, -7, 4), 24, (37, -13), (48, -24)), \
    (len(DOWN_PAIRS), NA, NB, len(DOWN_TB))

# =============================================================================
# 4. 交叉引用 (E/D 编号在这里定, 正文里用 «e:键» / «d:键», 写出前统一替换)
# =============================================================================
E_KEYS = ['lvds25', 'fs03_lvds18', 'adapt', 'swing33', 'odt', 'gw_in_std', 'gw_out_std', 'vccio_groups', 'vccio45', 'vccio23',
          'rate_tx', 'rate_rx', 'occupancy', 'b2b6', 'timing_tool', 'hclk', 'iodelay', 'core_len', 'fpc_z', 'pinorder', 'fs03_gnd',
          'b2b', 'pwr_dr1', 'pwr_gw', 'sideband_level', 'jtag', 'jtag_shift', 'powerup', 'cep27', 'jumper', 'oddr', 'gw_cfgpins', 'mech', 'nopower', 'handshake',
          'soc_se', 'jtag_share', 'spin_sync', 'dr1_vi']
D_KEYS = ['freeze', 'rtl_nlane', 'rtl_framemiss', 'rtl_fifo', 'rtl_readback', 'proto_12bit', 'ph1_unused', 'soc_dual', 'fs03_25v', 'res33',
          'b2b6', 'bridge_ver', 'jtag_shift_part', 'gw_hclk', 'gw_cfgpins', 'odt_part', 'down_clk', 'v2_vccio23', 'cep27', 'vccio0167', 'fpc', 'target_doc',
          'spin_sensor', 'soc_inject', 'cep_pin1', 'dr1_vi', 'adc_se', 'core_flash', 'tdo_oe']
ECODE = {k: f'E{i:02d}' for i, k in enumerate(E_KEYS, 1)}
DCODE = {k: f'D{i:02d}' for i, k in enumerate(D_KEYS, 1)}
_REF = re.compile(r'«([ed]):([a-z0-9_]+)»')


def resolve_refs(s):
    return _REF.sub(lambda m: (ECODE if m.group(1) == 'e' else DCODE)[m.group(2)], s)


STATUS_STYLE = {'已定': 'ok', '建议': 'sug', '待定': 'tbd'}


def st_style(s):
    for k, v in STATUS_STYLE.items():
        if str(s).startswith(k):
            return v
    return 'c'


def fmt_list(lst):
    return f"{len(lst)}: " + ', '.join(lst) if lst else '0'


ELEC_DIFF = ('LVDS25: 发端 VOD 200/350/400 mV、VOCM 0.9/1.25/1.4 V (最小/典型/最大, 取 DR1 PL LVDS25 规格作契约参考); '
             '收端共模窗须覆盖 0.9~1.4 V、|VID| 门限 ≤100 mV; 直流耦合 (数据非直流平衡, 不做 AC 耦合)')
ELEC_SE = ('LVCMOS25 (2.5 V 单端, 已定 D5): 收端 VIL 0.7 V / VIH 1.7 V / VIH 上限 VCCIO+0.3 = 2.8 V, 发端 VOH ≥ VCCIO−0.4 = 2.1 V '
           '(DS1200 表 3-11 与 DS1103 表 3-23 GW5A-25 同值)')
ELEC_JTAG = (ELEC_SE + '; 契约面 2.5V, 桥模组内部转换到桥片 JTAG 电平 (GW5A: bank10 = VCCX = 3.3V, LVCMOS33 VIH 2.0 V) —— 转换器属模组内部实现, 不进契约')
RATE_NOM = '800 Mbps 标称 (UI 1250 ps)'
RATE_DOWN = (f'降速档 (是否允许待定 «d:proto_12bit»): 阶段二 8-bit 18 lane 可降 700 / 600 Mbps (占用 {OCC[700]} / {OCC[600]} %); '
             f'12-bit 只能 800 Mbps ({OCC12} %)')
RATE_DATA = RATE_NOM + '; ' + RATE_DOWN
TERM_DIFF = '100 Ω ±10 % 差分受控阻抗; 接收端 (桥) 做 100 Ω 差分端接 (片内或板上择一); 发端不加串阻'


# ---------------------------------------------------------------- sheet1 说明
def sheet_readme():
    H = ['分类', '项目', '内容', '出处 / 备注']
    W = [10, 18, 90, 50]
    R = []

    def add(a, b, c, d='', sty=None):
        R.append(([a, b, c, d], sty or ['b', 'b', 't', 't']))

    add('文档', '名称', '资料包 03 · DR1V90 主控 ↔ GW5A 桥接模块 对接关系表 (模组间接口契约 + 验证板实现映射)',
        '文件: DR1V90主控_GW5A桥接模块_对接关系表_2026-09-15.xlsx')
    add('文档', '版本 / 日期', f'{VERSION} · {DATE} · 按用户 09-15 下午决定 D1~D7 修订 v2: 7 位配置预留 → JTAG 4 根; 接口单端统一 2.5V; 边带下拉与上电规则定案; LED 侧边带移到 2.5V 组; 合并 SoC 侧双面实现 (D7: 面 A / 面 B + 边带 + JTAG + 光电开关)。'
        'v2 (09-15 上午) 取代 v1 (14 対口径)',
        '生成脚本: zynq_pov/docs/DR1V90_GW5A对接关系表_mkxlsx.py (纯标准库, 重跑即重生成, 内含源数据核对与回读自检)')
    add('口径', '契约 = 目标板', '模组间接口 (永久契约) 按目标板冻结, 与芯片无关: 每面 20 対 = 18 条数据 lane UL_D[17:0] + 1 条校验 lane UL_CHK + 1 対转发时钟 UL_CLK, '
        '另加单端边带 4 根 (训练握手 SB_ALIGNED / 桥片复位 SB_RSTN / 状态回读 UART 两根, D4) 与程序加载 JTAG 4 根 (TCK / TMS / TDI / TDO, D3, 取代 v2 的 7 位 SSPI / 从串配置预留); '
        '单端统一 2.5V LVCMOS (D5); 两面 (A/B) 接口完全相同、各一套连接器 (D2); 电源不走接口、晶振在 LED 模组本地、两模组分开上电, SoC 读到桥片 JTAG IDCODE 之前不驱动 LVDS 与边带 (D6)。',
        '用户 09-15 决定 D1~D6; 本表 sheet2')
    add('口径', '验证板 = 契约的一种实现', '验证板 (SoC 侧 米联客 FS03 + V3 转接板; LED 侧 小梅哥 ACG525-CORE-V2 + V2 底板) 只是契约的一个实现。'
        'sheet3 / sheet4 给两端的实现映射; 验证板阶段一只接通契约子集 (14 対), 但 V2 / V3 按 20 対全画。验证板上的球位不传导到目标板。'
        'D7: 验证期 FS03 同时驱 2 块屏 + 光电开关, 两个 CEP bank 改板把 VCCIO 改 2.5V (改板方案见 dr1v90/fs03_mod/README.md v2.2, V3 设计输入见 V3_design_inputs.md; 未实施)。', '用户 09-15 D7')
    for dk, dtxt in [
        ('D1 契约 20 対', '目标板每面 24 颗; 模组间接口按目标板冻结: 每面 20 対 LVDS25 = UL_D[17:0] + UL_CHK (校验 / 相位 lane) + UL_CLK (转发时钟), 800 Mbps/lane 标称 (转发时钟 400 MHz), '
                         '100 Ω ±10 % 差分, 每対 G-S-S-G, 桥侧 100 Ω 端接; lane i 两个字周期携带 d[i] / d[i+18]。阶段一 (8-bit, 现役 13-lane RTL) 只用 UL_D[11:0] + UL_CHK + UL_CLK = 14 対, 其余物理接通逻辑不用'),
        ('D2 两面相同', '两面接口完全相同, 各一套连接器'),
        ('D3 JTAG 加载', '程序加载 = JTAG 4 根 (TCK / TMS / TDI / TDO), 取代 v2 的 7 位 SSPI / 从串配置预留; 桥片位流不得把 JTAG 脚回收成 GPIO; 桥片 flash 焊盘保留 DNP 作退路'),
        ('D4 边带 4 根', '边带 4 根: SB_ALIGNED (桥 → SoC, 训练握手; SoC 侧外部下拉 2.2 kΩ, SoC 在释放 SB_RSTN 且读到 IDCODE 前不采信)、SB_RSTN (SoC → 桥; 桥侧外部下拉 2.2 kΩ)、SB_UART_B2S、SB_UART_S2B'),
        ('D5 单端 2.5V', '接口所有单端 (边带 4 + JTAG 4) 统一 2.5V LVCMOS。LED 模组侧: 边带放 GW5A 2.5V 组 (VCCIO23 由 V2 底板设 2.5V / VCCIO67 核心板固定 2.5V); GW5A JTAG 在 bank10 固定 3.3V '
                        '(P1.94 TDO / 96 TDI / 98 TMS / 100 TCK) ⇒ V2 上做 2.5V ↔ 3.3V 电平转换 (固定方向、带 Ioff 的双电源转换器; TDO 3.3 → 2.5, TCK / TMS / TDI 2.5 → 3.3), V2 上留下载器插座与 SoC JTAG 0 Ω / 跳线二选一'),
        ('D6 分开上电', '晶振在 LED 模组本地、电源不走接口; 两模组分开上电 ⇒ SoC 在读到桥片 JTAG IDCODE 之前不驱动 LVDS 与边带'),
        ('D7 FS03 双面', '验证期 FS03 必须同时驱动 2 块屏 + 光电开关 (转子索引); FS03 两个 CEP bank 都改板把 VCCIO 改 2.5V (DR1 才能发 LVDS25; 3.3V bank 只有 LVDS33_E 300 Mbps, '
                         '差分输入只支持 LVDS25 / 18 —— DS1200 V1.0 §2.7 注 1 / 2、表 3-21 / 3-22, 经任务单转述)。改板方案见 dr1v90/fs03_mod/README.md v2.2 (未实施)'),
    ]:
        add('v3 决定 (已定)', dk, dtxt, '用户 09-15 下午 (经任务单转述)')
    add('口径', '为什么是 18 数据 lane', f'24 颗 ICND2260 每字槽 72 字节; 零 mux 分发要求每 beat 字节数 2N 被 3 整除且整除 72 —— 单凭这两条 N ∈ {{{", ".join(map(str, N_DIV))}}}; '
        f'再加带宽下限 N ≥ {N_MIN} (8-bit 载荷 {PAYLOAD_GBPS_8} Gbps/面 ≤ N × 800 Mbps × 126/128 ⇒ N ≥ {PAYLOAD_GBPS_8 * 1000 / (800 * SYNC_EFF):.2f}; '
        f'N = 9 只有 {9 * 800 * SYNC_EFF / 1000:.2f} Gbps) 与对数上限 (N = 36 每面 38 対, 过多) ⇒ N ∈ {{12, 18}}。'
        '18 lane: 每 beat 36 字节 = 12 条链, 2 个 beat 一个字槽; lane i 在较早 / 较晚两个字周期分别携带 d[i] / d[i+18] (现 12 lane 是 d[i] / d[i+12])。',
        '用户 09-15; SPEC.md §1; bridge_defs.vh §1 (9.003 Gbps) / §2 (126/128) / §3; 本表计算')
    add('阶段', '阶段一 (8-bit)', '现役 RTL 13-lane 协议不改 lane 数: 只用 UL_D[11:0] + UL_CHK + UL_CLK = 14 対 (契约子集, 契约第 4~17 対); '
        'UL_D[17:12] 物理接通、逻辑不用。', 'uplink_rx_defs.vh UL_NLANE = 13')
    add('阶段', '阶段二', f'12-bit, 或 8-bit 18 lane, 20 対全用。8-bit 18 lane 占用: 800 / 700 / 600 Mbps = {OCC[800]} / {OCC[700]} / {OCC[600]} %; '
        f'12-bit 只能 800 Mbps ({OCC12} %), 12-bit 协议尚未定义 (UL_WORDBITS = 8)。现 12 lane 8-bit @800 Mbps 占用 {OCC_NOW} %。',
        'bridge_defs.vh §1 载荷 9.003 Gbps/面, §2 SYNC 开销 126/128 (本表按此计算)')
    add('链路', '速率 / 时钟', "800 Mbps/lane 标称 (UI 1250 ps); 转发时钟 400 MHz = ODDRx2 发 4'b0101 (协议定案, uplink_tx_frame.fwd_clk)。"
        "⚠ 现役探针顶层 uplink_tx_top.v 的 txclk 发 4'b1100 = 200 MHz, 拿探针位流上板量到 200 MHz 属正常。",
        'uplink_tx_frame.v 端口 fwd_clk; uplink_tx_top.v 第 129 行')
    add('链路', '电平', '差分: 契约按目标板 LVDS25 (VOCM 典型 1.25 V), 100 Ω ±10 % 差分, 每対 G-S-S-G, 接收端 (桥) 100 Ω 端接; 验证板 FS03 两个 CEP bank 改 2.5V 后 DR1 直接出 LVDS25 '
        '(D7, 改板方案 README v2.2, 未实施), V3 上无电平适配 (FS03 原厂状态只能出 LVDS18, 已被 D7 取代)。'
        '单端 (边带 4 + JTAG 4): LVCMOS25 2.5V (已定 D5); GW5A 的 JTAG 在 bank10 固定 3.3V, 由 V2 上固定方向、带 Ioff 的双电源电平转换器转换 (模组内部实现)。',
        f'sheet5 {ECODE["lvds25"]} / {ECODE["adapt"]} / {ECODE["sideband_level"]} / {ECODE["jtag"]} / {ECODE["jtag_shift"]}')
    add('链路', '帧 / 训练', '训练码 TRAIN = 0x35 (所有 lane); 一帧 64 beat, beat0 为 SYNC beat = 两个字周期 (0x35, 0xCA); 位序 bit0 先上线 (ODDRx2 d0 先出)。',
        'uplink_rx_defs.vh (UL_TRAIN / UL_SYNC2 / UL_FRAME_BEATS)')
    add('链路', '校验 lane UL_CHK', "chk_early = 本 beat 数据字节的 CRC-8/ATM (多项式 0x07, 初值 0x00, MSB 先入, 按 d[0]→d[末] 顺序; 阶段一 24 字节, 阶段二 36 字节待 RTL); "
        "chk_late = {4'b0, beat_phase[1:0], slot_wrap, frame_start}。", 'SPEC.md §1 校验 lane 表')
    add('链路', '训练握手', 'DR1 发端要看到桥片 st_all_aligned 连续稳定 TRAIN_HOLD = 64 拍才退出训练; 不能用 st_link_up (死锁) ⇒ 契约必须有桥 → SoC 的 SB_ALIGNED (位置 62); '
        '桥片配置前 / 配置中 GPIO 默认弱上拉 (UG304 §3.3) ⇒ 该线 SoC 侧外部下拉 2.2 kΩ, SoC 在释放 SB_RSTN 且读到桥片 JTAG IDCODE 之前不采信 (已定 D4)。',
        'uplink_tx_frame.v 文件头【训练握手】; 用户 09-15 D4')
    add('链路', '上电与在位', '两模组分开上电、电源不走接口 (D6): SoC 先经 JTAG 读桥片 IDCODE (桥片在位且已上电), 读到之前不驱动 20 対 LVDS 与 SB_RSTN / SB_UART_S2B; '
        'JTAG 本身是在位探测通道, 不受此限 —— 桥模组侧电平转换器必须带 Ioff (桥模组未上电时 SoC 驱 JTAG 不灌电)。'
        '桥 → SoC 方向 (SB_RSTN 为低时桥片与其 flash 镜像不驱高) 与上下电顺序 (SoC 模组先上电、最后断电; 验证期 = FS03 上电 → 闸门 (J_TP11、SENSE33、TP_TDO_A) → 加载 LVDS25 位流 (位流内 LVDS / SB_RSTN / SB_UART_S2B 保持不使能) '
        '→ LED 模组 (V2 + 核心板 + V1) 上电 → SoC 轮询 IDCODE (不设失败超时, 只上报) → 读到后使能该面; 断电: LED 模组先断, FS03 最后断电) 为建议, 验证期按改板方案 README v2.2 §5.7 硬规则强制执行。'
        '在位判据: IDCODE 精确等于 0x0001281B; TDO 读到全 1 只作"不在位"提示。',
        f'用户 09-15 D6; sheet5 {ECODE["powerup"]}')
    fa_, fb_ = SOC_IMPL['faces']['A'], SOC_IMPL['faces']['B']
    add('结论', '验证板 SoC 侧', f'D7 双面 (前提: 两个 CEP bank 改 2.5V, 改板方案待定): 面 A = {fa_["cep"]} / bank{fa_["bank"]} 非劈开 20 対 (时钟 {SOC_SUM["clk"]["A"]}; '
        f'与现役 uplink_pin.adc 沿用 {len(A_KEEP)} / 改动 {len(A_MOVE)} / 新球位 {len(A_NEWBALL)}); 面 B = {fb_["cep"]} / bank{fb_["bank"]} 20 対 (避 {L12}, 时钟 {SOC_SUM["clk"]["B"]}, 全新); '
        f'单端 {SOC_SUM["se_balls"]} 球 = 劈开対 {2 * len(SPLIT33)} + bank11 余量 {2 * len(B_SPARE)} (两面各边带 4 + JTAG 4, TCK / TMS 两面共用, V3 分叉; 两面 JTAG 整组落 bank33 的 6 个 ADC 复用球、'
        '边带落非 ADC 球且每面 SB_RSTN 与本面 SB_ALIGNED / SB_UART_B2S 同在 bank11 —— DS1200 §4.2 ADC 复用注与门控同 bank, ADC 复用球作 LVCMOS 输出是否允许待定); '
        f'光电开关 {SOC_SUM["spin"]} (KEY2, bank32 3.3V, CEP 外); CEP {SOC_SUM["cep_io"]} 个 IO 全部分配 (含预留 {L12})。两面 LVDS 余量 0, 40 対须 TD 试综合 (Error-8221); 全部分配为建议。'
        'v2 的单面二选一已被 D7 取代。', f'sheet3 / sheet6 / sheet8; {DCODE["soc_dual"]} / {DCODE["fs03_25v"]}')
    add('结论', '验证板 LED 侧', f'上行 20 対放 VCCIO45 (3.3V 固定, bank4/5 = Bottom): 22 対用 20, 余 2 (B5_B8 / B5_B12, 带配置复用, 空置); 阶段一 14 対 = bank4 11 + bank5 3; '
        f'转发时钟 B4_B33 (GCLKT_9A / BPLL_T_IN1)。边带 4 根改放 2.5V 组 (LVCMOS25): 桥 → SoC 的 SB_ALIGNED / SB_UART_B2S 用 VCCIO67 半対 {" / ".join(SB_HALF)}, '
        f'SoC → 桥 的 SB_RSTN / SB_UART_S2B 用 VCCIO23 原隔离対 {SB_PAIRS[0]}; VCCIO45 的 4 个半対改为空置。'
        f'JTAG: 契约 → V2 电平转换 (2.5V ↔ 3.3V) → 核心板 P1.100 TCK / 98 TMS / 96 TDI / 94 TDO (bank10 固定 3.3V); V2 上下载器插座与 SoC JTAG 0Ω 二选一。'
        f'下行: VCCIO23 (底板设 2.5V) + VCCIO67 (2.5V) = 47 対, 扣隔离 {GUARD_ONLY[0]} 与边带 {SB_PAIRS[0]} = {len(DOWN_PAIRS)} 対 + {len(DOWN_HALF)} 单端; '
        f'36 数据 + 1 时钟 + 9 单端需 {NA[0]} 対, 余 {NA[1]} (v2 余 {NA_V2[1]}, 少的 1 対是边带占 2 个 2.5V 半対所致); '
        f'但其中 {len(DOWN_B26)} 対在 Bank2/Bank6 (Left/Right, DS1103 表 2-11 注[3] 速率偏低无数字), 剔除后缺 {-NC[1]} 対 —— 承重未证项 {DCODE["b2b6"]}。', 'sheet4 / sheet8')
    add('图例', '已定 (绿)', '有原理图 / 手册原文 / 用户决定 / 现役约束为据; 要改就得重跑工具或改板。', '', ['b', 'ok', 't', 't'])
    add('图例', '建议 (黄)', '本表按规则给出的分配或做法。未经 TD / Gowin 工具试综合或上板验证的球位一律只能是建议。V2 / V3 还没画, 可以改, 改了同步改约束。', '', ['b', 'sug', 't', 't'])
    add('图例', '待定 (红)', '需要决策或上板验证才能定, 不得当"已定"用; 清单见 sheet9 待定事项。', '', ['b', 'tbd', 't', 't'])
    add('图例', '状态格写法', f'开头两个字是结论, 括号里是补充; sheet2 分"信号与电气"与"位置号"两列状态, sheet3 分面 A / 面 B 两列状态, sheet6 用途旁有状态列。'
        f'用户决定编号 D1~D7 (一位数) 与 sheet9 待定事项 D01~D{len(D_KEYS):02d} (两位数) 是两套编号。'
        'sheet3 / sheet4 底色: 绿 = 沿用现役球位, 黄 = 建议分配, 红 = 待定或风险, 灰 = 地 / 不接。', '')
    add('读表', 'sheet 列表', f'1 说明 · 2 模组间接口契约 (目标板口径, 逐导体 1~{TOTAL_POS}) · 3 验证板实现-SoC 侧 (面 A / 面 B + 边带 + JTAG + 光电开关) · 4 验证板实现-LED 侧 · '
        '5 电气与机械约束 (E01~E%02d) · 6 DR1V90_FS03_CEP 全表 (100 脚) · 7 GW5A_ACG525-CORE-V2 连接器全表 (200 脚) · 8 bank 预算 (GW5A 模块 + FS03) · 9 待定事项 (D01~D%02d)'
        % (len(E_KEYS), len(D_KEYS)), '每个 sheet 首行冻结、可筛选')
    srcs = [
        ('决定', '用户 2026-09-15 新决定 (经任务单转述): 上午 = 按目标板冻结 20 対契约、分阶段、800 Mbps 标称、LVDS25、100 Ω ±10 %、G-S-S-G、桥侧端接; '
                 '下午 D1~D7 = 每面 24 颗 / 20 対、两面相同各一套连接器、JTAG 4 根取代配置预留 (位流不回收 JTAG 脚, 桥片 flash 焊盘 DNP)、边带 4 根与 2.2 kΩ 下拉、单端统一 2.5V + V2 电平转换、上电与 IDCODE 规则、FS03 双面 + 两 CEP bank 改 2.5V'),
        ('决定', 'UG714-1.0.1 (本包) 表 3-5 (TCK 输入无上拉; TMS / TDI 输入片内弱上拉; TDO 输出) · 表 3-6 (JTAG PORT 可设为普通 IO —— D3 禁止) · 表 3-7 (Tj_clk ≥10 ns, Tj_dvld ≤3.0 ns); '
                 'UG714-1.0.6 (2026-08-27, scratchpad 副本, 不在本包) §3.4.1 注 / 表 3-7 注[1] (A 版 TCK ≥15 MHz) / PUDC_B 注[1] (25K 弱上拉为 Medium); 核心板原理图 p3 (Bank10 = VCCX = VCC3P3; A17 TCK / B18 TMS / D15 TDI / D16 TDO) 与 p1 (P1.94/96/98/100)'),
        ('并行流程', '本会话并行流程结论 (只作线索, 关键数字已回原文): wf_3cee62db research:gw5a (UG714-1.0.6 A 版 TCK 下限; CB-V2 P5 下载座 1 TCK / 2 GND / 3 TDO / 4 VCC3P3 / 5 TMS / 9 TDI / 10 GND; JTAG 线上无元件) · '
                     'research:fs03 (FS03 双面 IO 预算: 初版按 1.8V bank、每面 7 根算, fix 步 cep_budget.py 已改 v3 口径每面 8 根 / 2.5V, 双面 17 → 余 −3; CB-V2 JTAG 台架飞线 CEP1.4 / 5 / 15 / 18 → P5) · '
                     'review #1 (openFPGALoader 写 GW5A SRAM 前先 RELOAD 从 flash 重配, gowin.cpp:267~271 / 384~393) · '
                     'wf_91b9a995 read:A / read:B (FS03 电源树: 1.8V 轨负载含 2.5V 绝对最大值器件, 不能整轨改 2.5V; 无空贴稳压位) / design v1 → v2 (两 bank 改板方案) / review v1 (已被 v2 吸收) → review v2 (0 critical / 3 major / 7 minor) · '
                     'P2 (FS03 双面分配 p2_fs03_alloc.py: CEP 链与 pinmap / cep_pin_table.tsv 一致, 两面时钟 GCLK, 单端 14 = 劈开 8 + 余 6; 本表 SOC_IMPL 内嵌其结果并逐项断言)'),
        ('协议', 'dr1v90/eg4_bridge/SPEC.md §1 (lane 用途 / 字节映射 / 校验 lane / 填充 36→40)'),
        ('协议', 'dr1v90/eg4_bridge/rtl/bridge_defs.vh §1 带宽核对 9.003 Gbps · §2 lane 划分与 126/128 SYNC 开销 · §3 字节→(链, lane) 映射 · §4 8-bit 源色深直传 · §5 dclk 150 MHz / ODDR 300 Mbps · §6 分发 FIFO 通式 (BR_FIFO_SLOTS = 384)'),
        ('协议', 'dr1v90/uplink_rx/rtl_v3/uplink_rx_defs.vh (UL_NLANE 13 / UL_WORDBITS 8 / UL_TRAIN 0x35 / UL_SYNC2 0xCA / UL_FRAME_BEATS 64); uplink_rx_top.v (st_all_aligned / st_link_up / FRAME_MISS = 4)'),
        ('协议', "dr1v90/uplink_tx/rtl/uplink_tx_frame.v 文件头【训练握手】与端口 (fwd_clk / rx_all_aligned / TRAIN_HOLD); uplink_tx_top.v (现役探针 txclk 4'b1100)"),
        ('系统', 'pcb/00_目标电路总览.md §2.1 (上行不排 bank33 → bank11/31/32) · §2.2 (从串 CCLK/DIN/PROGRAM_B/INIT_B/DONE) · §4 板间接口表 (配置 5~6 根 3.3 V, CCLK ≤24 MHz)'),
        ('DR1', 'dr1v90/uplink_tx/soc_prj/uisrc/04_pin/uplink_pin.adc (现役 14 対探针球位, 面 A 沿用对照; 由 tools/gen_uplink_adc.py 生成)'),
        ('DR1', 'DS1200_Datasheet_V1.0 表 3-4 (推荐: PL I/O 直流输入 ≤ VCCIO+0.165, VCCIO @2.5V 2.375~2.625 V, TVCCIO 0.2~100 ms) · 表 3-5 (VCCIO_33 必须供电 / VCCIO_11 可选择性供电) · 表 3-8 (热插拔: 每 I/O 直流 ≤350 µA)'),
        ('FS03', 'FS03 原理图 p16 (KEY1~3 = L19 / K18 / J18, 各 2.2 kΩ 上拉 VCC_3V3 + 0.1 µF; 本步渲染核 KEY2) · dr1v90/td_pov/soc_prj/uisrc/04_pin/fpga_pin.adc:35 与 dr1v90/constraints/panel_pins_dr1.adc:35 '
                 '(spin_sync_i = W6 LVCMOS33; bank11 31 球, 脚本核) · dr1v90/jtag_load/fs03_io/out/cep_pin_table.tsv (CEP 96 脚上电态与现役占用)'),
        ('FS03', 'dr1v90/fs03_mod/README.md v2.2 (两 bank 改板方案: §1 结论与硬规矩 / §5.2 互斥清单 / §5.4 电流预算 / §5.5 模块电路 / §5.6 插接方案 P / S / D 与开窗 / §5.7 上下电规则 / §5.8 光电挪 K18 / §5.9 实施步骤 / §5.12 V3 计算; v2 备份 README_v2_before_review2.md) · '
                 'dr1v90/fs03_mod/V3_design_inputs.md (V3 设计输入: B 闸门测点 / C 串阻与下拉 / F 开窗净空 / G 同步本表的措辞) · '
                 '改板审查 v2 (wf_91b9a995 review 第 2 条: M1~M3 / m1~m7, README v2.2 §10.2 逐条落实) 与 v2.1 复核 (J_TP 电阻隔离 / SB_ALIGNED 未配置电平 0.643 V / DR1 → 对端不串阻依据) · '
                 'dr1v90/docs/PANEL_BRINGUP_CHECKLIST.md §4.2 #3 (5V 灌入改法: 贴 L16 / L17、拆 L18 / L19)'),
        ('DR1', 'pcb/dr1v90_core_v1/05_机读数据/DR1V90GEG484_pinmap.csv (球位 → bank / 管脚名 / 差分対 / GCLK / ADC)'),
        ('DR1', 'DS1200_Datasheet_V1.0 §4.2 管脚定义注 (印刷页 62: ADC0P/N~ADC15P/N 可作复用 I/O 输入端口; LVCMOS 模式下同一接口功能单元不与其他 PL I/O 混用、对时钟占空比敏感时 < 30 MHz、'
                '对端驱动 FAST 或 slew rate > 3.3 V/ns; LVDS 电平模式不涉及) · §2.8.2 表 2-6 (上电固定态) ·§3 推荐上电顺序 VCCINT→VCCAUX(VCCPLL)→VCCIO · 表 3-1 (PL I/O 直流输入上限 VCCIO+0.3) · 表 3-9 (PL 弱上拉 / 下拉电流, 含 VCCIO 2.5V 档) · 表 3-11 (PL 单端门限, LVCMOS25 VIL 0.7 / VIH 1.7 / VOH ≥ VCCIO−0.4) · 表 3-14 (LVDS25/18 直流) · 表 3-22 (输出 1250 Mbps)'),
        ('DR1', '记忆库 project_dr1_uplink_tx_probe (SWNS +0.010 ns, PackReg = DDRX2 14/14, Error-8221: ODDRx2 合法 IOBE 球位无公开表); '
                'dr1v90/td_panel/soc_prj/fpga_prj_Runs/phy_1/td_20260806_150332.log Detailed IO Report (bank11 AB10 / V12 PackReg = DDRX1)'),
        ('FS03', 'FS03 硬件使用手册 §16 GPIO (CEP 表) / §18 电源 (供电顺序 VCCINT→VCCAUX→3.3V&1.8V&1.35V)'),
        ('FS03', 'FS03 原理图 P17_GPIO (J11/J12, R187~R210 33R 排阻) / P01_BANKPWR·P08_PWR (J1 = ADJ_BANK11, J2 = ADJ_BANK33: 1 = VCC_3V3, 2 = ADJ, 3 = VCC_1V8) / P06_BANK11&33; 物料表 R187~R210 = 33R RA4_0402 ×24'),
        ('FS03', 'dr1v90/docs/PANEL_BRINGUP_CHECKLIST.md §4.2 #1 (直驱屏要求 J1 = 3.3V); dr1v90/constraints/panel_pins_dr1.adc (直驱屏用 bank11 LVCMOS33)'),
        ('GW5A', 'ACG525-CORE-V2 核心板原理图 PDF 第 1 页 (P1/P2) / 第 3 页 (VCCIO 与 VCCX) / 第 4 页 (网名↔球位; U2 启动 flash、配置上拉、50M 晶振)'),
        ('GW5A', 'UG985_V1.7.2 (修订记录 v1.3.1 删 MCKTEST/ADCINCLK/ADCOTEST; Pin List UG324) —— 配置复用以此为准 (与 IDE json 的 24 脚差异嵌入脚本 ug985_cfg, pdftotext 可用时全量复核); UG714_V1.0.1 表 3-1 (MODE[1:0], 注[4] MSPI 失败自动进 SSPI) · EMCCLK / CCLK 管脚说明 · Dual-Purpose Pin 菜单'),
        ('GW5A', 'UG304_V1.3 (2024-06-28, 本包) §3.1 / §3.2 GPIO 分区策略 / §3.3 (配置前及配置过程中所有 GPIO 默认弱上拉; 核电压与 VCCIO 无上下电顺序要求) / §3.3.2 (所有分区支持片内 100 Ω 差分匹配)'),
        ('GW5A', 'DS1103-1.0.9 表 2-6/2-7 (IO 标准与 VCCIO) · 表 2-8 (IODELAY) · 表 2-11 注[3] (25K Bank2/Bank6 速率偏低) · 表 3-6 (VCCX) · 表 3-16 (GW5A-25 IPU / IPD) · 表 3-23 (LVCMOS33/25 门限) · '
                 '表 3-26 (差分输入 VICM 0.3~2.35 V / VID ±100 mV / RODT) · 表 3-27/3-28 (TLVDS/ELVDS 输出) · 表 3-34 (GW5A-25 Gearbox)'),
        ('GW5A', 'ACG525-CB-V2-260316_SCH/ACG525-CORE-V2.SchDoc (经 dr1v90/gw5a_loop/tools/schnet.py 解 200 脚); Gowin IDE data/device/GW5A-25A/UBGA324.json; dr1v90/gw5a_loop/pins_v2.tsv'),
        ('GW5A', 'dr1v90/gw5a_loop/results/n13_l800_verA/SUMMARY.txt + run.cst (LVDS25 DIFF_RESISTOR=ON BANK_VCCIO=3.3 于 bank2/3/4, WNS 2.340 ns, 工具层); README_x8.md (rtl_x8 WNS +1.986 ns); '
                 '资料包 02_…/04_环回自测位流_到板即可烧/wiring_n13_l800_verA.txt / verB.txt (lane8~10 TX U13/V13、R11/T11、U16/V16 bank4 → RX U17/U18 bank3) 与 wiring_n4_l800_verB.txt (只用 bank2)'),
        ('下行', '03_公共/ICND2260_V1.7 mini-LVDS 电气特性 (VIC 1.1~1.3 V); zynq_pov/docs/转接板接口与拓扑_2026-09-10.html §4 (验证灯板 36 数据 + 12 时钟 + 9 单端)'),
        ('记忆库', 'zynq_pov/docs/claude_memory/: project_pov3d_bridge_stamp_module · project_pov3d_adapter_board_and_uplink_bank · reference_dr1_bank33_poweron_forced_pins · '
                 'project_pov3d_fs03_cep_ground_and_third_row · project_gw5a_bridge_verification · project_pov3d_master_and_bridge_both_on_rotor (只当线索, 数字已尽量回原始表核对)'),
    ]
    for k, (cat, s) in enumerate(srcs, 1):
        add('数据来源', f'{cat} #{k}', s, '')
    add('核对', '机读交叉核对', '脚本每次运行先用 pinmap.csv / uplink_pin.adc / UBGA324.json / pins_v2.tsv / UG985 PDF (pdftotext) 复核嵌入数据 (97 球 / 现役 .adc 14 対 / 164 信号脚 / 73 行 / 154 个 IO 脚配置功能; JTAG 4 球 bank10 与 CFG 字段), '
        f'再对本表分配做结构断言: 契约 {TOTAL_POS} 位不重不漏、TCK 单独成组两侧为地; 面 A = bank33 去掉 4 个劈开対; 面 B 避开 L12_11 且时钟落 GCLK; GW5A 上行 20 対 + 空置 2 対 = VCCIO45 全部 22 対; '
        '边带全部落 2.5V 组 (桥 → SoC 输出在固定 2.5V 的 VCCIO67)、不占上行 / 下行対、无配置复用; JTAG 四脚 = P1.94 TDO / 96 TDI / 98 TMS / 100 TCK 且方向与转换方向一致; '
        'SoC 双面: check_soc_impl (P/N 同対 / bank / 劈开対 / L12 / 时钟 GCLK / 球不重, 共用须两面同名互指, 单端 vccio 与所在 bank 一致, SB_ALIGNED 2.2 kΩ 下拉; 正反例自测) + 合并断言 '
        '(两面各 20 対且时钟落 GCLK、LVDS 不占劈开対、CEP IO 无重复分配、光电开关已分配; check_soc_impl 另查一面 JTAG 不混用 ADC 复用球、SB_RSTN 与本面 SB_ALIGNED / SB_UART_B2S 同 bank、TDO 与 TCK 同 bank; '
        '内嵌数据另核 CEP 96 IO 全分配、单端 = 劈开 8 + 余量 6、两面 JTAG = bank33 全部 6 个 ADC 复用单端球、边带不落 ADC 复用球、TCK 所在球为表 2-6 强制下拉、CB-V2 飞线脚位), '
        'verify 另核 K18 / J18 与 pinmap.csv、spin_sync_i = W6 与直驱屏 bank11 31 球, 产物回读核 sheet3 球位 = SOC_IMPL、sheet6 无"未用" IO; '
        '核心板占用的 flash / 配置 / 50M 球不在连接器上; 连接器 P/N 脚序、MIPI / JTAG 脚位、UG985 与 json 差异集; 下行核算数字与边带下拉算式; 状态格颜色 = 开头词且括号外无第二状态。', '')
    conflicts = [
        'GW5A 片内 100 Ω 分区: 本包 UG304-1.3 §3.3.2 写"所有分区支持", 同文 §3.1 又说"特定分区支持…差分输入匹配, 见 3.2"但 §3.2 未列分区; DS1103 表 3-26 (25/60) RODT 未注分区 (只有 138K 的表注写 Left/Right ODT 140 Ω); '
        'gw5a_loop 工具在 bank2 (Right) 接受 DIFF_RESISTOR=ON; 任务口径引 "UG304-1.3.7 仅 Top/Bottom", 本包无该版本。未裁决; 上行放 bank4/5 (Bottom) 两种读法都成立',
        'DS1103 表 2-11 注[3] "25K Bank2/Bank6 传输速率偏低" 挂在 MIPI IO 类型支持表下, 措辞泛指, 无数字 —— 是否适用于 ELVDS / TLVDS 未知',
        'pcb/00_目标电路总览.md 仍写上行 13 対 + 1 対钟、桥片侧 GCLKIOL (EG4 口径)、配置 5~6 根 3.3V 从串 —— 与 09-15 的 20 対契约、JTAG 4 根 2.5V (D3 / D5) 不一致 (旧口径未更新)',
        'SPEC.md 开头写下游 "24 链 × 3 対 mini-LVDS @333 Mbps", bridge_defs.vh §5 定案 dclk 150 MHz ⇒ ODDR 300 Mbps/対 (333 是 166.67 MHz 旧工作点)',
        'FS03 CEP2.7: 手册 §16 写 Y19 (bank31), 原理图 P17 链路为 Y9 (IO_L12P_11, GCLKIOT2)',
        'FS03 CEP 线上 33Ω 排阻 R187~R210 (原理图 + 物料表) vs 记忆库曾判"排阻为编造"',
        '核心板 VCCIO01 / VCCIO67 由核心板自产 (FB4←VCC1P5 / FB3←VCC2P5) vs 记忆库"四组都由底板供"',
        f'配置复用口径: IDE UBGA324.json 与 UG985 V1.7.2 Pin List UG324 在连接器 {N_IO} 个 IO 脚里 {len(UG985_CFG)} 脚不同 —— json 独有 MCKTEST / ADCINCLK / ADCOTEST '
        f'(UG985 修订记录 v1.3.1 删除) 与 IOB4A / IOB4B 的 SDA / SCL; UG985 独有 {len(UG_UG985_ONLY)} 脚的 PLL IN / FB 复用 (如 IOB33B BPLL_C_IN1、IOB4A LPLL1_T_FB0); '
        '核心板原理图符号把 ADCCLKTEST 标在 IOR14A。本表显示与计数按 UG985, 逐脚差异注在 sheet7 备注; Gowin 工具按 json 判双用途脚',
        '记忆库 project_pov3d_bridge_stamp_module 上行边带 = 配置 5 + rstn + 回读 2 (EG4 从串假设); 本契约 v3 = 边带 4 + JTAG 4 (用户 09-15 D3), v2 的 7 位配置预留已取代',
        'GW5A-25 JTAG TCK 下限: 本包 UG714-1.0.1 只写"不能高于 100 MHz"; UG714-1.0.6 (2026-08-27) 新增"A 版本芯片不能小于 15 MHz, 其他版本无最低频率"; 用户口径 TCK ≤10 MHz 建议 —— '
        '桥片若为 A 版则冲突; IDCODE 两版同为 0x0001281B, 读 ID 分不出版本 (UG714 IDCODE 表; 并行流程 research:gw5a)',
        'FS03 CEP pin1: 原理图出厂态经 L19 / L18 接 VCC_3V3 (L16 / L17 NC) vs PANEL_BRINGUP_CHECKLIST §4.2 #3 "5V 灌入改法" (做过则两个 pin1 都是 VIN_5V0) —— 这块板改没改无记录, 未实测',
        'DR1 PL 输入上限: DS1200 表 3-1 绝对最大 VCCIO+0.3 (sheet5 边带核算所用) vs 表 3-4 推荐 VCCIO+0.165 —— 2.5V 直连在两侧 ±5 % 反向最坏时超推荐值',
    ]
    for k, s in enumerate(conflicts, 1):
        add('资料冲突', f'#{k} (原样列出, 未裁决)', s, '详见 sheet5 / sheet9')
    return 'sheet1', '说明', H, W, R


# ---------------------------------------------------------------- sheet2 模组间接口契约
def lane_role(k):
    if k == 'CLK':
        return ("转发时钟: 400 MHz 方波 (协议定案 ODDRx2 发 4'b0101, uplink_tx_frame.fwd_clk); 不带数据; 桥侧作 IDES8 采样时钟参考 / PLL 参考")
    if k == 'CHK':
        return ("校验 lane (= 现 RTL lane12 角色): chk_early = 本 beat 全部数据字节的 CRC-8/ATM (0x07, 初值 0x00, MSB 先入, d[0]→d[末]); "
                "chk_late = {4'b0, beat_phase[1:0], slot_wrap, frame_start}; 训练期发 0x35")
    i = int(k[1:])
    return f'数据 lane {i}: 较早字周期发 d[{i}], 较晚字周期发 d[{i + 18}] (8-bit 18 lane); 训练期发 0x35'


def lane_ph1(k):
    if k == 'CLK':
        return "用 (协议定案 400 MHz; 现役探针 uplink_tx_top.v 发 4'b1100 = 200 MHz)"
    if k == 'CHK':
        return '用: = 现 RTL lane12, chk_early 覆盖 24 字节 d[0]→d[23]'
    i = int(k[1:])
    if i < 12:
        return f'用: = 现 RTL lane {i}, 较早 d[{i}] / 较晚 d[{i + 12}]'
    return f'物理接通, 逻辑不用 (现 RTL 13 lane 不例化; 发端驱不驱见 «d:ph1_unused»)'


def sheet_contract():
    H = ['契约位置号 (建议脚序)', '信号名', '对内 P/N', '方向', '信号类', '逻辑角色 (阶段二 = 契约全量)', '阶段一 (8-bit, 现役 13-lane RTL)',
         '电平与共模', '速率', '端接 / 阻抗', '地与相邻 / 备注', '出处', '状态 (信号与电气)', '状态 (位置号)']
    W = [9, 15, 6, 10, 11, 50, 34, 44, 28, 32, 34, 30, 22, 14]
    rows = {}

    def sty(s1, s2, gray=False, red=False):
        base = 'gray' if gray else ('r' if red else 't')
        s = [base] * len(H)
        for i in (0, 2, 3):
            s[i] = 'gray' if gray else 'c'
        s[1] = 'gray' if gray else 'b'
        s[12], s[13] = st_style(s1), st_style(s2)
        return s

    for p in DIFF_GND:
        edge = '; 阶段一组的边界地' if p in PH1_SPAN else ''
        v = [p, 'GND', '—', '—', '地', 'G-S-S-G 的 G: 每対两侧各 1 根地' + edge, '—', '—', '—', '—',
             '两模组地经此回流; 不承载电源电流', '用户 09-15 (G-S-S-G)', '已定 (G-S-S-G)', '建议 (脚序)']
        rows[p] = (v, sty(v[12], v[13], gray=True))
    for k in PAIR_ORDER:
        role = lane_role(k)
        ph1 = lane_ph1(k)
        if k == 'CLK':
            rate = "400 MHz 方波 (= 800 Mbps 的位时钟一半; 协议定案 4'b0101)"
            st1 = '已定 (契约)'
            note = '位于 20 対正中 (第 10 対), 阶段一 14 対也居中; 验证板两端都落 GCLK 対'
        elif k == 'CHK':
            rate = RATE_DATA
            st1 = '已定 (契约; 36 字节 CRC 待 RTL)'
            note = '紧邻 UL_CLK'
        else:
            rate = RATE_DATA
            i = int(k[1:])
            st1 = '已定 (契约; 阶段二启用, RTL 未实现)' if i >= 12 else '已定 (契约; 阶段一已有 RTL)'
            note = '阶段二 lane, 在 20 対两端' if i >= 12 else '阶段一 lane'
        for pol, pos in zip('PN', CPOS[k]):
            v = [pos, f'{sname(k)}_{pol}', pol, 'SoC → 桥', '差分·时钟' if k == 'CLK' else ('差分·校验' if k == 'CHK' else '差分·数据'),
                 role, ph1, ELEC_DIFF, rate, TERM_DIFF, note + '; 对内等长, 对间偏斜由桥侧每 lane IODELAY 吸收',
                 '用户 09-15; SPEC.md §1; bridge_defs.vh §2/§3; DS1200 表 3-14 (LVDS25)', st1, '建议 (脚序; 形态由硬件定)']
            rows[pos] = (v, sty(st1, v[13]))
    for s in SB:
        v = [s['pos'], s['name'], '单端', s['dir'], s['cls'], s['role'] + '。RTL: ' + s['rtl'], s['ph1'], ELEC_SE + '; ' + s['ex'], s['rate'],
             '单端 50 Ω 参考地; 无端接 (低速)', se_group_note(s['pos']),
             'uplink_tx_frame.v【训练握手】; uplink_rx_top.v; eg4_bridge_top.v 端口表; UG304 §3.3 (桥片配置期弱上拉); 用户 09-15 D4 / D5',
             '已定 (D4 信号与 2.2 kΩ 外部下拉 / D5 2.5V)' if s['name'] in ('SB_ALIGNED', 'SB_RSTN') else '已定 (D4 信号 / D5 2.5V; 波特率与收端上拉为建议)',
             '建议 (脚序)']
        rows[s['pos']] = (v, sty(v[12], v[13]))
    for j in JTAG:
        if j['tap'] == 'TCK':
            rate, term = JTAG_TCK_RATE, '单端 50 Ω 参考地; 无端接; 走长线时发端串 22~33 Ω 源端匹配 (建议); 单独成组两侧夹地'
            st1 = '已定 (D3 信号 / D5 2.5V; TCK 频率待定)'
        else:
            rate = ('随 TCK: TDO 在 TCK 下降沿更新, Tj_dvld ≤3.0 ns (UG714 §3.4.3 / 表 3-7)' if j['tap'] == 'TDO'
                    else '随 TCK: 上升沿采样, 建立时间 ≥3.0 ns (UG714 表 3-7 Tj_tmssu / Tj_dsu)')
            term = '单端 50 Ω 参考地; 无端接'
            st1 = '已定 (D3 信号 / D5 2.5V; 上下拉阻值为建议)'
        v = [j['pos'], j['name'], '单端', j['dir'], 'JTAG·程序加载',
             j['role'] + '。桥片位流不得把 JTAG 脚回收成普通 IO (GW5A: UG714 表 3-6 "JTAG PORT" 保持默认); 桥片 flash 焊盘保留 DNP 作退路 (D3)。'
             'SoC 上电后先经 JTAG 读桥片 IDCODE 判在位, 读到之前不驱动 LVDS 与边带 (D6)',
             '用 (验证板: SoC 加载 GW5A 位流; V2 上与下载器插座二选一)',
             ELEC_JTAG + '; ' + j['pull'], rate, term, se_group_note(j['pos']),
             '用户 09-15 D3 / D5 / D6; UG714-1.0.1 表 3-5 / 3-6 / 3-7; 核心板原理图 p1 / p3', st1, '建议 (脚序)']
        rows[j['pos']] = (v, sty(v[12], v[13]))
    for p in SB_GND:
        v = [p, 'GND', '—', '—', '地', '单端组地: 每 2~3 根单端夹 1 根地', '—', '—', '—', '—', '—', '本表建议', '建议 (单端组地)', '建议 (脚序)']
        rows[p] = (v, sty(v[12], v[13], gray=True))
    assert sorted(rows) == list(range(1, TOTAL_POS + 1))
    body = [rows[p] for p in sorted(rows)]

    rules = [
        ('规定·差分', 'UL_D[17:0] / UL_CHK / UL_CLK 共 20 対: ' + ELEC_DIFF + '; ' + TERM_DIFF + '; 每対 G-S-S-G; 対内 P/N 严格等长, 对间偏斜由接收端 IODELAY 吸收。',
         '用户 09-15; DS1200 表 3-14; DS1103 表 3-26', '已定 (用户 09-15)'),
        ('规定·速率', RATE_NOM + "; UL_CLK = 400 MHz (fwd_clk 4'b0101)。本条已定的只有 800 Mbps 标称; " + RATE_DOWN + ' —— 降速档不在本条已定范围, 并入 «d:proto_12bit»。',
         'bridge_defs.vh §1/§2 (本表计算); 用户 09-15 (800 Mbps 标称)', '已定 (800 Mbps 标称)'),
        ('规定·单端边带', 'SB_ALIGNED / SB_RSTN / SB_UART_B2S / SB_UART_S2B: ' + ELEC_SE + '。默认电平靠外部下拉, 不靠片内弱上下拉: SB_ALIGNED 在 SoC 模组侧、SB_RSTN 在桥模组侧各加外部下拉 2.2 kΩ '
         '(桥片配置前 / 配置中 GPIO 默认弱上拉 UG304 §3.3, 25K 为 Medium ≤150 µA; DR1 配置中 HSWAPEN = 0 弱上拉 ≤153 µA @2.5V DS1200 表 3-9; 算式见 sheet5 «e:sideband_level»); '
         'SoC 在释放 SB_RSTN 且读到桥片 JTAG IDCODE 之前不采信 SB_ALIGNED («d:rtl_readback»); UART 空闲高。SoC 模组侧如果在 SB_ALIGNED 上串限流电阻, 2.2 kΩ 下拉必须放在串阻的连接器侧 (否则分压读不到高); 串 kΩ 级电阻的桥 → SoC 输入禁用片内上拉。'
         'SB_RSTN 应与它门控的 SB_ALIGNED / SB_UART_B2S 放在 SoC 侧同一 bank (岛掉电时门控同时生效)。目标板 SoC 侧: 2.5V 单端可与 LVDS25 上行同 bank (VCCIO 同为 2.5V)。',
         f'sheet5 {ECODE["sideband_level"]}; UG304 §3.3; uplink_tx_frame.v【训练握手】; 用户 09-15 D4 / D5', '已定 (用户 09-15 D4 / D5)'),
        ('规定·JTAG', 'JTAG_TCK / JTAG_TMS / JTAG_TDI / JTAG_TDO 共 4 根 (D3): ' + ELEC_SE + '; TCK / TMS / TDI = SoC → 桥, TDO = 桥 → SoC; 用途 = 桥片位流加载 (写 SRAM) 与 IDCODE 在位检测。'
         '桥片位流不得把 JTAG 脚回收成 GPIO; 桥片 flash 焊盘保留 DNP 作退路。桥片 JTAG 电平不是 2.5V 时由桥模组内部转换 (GW5A: bank10 固定 3.3V ⇒ V2 上固定方向、带 Ioff 的双电源转换器, sheet5 «e:jtag_shift»)。'
         '静止电平 (建议): TCK 在桥模组侧下拉为低 (2.2 kΩ, 压得住 SoC 配置期弱上拉); TMS / TDI 在桥模组侧上拉为高 (22 kΩ 到桥模组本地 2.5 V, 与 SoC 配置期弱上拉同向; 接电源的上拉 ≥6.07 kΩ, SoC IO 岛未上电时反灌 ≤350 µA; 转换器输入不带 bus-hold); '
         'TDO 在转换器 B 口下拉 10 kΩ (必须); TAP 只在 TCK 上升沿动 ⇒ SoC 未驱动期间 TAP 不动; SoC 每次访问先发 ≥5 个 TMS = 1 的 TCK 复位 TAP, 不依赖上电态; '
         '每次访问结束也发 ≥5 个 TMS = 1 让 TAP 回到 Test-Logic-Reset (静止时桥片 TDO 高阻、被下拉, 无注入)。'
         '在位判据: IDCODE 精确等于桥片 IDCODE; TDO 弱上拉读到全 1 只作"不在位"提示。'
         + JTAG_TCK_RATE + '。',
         f'sheet5 {ECODE["jtag"]} / {ECODE["jtag_shift"]}; 用户 09-15 D3 / D5', '已定 (D3 / D5; TCK 频率待定)'),
        ('规定·上电', '两模组分开上电, 电源不走接口, 晶振在 LED 模组本地 (D6)。SoC 在经 JTAG 读到桥片 IDCODE 之前不驱动 20 対 LVDS 与 SB_RSTN / SB_UART_S2B (输出保持高阻 / 不使能); '
         'JTAG 是在位探测通道, 不受此限 ⇒ 桥模组侧 JTAG 转换器必须带 Ioff (桥模组未上电时 SoC 驱 JTAG 不灌电)。'
         '以下为本表建议 (非用户决定), 验证期按改板方案 README v2.2 §5.7 硬规则强制执行: ① 上下电顺序: SoC 模组先上电、最后断电 —— 验证期 FS03 上电 → 闸门 (J_TP11、SENSE33、TP_TDO_A) → 加载 LVDS25 位流 '
         '(位流内 LVDS / SB_RSTN / SB_UART_S2B 保持不使能) → LED 模组 (V2 + 核心板 + V1) 上电 → SoC 轮询 IDCODE (不设失败超时, 只上报) → 读到后使能该面; 断电: LED 模组先断, FS03 最后断电。'
         '② 桥 → SoC 单端 (SB_ALIGNED / SB_UART_B2S / JTAG_TDO) 在 SoC 未上电或 SB_RSTN 为低时不得驱高: '
         '桥片 RTL 与桥片 flash / 自测镜像都要在 SB_RSTN 为低期间把 SB_ALIGNED / SB_UART_B2S 输出为低或高阻 (SoC 模组未上电时 SB_RSTN 被桥侧下拉为低); TDO 由转换器 B 口下拉 (必须) + 无 TCK 不进 Shift 保证。'
         '理由: 反向注入经 SoC bank 钳位二极管, mA 级 ≫ DS1200 表 3-8 每 I/O 直流 350 µA。SoC IO 岛掉电而桥模组仍在驱动时: SB_ALIGNED / SB_UART_B2S 流入 SoC 每脚 ≤350 µA 由 SoC 模组侧串限流电阻实现 (验证板 V3 8.2 kΩ), '
         'JTAG_TDO 靠 TAP 自门控 (TCK 停 ⇒ 不在 Shift ⇒ TDO 高阻被下拉), 残余风险为移位中途掉电; 转换器的 Ioff 只管转换器自己断电。'
         '③ SoC 侧 TDO 弱上拉, 桥模组未上电时读到全 1 只作"不在位"提示; 在位以 IDCODE 精确等于桥片 IDCODE 为准。',
         f'sheet5 {ECODE["powerup"]}; 用户 09-15 D6; dr1v90/fs03_mod/README.md v2.2 §5.7 / V3_design_inputs.md G3', '已定 (D6; 上下电顺序与桥 → SoC 不驱高为建议, 验证期按强制执行)'),
        ('规定·形态', f'契约位置号是逻辑序号 (1~{TOTAL_POS}): 连接器形态 (FPC / B2B / 其他) 与实际脚号由硬件定, 只要求保持 G-S-S-G、对内 P/N 与位置相对顺序。建议脚序: 1~61 = 20 対 G-S-S-G; '
         '62/63 SB_ALIGNED / SB_RSTN, 64 GND, 65/66 SB_UART_B2S / SB_UART_S2B, 67 GND, 68 JTAG_TCK, 69 GND, 70~72 JTAG_TMS / TDI / TDO, 73 GND —— TCK 单独成组两侧夹地, 单端每组 ≤3 根、组间夹地。'
         '两面接口完全相同、各一套连接器 (D2); 连接器不走电源 (D6)。',
         '本表建议; 用户 09-15 D2 / D6; project_pov3d_bridge_stamp_module (上行走独立阻抗受控 FPC)', '建议 (脚序与形态; 两面相同与不走电源已定 D2 / D6)'),
        ('规定·阶段', f'阶段一只接通逻辑用 UL_D[11:0] + UL_CHK + UL_CLK (契约第 4~17 対, 位置 {PH1_SPAN[0]}~{PH1_SPAN[1]}), 其余 6 対物理接通逻辑不用; 阶段二 20 対全用。验证板 V2 / V3 一律按 20 対画。',
         '用户 09-15', '已定 (用户 09-15)'),
    ]
    n = len(body)
    for k, (grp, txt, src, st) in enumerate(rules, 1):
        v = [f'规定{k}', grp, '', '', '', txt, '', '', '', '', '', src, st, '—']
        s = ['c', 'b'] + ['t'] * 10 + [st_style(st), 'c']
        body.append((v, s))
    return 'sheet2', '模组间接口契约', H, W, body


# ---------------------------------------------------------------- sheet3 验证板实现-SoC 侧 (D7 双面)
LVDS_STD_TXT = 'LVDS25 (ODDRx2 发端; bank VCCIO 改 2.5V 后契约电平直接满足, V3 无适配; .adc 只约束 P 端, TD Error-8066)'


def soc_cep_cells(ball):
    """CEP 球 → [排针脚, 串阻, 球位, 管脚名 · GCLK · ADC (· 借用对), 上电态]"""
    c = CEP_BY_BALL[ball]
    _bank, name, pair, _pl, alt = PM[ball]
    gc, adc = alt_split(alt)
    nm = name + (f' · {gc}' if gc else '') + (f' · 复用 {adc}' if adc else '')
    if pair in SPLIT33:
        nm += f' (劈开対 {pair} 的单端)'
    elif pair in B_SPARE:
        nm += f' (余量対 {pair} 的单端)'
    return [f"{c['conn']}.{c['pin']}", f"{c['res']} {c['rval']} 第{c['rch']}路", ball, nm, pwr_state(ball)]


def soc_ball_rel(ball):
    """球与现役约束 (uplink_pin.adc 探针 / 直驱屏 .adc) 的关系"""
    out = []
    if ball in CUR_SIG_BY_BALL:
        out.append(f'现役 uplink_pin.adc 为 {CUR_SIG_BY_BALL[ball]} (LVDS18)')
    if ball == SOC_POV_SPIN:
        out.append('现役 td_pov spin_sync_i (光电开关) 在此球 ⇒ 挪走')
    elif ball in PANEL_BALLS:
        out.append('现役直驱屏 .adc 用此球 (LVCMOS33; D7 后失效)')
    return '; '.join(out) or '新 (现役 .adc 未用)'


def soc_spin_who(impl):
    return next((f'面 {f} {sname(k)}_{pol}' for f in 'AB' for k in PAIR_ORDER for pol in 'PN' if impl['faces'][f]['pairs'][k][pol] == SOC_POV_SPIN), '未用')


def sheet_soc():
    impl = SOC_IMPL
    fa, fb = impl['faces']['A'], impl['faces']['B']
    H = ['契约位置', '信号名', 'P/N', '方向', '阶段',
         '面 A: FS03 CEP 脚', '面 A: 串阻', '面 A: DR1 球位', '面 A: 管脚名 · GCLK · ADC', '面 A: 上电态 (表 2-6)', '面 A: 与现役约束',
         '面 B: FS03 CEP 脚', '面 B: 串阻', '面 B: DR1 球位', '面 B: 管脚名 · GCLK · ADC', '面 B: 上电态 (表 2-6)', '面 B: 与现役约束',
         'DR1 IO 标准 / PULLTYPE (验证板, 两 bank 改 2.5V 后)', '约束与风险', '状态 (面 A)', '状态 (面 B)']
    W = [8, 16, 5, 9, 7, 8, 13, 7, 22, 14, 30, 8, 13, 7, 22, 14, 26, 30, 60, 22, 22]
    A_COLS, B_COLS = range(5, 11), range(11, 17)
    R = []

    def fill_of(st, keep=False):
        return 'r' if str(st).startswith('待定') else ('g' if keep else 'y')

    def sty(a_fill, b_fill, sa, sb, risk=False, gray=False):
        s = ['gray' if gray else 't'] * len(H)
        for i in (0, 2, 3, 4, 5, 7, 11, 13):
            s[i] = 'gray' if gray else 'c'
        if not gray:
            for i in A_COLS:
                s[i] = a_fill
            for i in B_COLS:
                s[i] = b_fill
        s[1] = 'gray' if gray else 'b'
        s[18] = 'risk' if risk else ('gray' if gray else 't')
        s[19], s[20] = st_style(sa), st_style(sb)
        return s

    st_head = '待定 (前提: 两 bank 改 2.5V 的改板方案)'
    v = ['—', '口径 (D7 双面)', '—', '—', '—', f"{fa['cep']} / bank{fa['bank']} · VCCIO {fa['vccio']} V · {fa['rework']}"] + [''] * 5 + \
        [f"{fb['cep']} / bank{fb['bank']} · VCCIO {fb['vccio']} V · {fb['rework']}"] + [''] * 5 + \
        ['—', f"验证期 FS03 同时驱 2 块屏 + 光电开关 (D7): 面 A / 面 B 各实现一份完全相同的契约 (D2), 逐行对应 sheet2 位置号; 本 sheet 分配全部为建议。数据来源: {impl.get('source', '—')}。"
              f"前提: {impl.get('rework', '—')}。", st_head, st_head]
    R.append((v, ['c', 'b', 'c', 'c', 'c'] + ['t'] * 12 + ['t', 'risk', st_style(st_head), st_style(st_head)]))

    for k in PAIR_ORDER:
        pa, pb = fa['pairs'][k], fb['pairs'][k]
        pra, prb = PM[pa['P']][2], PM[pb['P']][2]
        rel_a, kind_a = soc_pair_rel('A', k, pra)
        rel_a = pa.get('note') or rel_a
        rel_b = pb.get('note') or soc_pair_rel('B', k, prb)[0]
        for pol, pos in zip('PN', CPOS[k]):
            a, b = soc_cep_cells(pa[pol]), soc_cep_cells(pb[pol])
            ext = soc_ball_rel(pb[pol])
            rb = rel_b + ('' if ext.startswith('新') else '; ' + ext)
            risk = [f'{f}: {pair_pwr(PAIR_BALLS[p]["P"], PAIR_BALLS[p]["N"])[0]}' for f, p in (('A', pra), ('B', prb))]
            if '复用 ADC' in a[3]:
                risk.append('A: ADC 复用球作 LVDS25 —— DS1200 §4.2 ADC 复用注写明"LVDS 电平模式不涉及"; FS03 板上 BK33_ADCx 网络只到 R187~R198 排阻与 U1 球, 无 ADC 电路 (原理图 p06 / p17, 改板审查 v2 逐页扫)')
            if k == 'CLK':
                risk.append(f'转发时钟落 GCLK 対: A = {pra} ({PM[pa["P"]][4]}), B = {prb} ({PM[pb["P"]][4]}); 发端 ODDRx2 本身不依赖 GCLK 球; 两面都不用 CEP2.7/8 ({L12})')
            risk.append('两面都要 TD 试综合 (ODDRx2 合法 IOBE 球位 Error-8221; 两面 LVDS 余量 0) 并重跑两 bank 400 MHz pclk 时序')
            v = [pos, f'{sname(k)}_{pol}', pol, 'SoC → 桥', '阶段一' if k in PH1_KEYS else '阶段二'] + a + [rel_a] + b + [rb, LVDS_STD_TXT, '; '.join(risk),
                                                                                                    pa['status'], pb['status']]
            R.append((v, sty(fill_of(pa['status'], kind_a == 'keep'), fill_of(pb['status']), pa['status'], pb['status'])))

    for s in SE_ALL:
        name = s['name']
        grp = 'sideband' if name.startswith('SB_') else 'jtag'
        sa, sb_ = fa[grp][name], fb[grp][name]
        cells = []
        for se in (sa, sb_):
            if se.get('ball') in CEP_BY_BALL:
                c = soc_cep_cells(se['ball'])
                if se.get('shared_with'):
                    c[0] += ' (两面共用)'
                cells.append(c + [soc_ball_rel(se['ball'])])
            else:
                cells.append([se.get('via') or '—', '—', se.get('ball') or '—', '—', '—', '—'])

        def both(key):
            va, vb = sa.get(key), sb_.get(key)
            if va == vb:
                return va or '—'
            return f'A: {va or "—"}; B: {vb or "—"}'

        std = f"{both('iostd')}; PULLTYPE = {both('pulltype')}" + (f"; SoC 侧外部: {both('pull')}" if (sa.get('pull') or sb_.get('pull')) else '')
        risk = [f"上电 / 门控: {both('por')}"]
        if both('note') != '—':
            risk.append(both('note'))
        if s['dir'] == '桥 → SoC':
            risk.append('DR1 输入: 表 3-4 推荐 VI ≤ VCCIO+0.165 (2.5V bank = 2.665 V), 桥侧 2.5V 直驱标称满足, 两侧轨公差反向最坏须 ≤ ±3.3 % («e:dr1_vi»)')
        risk.append('FS03 板上串 33 Ω (对单端 = 源端匹配, 无害); 排阻 4 路一只, 换 0 Ω 会连带同只排阻的其他路 («d:res33»)')
        v = [s['pos'], name, '单端', s['dir'], '阶段一'] + cells[0] + cells[1] + [std, '; '.join(risk), sa['status'], sb_['status']]
        R.append((v, sty(fill_of(sa['status']), fill_of(sb_['status']), sa['status'], sb_['status'])))

    a_on_other = [n for g in ('sideband', 'jtag') for n, se in fa[g].items() if se.get('ball') in CEP_BY_BALL and CEP_BY_BALL[se['ball']]['conn'] != fa['cep']]
    b_on_other = [n for g in ('sideband', 'jtag') for n, se in fb[g].items() if se.get('ball') in CEP_BY_BALL and CEP_BY_BALL[se['ball']]['conn'] != fb['cep']]
    v = [', '.join(map(str, DIFF_GND[:3])) + ' … 61; ' + ', '.join(map(str, SB_GND)), f'GND ({len(DIFF_GND) + len(SB_GND)} 根)', '—', '—', '—',
         f"{fa['cep']}.2", '—', '—', '—', '—', '—', f"{fb['cep']}.2", '—', '—', '—', '—', '—', '—',
         f'两个 CEP 同时插 V3 (面 A 单端 {len(a_on_other)} 根在 {fb["cep"]}: {" / ".join(a_on_other)}; 面 B 单端 {len(b_on_other)} 根在 {fa["cep"]}: {" / ".join(b_on_other)}); '
         '每个 50 脚只有 pin2 一根地 ⇒ 两个排针都做 G-P-N-G 地排, 地条 ≥3 点接回 FS03 真地 (sheet5 «e:fs03_gnd»)', '建议', '建议']
    R.append((v, sty('gray', 'gray', '建议', '建议', gray=True)))
    st_vcc = '已定 (不接, D6)'
    v = ['—', 'VCC_CEP (pin1)', '—', '—', '—', f"{fa['cep']}.1", '—', '—', '—', '—', '—', f"{fb['cep']}.1", '—', '—', '—', '—', '—', '—',
         '不接 (契约不走电源, D6)。pin1 出厂经磁珠 L19 / L18 接 VCC_3V3 (L17 / L16 NC); PANEL_BRINGUP_CHECKLIST §4.2 #3 "5V 灌入改法" (贴 L16 / L17、拆 L18 / L19) '
         '若做过则两个 pin1 都是 VIN_5V0, 未记录 ⇒ V3 不接、任何与 CEP bank 信号相关的上拉 / 供电不以它为参考 («d:cep_pin1»)', st_vcc, st_vcc]
    R.append((v, sty('gray', 'gray', st_vcc, st_vcc, gray=True)))

    ss = impl['spin_sync']
    if ss['ball'] in CEP_BY_BALL:
        a = soc_cep_cells(ss['ball'])
    else:
        a = [ss.get('via') or '—', '无串阻 (直连球)', ss['ball'], f"{ss.get('pin')} (bank{ss.get('bank')})", pwr_state(ss['ball']) + ' (bank 不在表 2-6)']
    rel = (f'改动: 现役 spin_sync_i = {SOC_POV_SPIN} (IO_L24P_11, CEP2.23, LVCMOS33, 无 PULLTYPE; td_pov fpga_pin.adc:35) → {ss["ball"]}; '
           f'{SOC_POV_SPIN} 在本版是 {soc_spin_who(impl)}, 且 bank11 改 2.5V 后 3.3V 传感器电平超 DR1 输入上限')
    v = ['—', 'SPIN_SYNC 光电开关 (转子索引; 全系统 1 根, 不走模组间接口)', '单端', '传感器 → SoC', '阶段一'] + a + [rel] + ['— (全系统 1 根, 见面 A 列)'] + ['—'] * 5 + \
        [f"{ss.get('iostd')}; PULLTYPE = {ss.get('pulltype')}; 板上: {ss.get('pull')}", f"上电: {ss.get('por')}; {ss.get('note')}", ss['status'], '—']
    R.append((v, sty(fill_of(ss['status']), 't', ss['status'], '—')))

    for r in impl.get('reserved') or []:
        bs = r['balls']
        cells = [soc_cep_cells(b) for b in bs]
        side = [' / '.join(x[i] for x in cells) for i in range(5)] + ['; '.join(dict.fromkeys(soc_ball_rel(b) for b in bs))]
        blank = ['—'] * 6
        on_a = CEP_BY_BALL[bs[0]]['conn'] == fa['cep']
        v = ['—', f'(预留) {PM[bs[0]][2]}', 'P/N', '—', '—'] + (side if on_a else blank) + (blank if on_a else side) + \
            ['(未分配)', r['use'], r['status'] if on_a else '—', '—' if on_a else r['status']]
        R.append((v, sty('r' if on_a else 't', 't' if on_a else 'r', v[19], v[20], risk=True)))

    for item, txt, st in impl.get('plan') or []:
        v = ['规划', item] + [''] * 16 + [txt, st, st]
        R.append((v, ['c', 'b'] + ['t'] * 16 + ['t', st_style(st), st_style(st)]))
    return 'sheet3', '验证板实现-SoC侧_DR1V90_FS03', H, W, R


# ---------------------------------------------------------------- sheet4 验证板实现-LED 侧
# 官方 ACG525-CB-V2 底板 P5 JTAG 座 (10 脚 2.54 简易牛角座) 脚位 —— 出自本会话并行流程 research:gw5a (IPC-356 网表 + V1 底板 PDF p2 三方一致), 本表未独立复核
JTAG_HDR = {'TCK': 'pin1', 'TDO': 'pin3', 'TMS': 'pin5', 'TDI': 'pin9'}
JTAG_HDR_DESC = '1 TCK / 2 GND / 3 TDO / 4 VCC3P3 / 5 TMS / 9 TDI / 10 GND (并行流程读图, 本表未复核)'
assert set(JTAG_HDR) == {j['tap'] for j in JTAG}
SSPI_RE = re.compile(r'SSPI|SSI\d|(^|/)S[IO](/|$)|CLKHOLD')


def sheet_led():
    H = ['契约位置', '信号名', 'P/N', '方向', '阶段', 'V2 底板 (待设计)', '核心板连接器.脚号', '核心网名', 'GW5A 管脚', '球位', 'bank',
         'VCCIO 组 (电压)', '分区', 'IO 标准 / 端接', '配置复用 · GCLK/PLL (UG985 口径)', '相邻非上行脚 (同排 ±2 / 对排)', '约束与风险', '状态']
    W = [8, 14, 5, 9, 7, 26, 10, 11, 9, 6, 5, 26, 8, 30, 26, 36, 50, 18]
    GW_COLS = range(5, 15)
    R = []

    def sty(fill, st, risk=False, gray=False):
        s = ['gray' if gray else 't'] * len(H)
        for i in (0, 2, 3, 4, 6, 9, 10, 12):
            s[i] = 'gray' if gray else 'c'
        if not gray:
            for i in GW_COLS:
                if i not in (6, 9, 10, 12):
                    s[i] = fill
        s[1] = 'gray' if gray else 'b'
        s[16] = 'risk' if risk else ('gray' if gray else 't')
        s[17] = st_style(st)
        return s

    for k in PAIR_ORDER:
        base = GW_MAP[k]
        for pol, pos in zip('PN', CPOS[k]):
            c = CORE_BY_NET[f'{base}_{pol}']
            gclk, cfg = gw_cfg_split(ug_cfg(c))
            stdt = 'LVDS25 输入 (TLVDS_IBUF), DIFF_RESISTOR=ON 片内 100 Ω, BANK_VCCIO=3.3'
            risk = []
            if k == 'CLK':
                stdt += '; 转发时钟入口'
                risk.append('HCLK 直驱 IDES8.FCLK 或经 BPLL 再生、以及能否覆盖 bank4 + bank5 两个 bank, 均未综合 («d:gw_hclk»); 备选 B4_B35 (GCLKT_8, 无配置复用)')
            elif gclk:
                risk.append(f'该脚另有 {gclk} (作数据无妨)')
            if cfg:
                risk.append(f'配置复用 {cfg}: 核心板 MSPI 启动时不参与配置, 综合时需在 Dual-Purpose Pin 放开 («d:gw_cfgpins»)')
                if SSPI_RE.search(cfg):
                    risk.append('MSPI 失败回落 SSPI 时本脚被采样 («e:pwr_gw»), 所以只放阶段二 lane' if k not in PH1_KEYS else 'MSPI 失败回落 SSPI 时本脚被采样')
            if k not in PH1_KEYS:
                risk.append('阶段二 lane: 阶段一物理接通、逻辑不例化')
            nb = gw_neigh(c['conn'], c['pin'])
            if any('隔离対' in x for x in nb):
                risk.append('紧邻 VCCIO23 的 2.5V 对 (原下行候选) ⇒ 该对已改作隔离、不作下行 (sheet8)')
            if any('下行候选' in x for x in nb):
                risk.append('紧邻下行 2.5V ELVDS 候选, 画 V2 时拉开间距或加地')
            if any('边带 SB_' in x for x in nb):
                risk.append('紧邻 2.5V 边带 ' + ' / '.join(x.split('边带 ')[1].rstrip(')') for x in nb if '边带 SB_' in x)
                            + ': 准静态单端, 不构成干扰源; V2 上该单端线与上行対保持间距, 边带侧 RTL 同步去毛刺')
            v = [pos, f'{sname(k)}_{pol}', pol, 'SoC → 桥', '阶段一' if k in PH1_KEYS else '阶段二',
                 f"待设计: 契约位置 {pos} → B2B {c['conn']}.{c['pin']}; 100 Ω 差分, 对内等长; {PN_NOTE[c['conn']]} (见本表 规划·P/N 脚序)", f"{c['conn']}.{c['pin']}", c['net'], c['fpga'], c['ball'],
                 str(c['bank']), f"{VG[c['bank']]} ({VG_NOTE[VG[c['bank']]]})", part_of(c['fpga']), stdt, cfg_cell(c, cfg, gclk),
                 '; '.join(nb) or '无 (两侧为上行或地)', '; '.join(risk) or '—', '建议 (未经 Gowin 工具试综合)']
            R.append((v, sty('y', v[17])))
    for s in SB:
        net = GW_SB[s['name']]
        c = CORE_BY_NET[net]
        grp = VG[c['bank']]
        gclk, cfg = gw_cfg_split(ug_cfg(c))
        if base_of(net) in FULL:
            kind = f"完整対 {base_of(net)} 的 {c['pol']} 端 (对内另一端 {c['mate']} 也作边带), 只作单端用"
        else:
            kind = '半対单脚 (' + (f"对偶球 {c['mate']} 未引出" if c['mate'] else 'UG324 封装无对偶脚') + ')'
        risk = [kind + '; 只放准静态 / 低速单端']
        if grp == 'VCCIO23':
            risk.append('VCCIO23 由 V2 底板设 2.5V (D5)。V2 若把 VCCIO23 跳到 3.3V 跑官方自测位流: 该脚变 LVCMOS33 输入 (SoC 2.5V VOH ≥2.1 V 对 VIH 2.0 V 仅余 0.1 V), '
                        '且自测位流可能把它当输出驱 3.3V ⇒ VCCIO23 = 3.3V 或跑非本接口位流时不得接 SoC 模组 («d:v2_vccio23»)')
        else:
            risk.append('VCCIO67 由核心板固定 2.5V (VCC2P5 经 FB3), 不随 V2 的 VCCIO23 选择变 ⇒ 桥 → SoC 输出放这里, 不会有 3.3V 进 DR1 2.5V bank (DS1200 表 3-1 输入上限 VCCIO+0.3)')
        if s['name'] == 'SB_RSTN':
            risk.append('V2 底板下拉 2.2 kΩ 必贴 (D4 桥侧外部下拉; DR1 配置期弱上拉 ≤153 µA @2.5V × 2.2 kΩ ≤0.34 V < VIL 0.7 V, sheet5 «e:sideband_level»); '
                        'P1.32 同排紧邻上行 UL_D[5]_P (P1.30): 本线准静态, 不构成干扰源; 桥侧 RTL 两级同步 + 去毛刺 (建议)')
        if s['name'] == 'SB_UART_S2B':
            risk.append('P1.34 同排两侧为 P1.32 (SB_RSTN) 与 P1.36 (GND), 对排 P1.33 = 隔离対 B3_B65_P (悬空): 不直接挨上行; 与 SB_RSTN 相邻 ⇒ SB_RSTN 侧去毛刺, RX 过采样滤波')
        if s['name'] == 'SB_ALIGNED':
            risk.append('GW5A 配置前 / 配置中本脚弱上拉 (UG304 §3.3; 25K Medium ≤150 µA) ⇒ 线上必须有外部下拉 2.2 kΩ (D4 放 SoC 侧 = V3 贴在 8.2 kΩ 串阻的连接器侧; V2 留 0402 焊盘默认不贴, 两处只贴一处), 否则桥片未配置时 SoC 可能读成已对齐; '
                        'V3 上桥片未配置时 DR1 焊盘 0.643 V, 余 57 mV ⇒ SB_RSTN 为低时 V2 侧 (桥片与 flash 镜像) 不驱高')
        if s['name'] in ('SB_ALIGNED', 'SB_UART_B2S'):
            risk.append('P2.32 / P2.34 相邻, 周围为下行 2.5V 候选 (同排 P2.30 B7_T21_N、P2.36 B6_L5_CK_P, 对排 P2.31 / P2.33 B6_L3_CK): 下行 300 Mbps ELVDS 边沿会串到这两根 ⇒ '
                        'GW5A 输出限摆率, SoC 侧同步 / 过采样; 桥片在 SB_RSTN 为低期间不驱高 (建议, 验证期按强制执行: 桥片 RTL 与 flash 镜像都要满足, «e:powerup» / 本表 规划·核心板 flash)')
        if cfg:
            risk.append(f'配置复用 {cfg}')
        pull = {'SB_RSTN': '; V2 下拉 2.2 kΩ (必贴, D4)', 'SB_ALIGNED': '; 下拉 2.2 kΩ 贴 SoC 侧 V3 (D4), V2 留 0402 下拉焊盘默认不贴'}.get(s['name'], '')
        v = [s['pos'], s['name'], '单端', s['dir'], '阶段一', f"待设计: 契约位置 {s['pos']} → B2B {c['conn']}.{c['pin']}{pull}",
             f"{c['conn']}.{c['pin']}", net, c['fpga'], c['ball'], str(c['bank']), f"{grp} ({VG_NOTE[grp]})", part_of(c['fpga']),
             'LVCMOS25 (2.5V, D5)', cfg_cell(c, cfg, gclk),
             '; '.join(gw_neigh(c['conn'], c['pin'])) or '—', '; '.join(risk), '建议 (脚位未上板; 2.5V 组与下拉为用户 D4 / D5 所定)']
        R.append((v, sty('y', v[17])))
    for j in JTAG:
        cp = CORE_BY_PIN[('P1', j['core_pin'])]
        ch = 'CH' + str('TCK TMS TDI TDO'.split().index(j['tap']) + 1)
        if j['tap'] != 'TDO':
            path = (f"待设计: 契约位置 {j['pos']} → 电平转换 {ch} (A 口入 2.5V → B 口出 3.3V) → 0Ω 选择电阻 (默认贴 = SoC 驱动; 用下载器时拆) → B2B P1.{j['core_pin']}; "
                    f"下载器插座 {JTAG_HDR[j['tap']]} 接 0Ω 的 FPGA 侧")
        else:
            path = (f"待设计: B2B P1.{j['core_pin']} → 电平转换 {ch} (B 口入 3.3V → A 口出 2.5V) → 契约位置 {j['pos']}; 下载器插座 {JTAG_HDR[j['tap']]} 并听 (TDO 不需选择)")
        risk = ['契约面 2.5V ↔ GW5A bank10 3.3V (核心板 p3: VCCIO10 = VCCX = VCC3P3): 不转换时 TDO 3.3V 进 DR1 2.5V bank 超 DS1200 表 3-1 输入上限 VCCIO+0.3 = 2.8 V, '
                'SoC VOH ≥2.1 V 对 GW5A LVCMOS33 VIH 2.0 V 仅余 0.1 V ⇒ 必须转换 (D5; 转换器要求 sheet5 «e:jtag_shift»)',
                j['pull'],
                '桥片位流 Dual-Purpose Pin 不得勾 JTAG PORT (UG714 表 3-6), 否则配置后 JTAG 变 GPIO, SoC 无法再读 IDCODE / 重载 (D3)']
        if j['tap'] == 'TCK':
            risk.append(JTAG_TCK_RATE)
        risk.append('对排 P1.93 / 95 / 97 / 99 = B2_R7 / B2_R9 (VCCIO23 下行候选): 若作 300 Mbps 下行, 边沿会串到 JTAG (TCK 最敏感, 毛刺 = 多打 TAP 时钟) '
                    '⇒ 建议这 2 対不作高速下行或 V2 走线拉开 (sheet8 核算 A 未扣, 若扣则余量减 2)')
        v = [j['pos'], j['name'], '单端', j['dir'], '阶段一', path, f"P1.{j['core_pin']}", cp['alias'], f"{j['fpga']} / {j['tap']}", j['ball'], '10',
             'VCCIO10 (= VCCX = VCC3P3, 核心板原理图 p3; 3.3V 固定)', 'Right (bank10 专用)', 'LVCMOS33 (bank10); 契约面 2.5V 经 V2 转换', f"JTAG 专用 ({j['tap']})",
             '; '.join(gw_neigh('P1', j['core_pin'])) or '—', '; '.join(risk), '建议 (V2 电路未设计; 四脚脚位为核心板事实)']
        R.append((v, sty('y', v[17])))
    for base in GW_SPARE:
        for pol in 'PN':
            c = CORE_BY_NET[f'{base}_{pol}']
            gclk, cfg = gw_cfg_split(ug_cfg(c))
            note = 'VCCIO45 余下对, 不接契约'
            if 'SO' in cfg.split('/'):
                note += '; 本脚 = SSPI SO, MSPI 失败回落 SSPI 时可能为输出 ⇒ 悬空, 勿接地'
            else:
                note += '; 底板可留 0 Ω 到地 (默认不贴)'
            v = ['—', f'(空置) {c["net"]}', pol, '—', '—', '空置', f"{c['conn']}.{c['pin']}", c['net'], c['fpga'], c['ball'], str(c['bank']),
                 f"VCCIO45 ({VG_NOTE['VCCIO45']})", part_of(c['fpga']), '—', cfg_cell(c, cfg, gclk),
                 '; '.join(gw_neigh(c['conn'], c['pin'])) or '—', note, '建议 (空置)']
            R.append((v, sty('t', v[17])))
    v = ['G', f'GND (契约 {len(DIFF_GND) + len(SB_GND)} 根)', '—', '—', '—', '就近打孔接底板地平面', 'P1.11~14/35/36/57/58/79/80; P2.21/22/43/44/65/66/87/88/89/91', '—', '—', '—', '—', '—', '—', '—', '—', '—',
         '核心板 B2B 200 脚只有 20 根地, 上行 20 対之间无地、不能再隔对使用 (sheet5 «e:b2b»)', '已定 (核心板事实)']
    R.append((v, sty('gray', v[17], gray=True)))
    ul_by_ball = {CORE_BY_NET[f'{b}_{p}']['ball']: f'{sname(k)}_{p}' for k, b in GW_MAP.items() for p in 'PN'}
    se_by_ball = {CORE_BY_NET[n]['ball']: s for s, n in GW_SB.items()}
    loop_tx = [('U13', 'V13'), ('R11', 'T11'), ('U16', 'V16')]          # wiring_n13_l800_verA / verB: lane8~10 TX (bank4)
    loop_rx = ('U17', 'U18')                                             # lane10 RX (bank3), DIFF_RESISTOR=ON
    assert [ul_by_ball[a][:-2] for a, _b in loop_tx] == ['UL_D[3]', 'UL_D[2]', 'UL_D[5]'] and all(ul_by_ball[b][:-2] == ul_by_ball[a][:-2] for a, b in loop_tx)
    assert [se_by_ball[x] for x in loop_rx] == ['SB_UART_S2B', 'SB_RSTN']
    flash_txt = ('ACG525-CORE-V2 板载 GD25Q128E, MSPI 上电自动加载; openFPGALoader 每次 JTAG 写 GW5A SRAM 前先发 RELOAD 让芯片从 flash 重配, 再擦写 SRAM '
                 '(gowin.cpp:267~271 / 384~393, 并行流程 wf_3cee62db review #1) ⇒ flash 里的镜像在 SoC 读 IDCODE 之前、以及每次加载时都会运行, D3 "flash 焊盘 DNP" 在验证板上不成立。'
                 '包内环回自测镜像 n13_l800 (verA / verB 接线相同) 把 bank4 ' + '、'.join(f'{a} / {b}' for a, b in loop_tx) + ' 设为 TLVDS 输出 —— 正是本表 V2 上接收 DR1 的 '
                 + ' / '.join(ul_by_ball[a][:-2] for a, _b in loop_tx) + ', 两端对驱; 又把 bank3 ' + ' / '.join(loop_rx) + ' 设为 LVDS 接收并开 DIFF_RESISTOR = ON —— 本表 '
                 + ' / '.join(se_by_ball[x] for x in loop_rx) + ', 100 Ω 跨在两路 DR1 LVCMOS25 输出之间, SB_RSTN 电平不定、DR1 输出电流超驱动档; 该镜像按 BANK_VCCIO = 3.3 约束 (verA run.cst), 与 V2 VCCIO23 = 2.5V 也不符。'
                 'n4_l800 只用 bank2 (V2 上为 2.5V 下行候选, 同为 3.3V 约束); 出厂镜像脚位未查。⇒ 前提: 核心板插上 V2 并接 V3 / FS03 之前, flash 必须擦除, 或烧入与 V2 脚位一致的安全镜像 '
                 '(上行球全输入且不开端接; SB_RSTN / SB_UART_S2B 为输入; SB_ALIGNED / SB_UART_B2S 受 SB_RSTN 门控, 为低时输出低或高阻); 自测镜像只在官方 CB-V2 上用; '
                 '擦 flash 会丢出厂镜像, 须用户确认 (并行流程 wf_3cee62db doc R28)。')
    summary = [
        ('规划·上行', f'上行 20 対全放 VCCIO45 (bank4 / bank5 = Bottom 分区, 3.3V 固定): 22 完整対用 20, 余 2 (B5_B8 SO/D05·D06、B5_B12 SSPI_WPN/D07·RDWR_B, 空置); '
                    f'阶段一 14 対 = bank4 {GW_PH1_BANK[4]} 対 (P1 7 対 + P2 4 対) + bank5 {GW_PH1_BANK[5]} 対; 阶段二再加 bank5 6 対 (含 SSPI / CPU 并口复用対)。'
                    f'上行対里带配置复用的 {len(UL_CFG)} 対: {", ".join(UL_CFG)}。核心板自己占用的 flash / MODE / READY / DONE / RECONFIG_N / 50M 球都不在连接器上, 不撞脚。', '建议'),
        ('规划·时钟', '转发时钟 B4_B33 (P1.21 P = U10 GCLKT_9A / BPLL_T_IN1; P1.19 N = V10 GCLKC_9A / EMCCLK / BPLL_C_IN1 (BPLL_C_IN1 为 UG985 所列, IDE json 无)), 兼有 GCLK 与 Bottom PLL 输入; 备选 B4_B35 (P1.18/16, GCLKT_8, 无复用) 或 B5_B26 (P2.84/86, GCLKT_9B)。'
                    'EMCCLK 只在主模式选外部配置时钟时用, 核心板默认内部振荡 (UG714 EMCCLK 说明)。', '建议'),
        ('规划·P/N 脚序', f'核心板连接器对内脚序两排相反 (73 个完整対全核): P1 每対 N 在小脚号、P 在大脚号 (如 B4_B35_N P1.16 / P P1.18, B4_B33_N P1.19 / P P1.21); '
                         f'P2 每対 P 在小脚号 (如 B5_B20_P P2.79 / N P2.81, B4_B31_P P2.90 / N P2.92)。上行在 P1 {len(UL_P1)} 対 ({"、".join(sname(k) for k in UL_P1)}), 在 P2 {20 - len(UL_P1)} 対。'
                         '契约只规定位置号 P 前 N 后; V2 布局时 (两个连接器在核心板上的朝向以 ACG525-CORE_NEW260310 封装为准) 逐对核对走线是否要 P/N 交叉。要交叉的对两种做法: '
                         '① 逐对换层交叉, P/N 仍对应 GW5A P/N 球; ② V2 上 P/N 对调接 (契约面不变, 属 LED 模组内部实现): 数据 lane 在 RTL 于 IDES8 输出、lane 对齐逻辑之前逐位取反 '
                         '(不取反则训练码 0x35 读成 0xCA 及其移位, 该 lane 永不对齐); UL_CLK 优先用 ①, 若对调 = 转发时钟反相 180° (400 MHz 下 1.25 ns = 800 Mbps 的 1 UI), '
                         '需确认 IODELAY 训练 / bitslip 能吸收。哪几对取反写进 .cst 与 RTL 参数, 随 «d:gw_hclk» 一次综合定。', '建议'),
        ('规划·边带', f'边带 4 根全部放 2.5V 组 (D5, LVCMOS25): 桥 → SoC 输出 SB_ALIGNED = P2.32 (H5, B7_T5_N)、SB_UART_B2S = P2.34 (J1, B6_L7_N), 均为 VCCIO67 半対 (核心板固定 2.5V); '
                    f'SoC → 桥 输入 SB_RSTN = P1.32 (U18, B3_B71_N)、SB_UART_S2B = P1.34 (U17, B3_B71_P), 为 VCCIO23 原隔离対 B3_B71 (V2 设 2.5V)。'
                    f'下拉: SB_RSTN 在 V2 贴 2.2 kΩ (D4); SB_ALIGNED 的 2.2 kΩ 在 SoC 侧 (D4), V2 只留焊盘。不占上行 / 下行対, 只用掉 2 个 2.5V 半対 (下行单端候选 4 → {len(DOWN_HALF)})。'
                    f'VCCIO45 的 4 个半対 ({", ".join(V45_HALF_FREE)}) 改为空置 (3.3V 组, 不能放 2.5V 边带)。', '建议'),
        ('规划·JTAG', f'契约 JTAG 4 根 (2.5V) → V2 电平转换 → 核心板 P1.100 TCK / 98 TMS / 96 TDI / 94 TDO → GW5A bank10 A17 / B18 / D15 / D16 (3.3V 固定)。'
                     '转换器: 固定方向、双电源、两侧带 Ioff (如 SN74LVC1T45 ×4 或 LVC2T45 ×2 类, 型号待定), A 口 VCCA = V2 本地 2.5V (与 VCCIO23 同轨), B 口 VCCB = V2 3.3V; '
                     'TCK / TMS / TDI 为 A → B, TDO 为 B → A (DIR 脚硬接)。选择: TCK / TMS / TDI 三路在转换器 B 口与 FPGA 之间串 0Ω (默认贴 = SoC 驱动), '
                     f'下载器插座 (按官方 CB-V2 P5: {JTAG_HDR_DESC}) 接 0Ω 的 FPGA 侧, 用下载器时拆 0Ω (或换 2×3 跳线); TDO 两路并听不需选择。'
                     '用下载器时 SoC 读不到 IDCODE ⇒ 按 D6 SoC 不驱 LVDS, 台架需调试旁路 («d:jtag_shift_part»)。静止电平 TCK 为低、TMS / TDI 为高: A 口 TCK 2.2 kΩ 下拉、TMS / TDI 各 22 kΩ 上拉到 V2 本地 2.5 V; '
                     'B 口 TCK 4.7 kΩ 下拉、TDO 10 kΩ 下拉 (必须) (sheet5 «e:jtag_shift»)。'
                     '桥片 flash 焊盘保留 DNP 是目标板要求 (D3); 验证板核心板自带 GD25Q128E 且 MSPI 上电自启, 其镜像在 SoC 读 IDCODE 前与每次 JTAG 加载时都会运行, 见 规划·核心板 flash。', '建议'),
        ('规划·核心板 flash', flash_txt, '建议 (验证期前提, 接入前必须执行; 擦除还是换安全镜像待定 «d:core_flash»)'),
        ('规划·下行', f'下行放 VCCIO23 (V2 设 2.5V, bank2 Right + bank3 Bottom) + VCCIO67 (2.5V, bank6 Left + bank7 Top): 26 + 21 = 47 対, 扣隔离 {"/".join(GUARD_ONLY)} 与边带 {"/".join(SB_PAIRS)} '
                    f'= {len(DOWN_PAIRS)} 対 + {len(DOWN_HALF)} 单端 ({", ".join(DOWN_HALF)}); 核算 A 需 {NA[0]} 対, 余 {NA[1]} (v2 余 {NA_V2[1]}); '
                    f'剔除 Bank2/Bank6 后差分可用 {len(DOWN_TB)} 対, 缺 {-NC[1]} (sheet8)。', '待定 (B2/B6 未证)'),
    ]
    for item, txt, st in summary:
        v = ['规划', item] + [''] * 14 + [txt, st]
        R.append((v, ['c', 'b'] + ['t'] * 14 + ['t', st_style(st)]))
    return 'sheet4', '验证板实现-LED侧_GW5A_ACG525', H, W, R


# ---------------------------------------------------------------- sheet5 电气与机械约束
def sheet_constraints():
    H = ['编号', '类别', '约束项', '数值与判据 (原文)', '对本接口的结论 / 做法', '出处', '状态']
    W = [6, 11, 18, 56, 70, 40, 16]
    a_up, a_free = len(A_UP), ', '.join(A_FREE)
    C = {
        'lvds25': ('电气·契约电平', '契约差分电平 LVDS25',
                   'DS1200 表 3-14 LVDS25 (VCCIO = 2.5): VOD 200/350/400 mV, VOCM 0.9/1.25/1.4 V; GW5A-25 表 3-26: VICM 0.3~2.35 V, VID 门限 ±100 mV',
                   '契约 = LVDS25 (VOCM 典型 1.25 V), 100 Ω ±10 % 差分, G-S-S-G, 接收端 (桥) 100 Ω 端接, 直流耦合。契约不迁就 FS03。桥片候选的收端共模窗要覆盖 0.9~1.4 V (GW5A 0.3~2.35 V 覆盖; 其他候选待查)。',
                   '用户 09-15; DS1200 表 3-14; DS1103 表 3-26', '已定 (用户 09-15)'),
        'fs03_lvds18': ('电气·验证板发端', 'FS03 原厂状态只能 LVDS18 (D7 改板后失效)',
                        'FS03 电源只有 3.3 / 1.8 / 1.35 V (手册 §18); DR1 LVDS18 (VCCIO = 1.8): VOCM 0.3/0.6/0.8 V, VOD 200/350/500 mV (DS1200 表 3-14)',
                        'FS03 原样只能出 LVDS18, 共模 0.3~0.8 V 低于契约 0.9~1.4 V。D7 已定: 两个 CEP bank 改板把 VCCIO 改 2.5V 出真 LVDS25 (改板方案 README v2.2, 未实施, «e:adapt»)。'
                        '另据用户转述 DS1200 V1.0 §2.7 注 1 / 2 与表 3-21 / 3-22: 3.3V bank 只有 LVDS33_E (300 Mbps), 差分输入只支持 LVDS25 / 18 ⇒ 不能靠 3.3V bank 出契约电平。',
                        'FS03 手册 §18; DS1200 表 3-14; DS1103 表 3-26', '已定 (事实)'),
        'adapt': ('电气·适配方案', 'LVDS18 → 契约 LVDS25: FS03 两个 CEP bank 改板到 2.5V (D7)',
                  'DS1200: 推荐上电顺序 VCCINT → VCCAUX(VCCPLL) → VCCIO, 下电相反; FS03 手册 §18: VCCINT → VCCAUX 1.8V → 3.3V & 1.8V & 1.35V; J1 (ADJ_BANK11) / J2 (ADJ_BANK33) 只有 1 = 3V3 / 3 = 1V8 两档。'
                  '并行流程 read:B 读图: VCC_1V8 轨 (U8 ES5030) 上挂 QSPI flash GD25LB256E、USB3320 等绝对最大 2.5V 器件, 不能整轨改 2.5V; 板上无空贴稳压位、无 2.5V 网络',
                  '按 D7 (已定) 两个 CEP bank 都改 VCCIO 2.5V, DR1 出真 LVDS25 (VOCM 0.9~1.4 V), 同 bank 的边带 / JTAG 为 LVCMOS25, 与契约一致。改板方案见 dr1v90/fs03_mod/README.md v2.2 (未实施), '
                  'V3 设计输入见 dr1v90/fs03_mod/V3_design_inputs.md —— 1.8V / 3.3V 公用轨不能改分压、板上无 2.5V 轨与空贴位 ⇒ '
                  'J1 / J2 各一路: 肖特基 + TPS73625DBVR + 0.2 Ω 采样 + 10 µF + 1 kΩ 泄放; 插座小板 (方案 P) 或引线直焊 (方案 S); 每 bank 设计 200 mA, > 300 mA 停 (V3 G2; 方案 D 杜邦胶壳只限阶段 1~4; 地线双线双端子)。'
                  '上下电: VCCIO 晚于 VCCAUX 上电 (LDO 取自 VCC_3V3, VCC_3V3 由 AUX_PG 使能, 由电路结构保证); 下电时 VCCIO 比 VCCAUX 晚掉几 ms 到十几 ms (输入肖特基挡住回流, 岛经 1 kΩ 泄放, τ ≈ 12 ms), '
                  'DS1200 PDF p44 §3.1.5 允许: 不按推荐顺序下电只会在 I/O 上产生脉冲, 不影响器件寿命; LED 模组先断电, 此时 CEP 上没有带电的接收端 (V3 G1)。'
                  '旧屏链 CEP2 排线下线, 光电挪 K18 (拆 K2 / C245)。硬规则: SW1 拨 JTAG 并拔 TF 卡; 物理拆除 CEP1 上 CB-V2 JTAG 飞线 (CEP1.4 / 5 / 15 / 18), CEP 全空才上电; '
                  '加载前闸门: V3 插上前量 CEP 脚预插测试线, V3 插上后读 J_TP11 / SENSE33 / TP_TDO_A (判 DR1 VCCIO 闸门窗 2.40~2.60 V), 不量模块输出; FS03 先上电、最后断电 («e:powerup»); 不从 CEP pin1 取任何东西; J2 空着不上电 (VCCIO_33 必须供电); '
                  '焊接或插上后先做断电阻值检查 (v2.1 复核)。'
                  '审查 v2 = 0 critical / 3 major / 7 minor, v2.1 已给落实做法: M1 带电读数改预插测试线; M2 V3 闸门测点 J_TP11 (CEP2.7 / CEP2.8 各串 10 kΩ) + SENSE33 (10 kΩ) + TP_TDO_A (47 kΩ 隔离) (sheet3 规划·V3); '
                  'M3 插座小板 / 地线双线 + V3 对端 → DR1 串阻且门控与被门控同 bank (sheet3 规划·单端 / 规划·V3)。'
                  'DS1200 表 3-4: VCCIO @2.5V 2.375~2.625 V、TVCCIO 0.2~100 ms; 表 3-5: VCCIO_33 必须供电。上板用中心抽头量 VOCM ≈1.25 V。不用 AC 耦合 (8-bit 直传, 非直流平衡码)。',
                  '用户 09-15 D7; DS1200 表 3-4 / 3-5 / 3-8 / 3-14 / §3.1.5; FS03 手册 §18; FS03 原理图 P01 / P08; dr1v90/fs03_mod/README.md v2.2 §5.4~§5.7 / V3_design_inputs.md G1 / G2; 并行流程 wf_91b9a995 read:B / design / review', '已定 (D7 改 2.5V; 改板方案 v2.2 未实施)'),
        'swing33': ('电气·摆幅 / 串阻', '差分摆幅 vs 门限; FS03 33Ω 串阻',
                    'DR1 LVDS25 VOD 最小 200 mV (DS1200 表 3-14) vs GW5A VID 门限 ±100 mV; FS03 原理图 P17: J11 经 R187~R198、J12 经 R199~R210 到 FPGA, 每只 4 路; 物料表 R187~R210 = 33R RA4_0402 ×24 ⇒ 96 根 CEP 信号每根串 33Ω',
                    '最小 VOD 对门限余 2 倍, 再扣 33Ω 串阻、FPC 插损 (200 mm 估 0.5~1.9 dB)、排针与 B2B。33Ω 影响 (定性, 未测): ① 源端阻抗台阶 → 反射; ② 与排阻 / 排针寄生电容成 RC 低通; '
                    '③ 按 VOD 350 mV / 100 Ω 推的环路电流约 3.5 mA, 每臂压降约 0.12 V (估); 改 2.5V 后改板流程按恒流源驱动估 FPGA 焊盘处 VOH ≈1.54 V, 擦着表 3-14 VOH ≤1.5 V (估算, 未测)。D7 双面: 两个排针的排阻都在上行路径上, 且排阻 4 路一只、与单端混用。与记忆库"排阻为编造"冲突。是否换 0Ω 待定 («d:res33»)。',
                    'DS1200 表 3-14; DS1103 表 3-26; FS03 原理图 P17 + 物料表; README_1g6 §接插件 (估); 冲突方 project_pov3d_fs03_cep_ground_and_third_row §5', '待定'),
        'odt': ('电气·端接', 'GW5A 片内 100 Ω 条件与分区',
                'DS1103 表 3-26 (25/60): RODT 100 Ω @Vccx = 3.3V, 未注分区 (只有 138K 的表注写 Left/Right ODT 140 Ω); 表 3-6: VCCX 2.375~3.465 V; '
                'UG304-1.3 §3.3.2: "Arora V 器件在所有分区支持片内可编程的 100 欧姆输入差分匹配电阻"',
                '核心板 VCCX = VCC3P3 (原理图 p3), 由 V2 底板经 P1.1~4 供 ⇒ 满足。上行放 bank4/5 (IOB = Bottom): 片内 100 Ω 不论"所有分区" (UG304-1.3) 还是"仅 Top/Bottom" (任务口径引 UG304-1.3.7, 本包无该版) 都成立; '
                '收端开 DIFF_RESISTOR=ON, 板上不再外加 100 Ω, 发端不加串阻。分区口径冲突记 «d:odt_part»。',
                'DS1103 表 3-6 / 3-26; UG304-1.3 §3.3.2; 核心板原理图 p3', '已定 (对本接口)'),
        'gw_in_std': ('电气·IO 标准', 'GW5A 差分输入对 VCCIO 的要求',
                      'DS1103 表 2-7 (GW5A-25): LVDS25 输入, Bank VCCIO 2.5 / 1.0 / 1.2 / 1.5 / 1.8 / 3.3 均可',
                      '上行接收组放 3.3V 固定的 VCCIO45 合法。gw5a_loop n13_l800_verA 已按 LVDS25 DIFF_RESISTOR=ON BANK_VCCIO=3.3 在 bank2 / 3 / 4 布局布线通过 (WNS 2.340 ns; 工具层, 未上板)。',
                      'DS1103 表 2-7; gw5a_loop/results/n13_l800_verA/SUMMARY.txt / run.cst', '已定 (手册) / 工具层'),
        'gw_out_std': ('电气·IO 标准', 'GW5A 输出对 VCCIO 的要求 (下行依据)',
                       'DS1103 表 2-6: LVDS25 (TLVDS) 输出 VCCIO 2.5 / 3.3; LVDS25E (ELVDS) 输出 VCCIO 2.5; LVCMOS33D 输出 VCCIO 3.3; 表 3-27: TLVDS VOS 1.125 / 1.25 / 1.375 V; 表 3-28: ELVDS VOS = VCCIO/2; ICND2260 VIC 1.1~1.3 V',
                       f'下行驱 ICND2260 走 ELVDS + 3R @2.5V ⇒ 下行组 = VCCIO23 (底板设 2.5V) + VCCIO67 (核心板定 2.5V) = 47 対 (sheet8)。3.3V TLVDS VOS 上限 1.375 V 超 VIC 上限 1.3 V; 3.3V 伪差分 (LVCMOS33D + 5R) 作备用 (sheet8)。',
                       'DS1103 表 2-6 / 3-27 / 3-28; ICND2260 mini-LVDS 电气特性', '已定 (口径)'),
        'vccio_groups': ('电源·GW5A', '核心板 VCCIO 组电压固定情况',
                         '核心板原理图 p3: VCCIO01 = VCC1P5 经 FB4 (bank0/1 挂 DDR3); VCCIO67 = VCC2P5 经 FB3; 两者同时引到连接器 (P1.9/10, P2.97/99); VCCIO23 / VCCIO45 只由连接器 P1.5/7、P1.6/8 输入 (官方 CB-V2 底板 VCC3P3 经 FB5 / FB4)',
                         'VCCIO01 1.5V 固定 · VCCIO23 底板供 (D5 定 2.5V, «e:vccio23») · VCCIO45 3.3V 固定 («e:vccio45») · VCCIO67 2.5V 固定。V2 底板不得向 P1.9/10、P2.97/99 另灌电源 («d:vccio0167»)。',
                         '核心板原理图 p3; ACG525-CORE-V2.SchDoc', '已定 (需供应商确认 FB 实装)'),
        'vccio45': ('电源·GW5A', 'VCCIO45 = 3.3V 固定 (bank4/5 挂核心板启动电路)',
                    '核心板原理图 p4: U2 = GD25Q128ESIG, VCC 接 VCC3P3; FLASH_CS → V3 (MCS_N)、MISO → R13 (D00)、MOSI → T13、CLK → R15 (CCLK)、WP → T14、HOLD → V14, 均在 bank4, 4.7K 上拉 VCC3P3。'
                    '配置脚: READY (U3)、RECONFIG_N (V2, bank5)、DONE (V17)、MODE0 (T15)、MODE1 (N12, R56 DNI/1K) 接 VCC3P3。50M 有源晶振 CLK_G 经 22Ω 入 T9 (bank4)。'
                    'UG714 §3.2: 配置脚上拉到对应 bank 的 VCCIO; DS1103 表 3-23: LVCMOS25 VIH 上限 = VCCIO + 0.3',
                    'V2 底板必须给 VCCIO45 (P1.6/8) 供 3.3V, 与官方 CB-V2 一致, 不能自选; bank4/5 不能作 2.5V ELVDS 下行组, 正好作上行接收组 (差分输入不限 VCCIO, «e:gw_in_std»)。'
                    '核心板占用的这 12 个球都不在 P1/P2 连接器上 (脚本已核), 上行 20 対与边带不撞脚。',
                    '核心板原理图 p3 / p4; UBGA324.json; UG985 V1.7.2 Pin List; UG714 §3.2; DS1103 表 3-23', '已定'),
        'vccio23': ('电源·GW5A', 'VCCIO23 = 2.5V (V2 底板设)',
                    'DS1103 表 2-6: LVDS25E 输出 VCCIO 2.5; 表 3-23: LVCMOS25 VIL 0.7 V / VIH 1.7 V, VIH 上限 VCCIO + 0.3',
                    'VCCIO23 = 2.5V (D5 定): 作下行 ELVDS 组, 并放边带 SoC → 桥 输入 SB_RSTN / SB_UART_S2B (B3_B71, LVCMOS25)。后果: ① 与官方 CB-V2 (3.3V) 不同, gw5a_loop 自测位流按 BANK_VCCIO=3.3 约束 bank2/3, 不能直接拿到 V2 上用 («d:v2_vccio23»); '
                    '② V2 若留 3.3V 档跑自测, 3.3V 档下不得接 SoC 模组 (边带输入门限余量仅 0.1 V, 自测位流可能驱这两脚); 桥 → SoC 输出因此放固定 2.5V 的 VCCIO67; '
                    '③ B3_B65 (N 端 DOUT) 仍作隔离不接, B3_B71 改作边带 (sheet8)。',
                    'DS1103 表 2-6 / 3-23; 核心板原理图 p1; 用户 09-15 D5', '已定 (D5; 边带落脚为建议)'),
        'rate_tx': ('速率', '发端 IO 上限', 'DR1 PL I/O 输出: LVDS25 / LVDS18 均 1250 Mbps (注: 能否到最高以 Timing Report 为准)', '800 Mbps 余 56 %。', 'DS1200 表 3-22', '已定'),
        'rate_rx': ('速率', '收端 Gearbox 上限', 'GW5A-25: IDES4 800 Mbps, IDES8 1600 Mbps, IDDR 400 Mbps', '800 Mbps 用 IDES4 零余量 ⇒ 上行必须 IDES8 (rtl_x8)。', 'DS1103 表 3-34; README_x8.md', '已定'),
        'occupancy': ('速率', '链路占用率', '8-bit 载荷 9.003 Gbps/面 (bridge_defs.vh §1); 线上有效 = lane 数 × 线速率 × 126/128 (SYNC beat 开销, bridge_defs.vh §2)',
                      f'阶段二 8-bit 18 lane: 800 / 700 / 600 Mbps 占用 {OCC[800]} / {OCC[700]} / {OCC[600]} %; 12-bit 18 lane 只能 800 Mbps ({OCC12} %)。现 12 lane 8-bit @800 Mbps 占用 {OCC_NOW} % (余 5.0 %)。',
                      'bridge_defs.vh §1 / §2 (本表计算)', '已定 (计算; 12-bit 协议与降速档是否允许见 «d:proto_12bit»)'),
        'b2b6': ('速率·GW5A', 'Bank2 / Bank6 (Left/Right) 速率',
                 'DS1103 表 2-11 注[3]: "GW5A-25 器件的 Left/Right Bank (Bank2 / Bank6) 的传输速率偏低, 建议使用 Top / Bottom Bank (Bank0 / Bank1 / Bank3 / Bank4 / Bank5 / Bank7)" —— 注挂在 MIPI IO 类型支持表下, 无数字',
                 f'上行在 bank4/5 (Bottom) 不受影响。下行规划里 {len(DOWN_B26)} 対在 bank2 (Right) / bank6 (Left): 剔除后 2.5V 差分可用只剩 bank3 + bank7 = {len(DOWN_TB)} 対 (已扣隔离), 核算 A 需 37 対 ⇒ 缺 {-NC[1]} 対。'
                 f'下行 300 Mbps (dclk 150 MHz 双沿, bridge_defs.vh §5) 在 B2/B6 上能否跑是下行规划的承重未证项 («d:b2b6»)。',
                 'DS1103 表 2-11 注[3]; bridge_defs.vh §5', '待定'),
        'timing_tool': ('时序', '时序余量来源 (工具层)', 'DR1 发端探针 (bank33 现役 14 対): SWNS +0.010 ns (pclk 按 400 MHz 约束), PackReg = DDRX2 14/14; GW5A-25 rtl_x8 @800 Mbps WNS +1.986 ns',
                        f'只对旧球位与 LVDS18 成立: SoC 侧两面都换球 / 改 LVDS25 (面 A 新球位 {len(A_NEWBALL)} 对 + 改动 {len(A_MOVE)} 对, 面 B 20 对全新) ⇒ 必须重跑; '
                        'GW5A 侧上行从 bank2/3 挪到 bank4/5, 也要按新脚位重综合。板级眼宽只能上板扫 IODELAY / 跑 PRBS。',
                        'project_dr1_uplink_tx_probe; README_x8.md', '已定 (工具层, 旧球位)'),
        'hclk': ('时序', '采样时钟与跨 bank', 'GW5A PLL 经 HCLK cycle-cycle 抖动 < 300 ps (≈24 % UI @800 Mbps)',
                 f'上行 20 対跨 bank4 (11 対) + bank5 (9 対); 阶段一 14 対 = bank4 {GW_PH1_BANK[4]} + bank5 {GW_PH1_BANK[5]}。转发时钟建议 B4_B33 (GCLKT_9A / BPLL_T_IN1), 备选 B4_B35 (GCLKT_8)。'
                 '转发时钟直驱 HCLK → IDES8.FCLK 能否覆盖两个 bank、或经 BPLL 再生, 未综合过 («d:gw_hclk»)。',
                 'DS1103 表 3-38 (经 README_1g6.md 引); README_x8.md 未做项', '待定'),
        'iodelay': ('时序', '对间偏斜吸收', 'IODELAY Tdlyunit 10 / 12.5 / 15 ps, Tdlyoffset 200 / 250 / 300 ps, 256 步 ⇒ 量程约 2.76 ~ 4.14 ns',
                    '对间长度差由每 lane IODELAY 吸收, 不必强求对间等长; 对内仍需等长 (建议 ≤5 mil, 估)。', 'DS1103 表 2-8; README_1g6.md', '建议'),
        'core_len': ('时序', '核心板引出线长', 'V1 核心板线长报告: bank 内对间差 ≤47 mil (≈8 ps), 对内 ≤36 mil (≈6 ps); 跨 bank 最大差 544 mil (≈90 ps)',
                     '上行 20 対必跨 bank4 / bank5 (各引出 11 完整対); 90 ps 在 IODELAY 量程内。V2 核心板线长报告本包没有。', 'project_gw5a_bridge_verification (记忆库线索)', '建议'),
        'fpc_z': ('SI·阻抗', '连接器 / FPC', '100 Ω ±10 % 差分受控, 向厂家写明并给叠层; 必须是阻抗受控多层 FPC (或同等连接器), 不是普通 FFC; 长度尽量 ≤200 mm (估)',
                  '普通无阻抗控制排线在 800 Mbps 下不成立。', '用户 09-15; project_pov3d_bridge_stamp_module', '已定 (用户 09-15)'),
        'pinorder': ('SI·脚序', '契约建议脚序', f'20 対 × G-S-S-G = 61 芯 (位置 1~61); 边带 4 + JTAG 4 + 地 {len(SB_GND)} = {len(SE_ALL) + len(SB_GND)} 芯 (62~{TOTAL_POS}); 合计 {TOTAL_POS} 芯',
                     f'阶段一 14 対落契约第 4~17 対 (位置 {PH1_SPAN[0]}~{PH1_SPAN[1]}), UL_CLK 在第 10 対 (位置 {CPOS["CLK"][0]}/{CPOS["CLK"][1]}), 阶段一与阶段二都居中; '
                     f'UL_D[14:12] 在一端 (位置 {CPOS["D12"][0]}~{CPOS["D14"][1]}), UL_D[17:15] 在另一端 (位置 {CPOS["D15"][0]}~{CPOS["D17"][1]})。单端每组 ≤3 根、组间夹地, JTAG_TCK 单独成组两侧是地 (位置 67 / 69)。形态与实际脚号由硬件定; 两面接口完全相同 (D2)。',
                     '本表', '建议'),
        'fs03_gnd': ('SI·FS03 地', 'CEP 只有 2 根地', 'CEP1 / CEP2 各 50 脚: pin1 = VCC_CEPx, pin2 = GND, pin3~50 = 48 个 FPGA IO ⇒ 96 信号 : 2 地; 排针 (n, n+1) 列 = 真差分対 (奇 P 偶 N)',
                     'V3 地改造: 两侧各加一排地做 G-P-N-G 四排; 地条沿长度 ≥3 点接回 FS03 真地, 最长自由段 ≤21 mm (否则地条 λ/4 谐振落在 0.96~1.18 GHz), 每个接点 ≤5 mm; 动烙铁前先测未改造基线。D7 双面两个排针同时用, 都要改; J12 相对 J11 转 180° (pin1 在右), V3 布局镜像; FS03 侧只焊短线 (虚焊的地针比没有更糟)。',
                     'FS03 手册 §16; project_pov3d_fs03_cep_ground_and_third_row §1 / §4 / §6', '建议'),
        'b2b': ('SI·B2B', '核心板 B2B 地脚少、上行用满 VCCIO45', 'P1 / P2 共 200 脚只有 20 根地; 差分対 P/N 连排, 相邻対之间无地; VCCIO45 引出 22 完整対',
                '上行 20 対占 VCCIO45 22 対里的 20 対 ⇒ 不能再隔对使用, 同排相邻対、双排面对面対之间都无隔离 (v1 表的隔离対做法不再适用)。'
                'VCCIO23 的 B3_B65 (P1.31/33, 隔离不接) 与 B3_B71 (P1.32/34, 边带 SB_RSTN / SB_UART_S2B) 紧邻上行 P1.29/30 —— 紧挨上行的 P1.32 放准静态 SB_RSTN; '
                'VCCIO45 空置 2 对 (P2.68~74) 与空置半対 P2.71/73 夹在上行之间 ⇒ 不接; P1.15 / P1.17 半対空置 (P1.17 紧邻 UL_CLK N P1.19); P2.59/60 为 MIPI 硬核 (不用)。'
                'JTAG P1.94~100 对排是 B2_R7 / B2_R9 (VCCIO23 下行候选), 作高速下行时会串扰 TCK (sheet4)。逐脚见 sheet4 "相邻非上行脚" 列, 上板 PRBS / 眼图时对照。'
                '对内脚序: P1 每対 N 小脚号 / P 大脚号, P2 相反 ⇒ V2 布线逐对核对是否要 P/N 交叉, 或 P/N 对调 + RTL 取反 (sheet4 规划·P/N 脚序)。',
                '核心板原理图 p1; ACG525-CORE-V2.SchDoc; README_1g6.md §接插件 (估)', '建议'),
        'pwr_dr1': ('上电·DR1', 'bank33 上电固定态',
                    '上电完成到程序加载完成前 (TPOR ≤49.2 ms + TPROG ≤39.6 ms, 最坏约 90 ms), bank33 有 35 球被硬性固定, 不受 HSWAPEN 控制: 下拉 D22 A21; 上拉 33 球; 4 対被劈开 R9 / R15 / R16 / R21',
                    f'D7 双面: 面 A (bank33) 20 対里 {a_up} 対 P/N 同上拉 (对端差分≈0)、{len(A_FREE)} 対随 HSWAPEN ({a_free}); 4 个劈开対 8 球不作 LVDS, 改作单端: '
                    '两面 JTAG 6 球 (A16 / A17 / A21 / A22 / E19 / E20, 全是 ADC 复用球, «e:soc_se») + SB_UART_S2B (D22 / C22); JTAG_TCK 落 A21 (强制下拉 ⇒ 配置期 TCK 为低, TAP 不动), '
                    '面 A JTAG_TDO 落 A17 (强制上拉 ⇒ 桥模组未上电读全 1, 只作"不在位"提示; 面 B TDO A22 随 HSWAPEN, FS03 HSWAPEN = 0 同为弱上拉);两面 SB_RSTN 在 bank11 (弱上拉 × 桥侧 2.2 kΩ ≤0.34 V ⇒ 默认复位)。'
                    '面 B (bank11) 不在表 2-6, 20 対随 HSWAPEN。两面都要 SB_RSTN 门控: 桥片在复位释放前不开始 lane 对齐; 这 ~90 ms 内 DR1 弱上拉灌入未上电桥模组, D6 管不到, 按 FS03 先上电的顺序不出现 («d:soc_inject»)。',
                    'DS1200 §2.8.2 表 2-6; DS1200 配置时序注 3; reference_dr1_bank33_poweron_forced_pins', '已定 (事实; 应对做法为建议)'),
        'pwr_gw': ('上电·GW5A', '配置期 GPIO 与 SSPI 回落',
                   'UG304-1.3 §3.3: 配置前及配置过程中器件所有 GPIO 默认弱上拉; UG714 表 3-1: MSPI = MODE[1:0] 01, 注[4] "MSPI 失败之后会自动进入 SSPI 模式"; UBGA324.json: R3 = IOB8A D05/SO/SSI1 (B5_B8_P)',
                   '核心板从 GD25Q128E (MSPI) 启动。若 MSPI 失败回落 SSPI, SSPI 脚会被采样、SO 可能变输出 ⇒ SO 所在对 B5_B8 不接上行 (悬空, 勿接地); 上行用到的 SSPI 脚 (B5_B14 SSPI_CLK / CLKHOLD_N、B5_B10 SSPI_CS_N / SI) 只放阶段二 lane。'
                   '上电到配置完成期间上行接收脚为弱上拉输入, 不驱动线路; 边带 SB_ALIGNED 输出脚同样是弱上拉 ⇒ 靠 SoC 侧外部下拉给默认"未对齐" («e:sideband_level»)。'
                   '配置完成后跑的是 flash 里的镜像 (出厂 / 环回自测 / 空): 它在 SoC 读 IDCODE 前、以及每次 openFPGALoader 加载 (先 RELOAD) 时都会运行, 包内 n13_l800 自测镜像会对驱上行球并端接边带输入 '
                   '⇒ 接 V2 / V3 / FS03 前擦除或烧安全镜像 (sheet4 规划·核心板 flash, «d:core_flash»)。',
                   'UG304-1.3 §3.3; UG714 表 3-1; UBGA324.json; 核心板原理图 p4', '建议'),
        'sideband_level': ('电气·边带', '边带电平 2.5V、两端直连与默认下拉',
                           'DS1200 表 3-11 (DR1 PL) LVCMOS25: VIL 0.7 V / VIH 1.7 V / VIH 上限 VCCIO+0.3 = 2.8 V / VOH ≥ VCCIO−0.4 = 2.1 V, IOH 4 / 8 / 12 / 16 mA; '
                           'DS1103 表 3-23 (GW5A-25) LVCMOS25: VIL 0.7 V / VIH 1.7 V / 上限 VCCIO+0.3 / VOH ≥ VCCIO−0.4, IOH 2~16 mA; DS1200 表 3-1: PL I/O 直流输入 ≤ VCCIO+0.3。'
                           '上下拉: UG304 §3.3 GW5A 配置前及配置中所有 GPIO 默认弱上拉, UG714-1.0.6 PUDC_B 注[1] "25K 器件弱上拉强度为 Medium"; DS1103 表 3-16 IPU 上限 50 / 150 / 400 µA (Weak / Medium / Strong); '
                           'DS1200 表 3-9 (PL) IPU @VCCIO 2.5V 83~153 µA、@3.3V 93~192 µA; DS1200 §2.8.2 HSWAPEN = 0 时用户 I/O 配置中弱上拉',
                           '契约边带 = LVCMOS25 2.5V (已定 D5)。两端直连核验 (两侧 VCCIO 均 2.5V): DR1 VOH ≥2.1 V > GW5A VIH 1.7 V ✓; GW5A VOH ≥2.1 V > DR1 VIH 1.7 V ✓; 驱动端 VOH ≤ VCCIO = 2.5 V < 对端上限 2.8 V ✓ '
                           '(两侧 VCCIO 各 ±5 % 最坏 2.625 V < 2.375 + 0.3 = 2.675 V ✓) ⇒ 可直连。LED 侧落 2.5V 组 (sheet4): 桥 → SoC 输出放 VCCIO67 (核心板固定 2.5V), SoC → 桥 输入放 VCCIO23 (V2 设 2.5V)。'
                           '✘ 不许落 GW5A VCCIO45 (3.3V 固定): 3.3V 输出超 DR1 输入上限 2.8 V。'
                           '默认电平 (已定 D4): SB_ALIGNED 在 SoC 侧、SB_RSTN 在桥侧各加外部下拉 2.2 kΩ, 不能只靠片内弱下拉。核算: SB_ALIGNED 对桥片配置期弱上拉 Medium 上限 150 µA 加 DR1 输入漏电 30 µA 同流过下拉, (150 + 30) µA × 2.2 kΩ = 0.40 V < DR1 VIL 0.7 V (不串阻时余 0.30 V; 验证板 V3 串 8.2 kΩ 后焊盘 0.643 V, 余 57 mV, 见下; '
                           '若实为 Strong 400 µA 则 0.88 V ✘, 需 ≤1.5 kΩ —— 上板量该线在桥片配置中的电平确认); SB_RSTN 对 DR1 配置中弱上拉 153 µA @2.5V × 2.2 kΩ = 0.34 V < GW5A VIL 0.7 V (余 0.36 V)。'
                           '驱动端高电平负载 2.5 V / 2.2 kΩ = 1.14 mA, 在 GW5A 最小 2 mA / DR1 最小 4 mA 驱动档内。'
                           '验证板 V3 对端 → DR1 限流 (改板审查 v2 M3(c); README v2.2 §5.12.2): 岛掉电是持续状态, 按表 3-8 DC 350 µA 算 ⇒ 串阻 6.04 kΩ ≤ Rs ≤ 9.13 kΩ (审查原建议的百欧级只满足 AC 15 mA, 不采用)。'
                           'SB_ALIGNED: 紧贴 CEP 母座串 8.2 kΩ (1 %, 0402), 2.2 kΩ 下拉在串阻的连接器侧 (仍在 V3 上), DR1 PULLTYPE = NONE; 注入 (2.625 − 0.3~0.5) / 8.233 kΩ = 258~282 µA ✓; '
                           '高电平最坏 1.975 − 30 µA × 8.233 kΩ = 1.728 V ≥ 1.7 V (余 28 mV, 按手册极限值; µA 级负载下实际 VOH ≈ VCCIO); '
                           '桥片未配置: DR1 漏电 30 µA 也流过 2.2 kΩ, 节点 (150 + 30) µA × 2.2 kΩ = 0.396 V, 焊盘 0.396 + 30 µA × 8.233 kΩ = 0.643 V < 0.7 V (余 57 mV) ⇒ SB_RSTN 为低时 V2 侧不驱高; '
                           '下拉若放在串阻与 CEP 母座之间则分压, 8.2 kΩ 时高电平约 0.5 V, 恒读未对齐。'
                           'SB_UART_B2S: 串 8.2 kΩ, DR1 PULLTYPE = NONE (禁止 PULLUP: 开 PULLUP 时低电平 0.4 + 153 µA × 8.233 kΩ = 1.66 V, 恒读 1; 要开 PULLUP 串阻须 ≤1.93 kΩ, 失去 DC 保护); '
                           'NONE 时低电平最坏 0.4 + 30 µA × 8.233 kΩ = 0.647 V ✓; 115200 bps: τ = 8.233 kΩ × 20 pF (估) = 165 ns, 过门限最坏 679 ns = 位宽 8.68 µs 的 7.8 % ✓; 读到 IDCODE 前 SoC 不采信 RX。'
                           '两根都落 bank11 非 ADC 球 (串 kΩ 级电阻的慢沿输入不得落 ADC 复用球)。'
                           'JTAG_TDO: V3 不贴串阻 (0402 位默认 0 Ω), DR1 PULLUP, V2 B 口 10 kΩ 下拉必须; DC 保护: bank33 掉电 ⇒ TCK 停 ⇒ TAP 不在 Shift ⇒ TDO 高阻 ⇒ 被 B 口下拉 ⇒ 转换器输出低; '
                           '残余风险 = 移位中途掉电 («d:soc_inject»); 落 ADC 复用输入球的摆率依据见 «e:soc_se»。SB_RSTN / SB_UART_S2B: V3 不串阻、不加上下拉, 2.2 kΩ 下拉只贴 V2 (误串 8.2 kΩ 时 0.44 V, 桥片永远复位)。'
                           '目标板 SoC 侧: 2.5V 单端可与 LVDS25 上行同 bank。',
                           'DS1200 表 3-1 / 3-9 / 3-11 / §2.8.2; DS1103 表 3-16 / 3-23; UG304 §3.3; UG714-1.0.6 PUDC_B 注; 用户 09-15 D4 / D5', '已定 (D4 / D5; 直连与下拉为计算核验)'),
        'jtag': ('JTAG', '程序加载 JTAG 4 根 (契约)',
                 'UG714-1.0.1 表 3-5: TCK 输入 (无片内上拉) / TMS、TDI 输入片内弱上拉 / TDO 输出; 表 3-6: JTAG PORT 默认专用, 可设为"配置结束后作 GPIO"; 注[2] JTAG 复用时上电加载中 TCK / TMS 须稳定; '
                 '表 3-7: Tj_clk ≥10 ns (≤100 MHz), Tj_tmssu / Tj_dsu ≥3.0 ns, Tj_dvld ≤3.0 ns。UG714-1.0.6 §3.4.1 注 / 表 3-7 注[1]: A 版本芯片 TCK ≥15 MHz, 其他版本无下限。'
                 '核心板原理图 p3: Bank10 IOR1A/TCK = A17、IOR3A/TMS = B18、IOR1B/TDI = D15、IOR3B/TDO = D16, VCCX / M0_VDDX / VCCIO10 = VCC3P3; p1: P1.94 TDO / 96 TDI / 98 TMS / 100 TCK',
                 '契约 (D3 / D5): TCK / TMS / TDI (SoC → 桥)、TDO (桥 → SoC), LVCMOS25 2.5V; TCK 单独成组两侧夹地, TMS / TDI / TDO 一组。桥片位流不得回收 JTAG 脚 (GW5A: Dual-Purpose Pin 不勾 JTAG PORT); '
                 '桥片 flash 焊盘保留 DNP 作退路。在位检测: SoC 读 IDCODE 判桥片在位, 读到前不驱 LVDS 与边带 (D6); GW5A-25 IDCODE 0x0001281B, A / B 版相同, 读 ID 分不出版本 (并行流程 research:gw5a 引 UG714 IDCODE 表, 本表未复核)。'
                 + JTAG_TCK_RATE + '。',
                 'UG714-1.0.1 表 3-5 / 3-6 / 3-7; UG714-1.0.6 (scratchpad) §3.4.1; 核心板原理图 p1 / p3; UBGA324.json (CFG = TCK / TMS / TDI / TDO, BANK 10); 用户 09-15 D3 / D5 / D6',
                 '已定 (D3 / D5 / D6; TCK 频率待定)'),
        'jtag_shift': ('JTAG·电平转换', 'V2 上 2.5V ↔ 3.3V 转换器要求',
                       'GW5A bank10 = VCCX = 3.3V 固定 (核心板 p3), LVCMOS33 VIH 2.0 V (DS1103 表 3-23); DR1 LVCMOS25 VOH ≥2.1 V、PL 输入上限 VCCIO+0.3 = 2.8 V (DS1200 表 3-11 / 3-1)',
                       '必须转换 (D5): 不转换则 GW5A TDO 3.3V 进 DR1 2.5V bank 超 2.8 V 上限 ✘, SoC → 桥 方向 2.1 V 对 2.0 V 仅余 0.1 V。要求 (D5 已定): 固定方向 (DIR 硬接, 不用自动方向检测型)、双电源、带 Ioff (任一侧掉电时 I/O 高阻), '
                       'TDO = B (3.3V) → A (2.5V), TCK / TMS / TDI = A → B; 如 SN74LVC1T45 ×4 或 LVC2T45 类 (型号、Ioff 条件、A 口 VIH 与速率余量待查手册 «d:jtag_shift_part»)。'
                       '建议: VCCA = V2 本地 2.5V (与 VCCIO23 同轨), VCCB = V2 3.3V, 两个电源都在 LED 模组本地、不走接口 (D6)。静止电平约定 TCK 为低、TMS / TDI 为高: '
                       'A 口 TCK 2.2 kΩ 下拉、TMS / TDI 各 22 kΩ 上拉到 V2 本地 2.5 V; B 口 TCK 4.7 kΩ 下拉、TDO 10 kΩ 下拉 (必须: TAP 不在 Shift 时 TDO 为低, 是 SoC 岛掉电时 TDO 线的直流保护前提)。'
                       '依据: TCK 用 2.2 kΩ, SoC 配置期弱上拉 ≤153 µA × 2.2 kΩ ≤0.34 V < VIL 0.7 V (两面共用并联 1.1 kΩ 为 0.17 V, DR1 8 mA 档驱高负载 2.27 mA); '
                       'TMS / TDI 上拉与 DR1 配置期状态一致 (E20 表 2-6 强制上拉, A16 / E19 随 HSWAPEN = 0 弱上拉), 旧"下拉时电平不定"的说法作废; 上拉经 22 kΩ + 33 Ω 反灌未上电 DR1: TDI 单只 (2.625 − 0.5) / 22.03 kΩ = 96 µA, 共用 TMS 两只并联 11 kΩ 为 (2.625 − 0.5) / 11.03 kΩ = 193 µA, 均 ≤350 µA (≥6.07 kΩ); '
                       'DR1 驱低灌电流: 共用 TMS 2.5 V / 11 kΩ = 0.23 mA, TDI 2.5 V / 22 kΩ = 0.11 mA; 一面 LED 模组未上电时 TMS 仍被分压到约 1.25 V, 此时 TCK ≤0.17 V 无沿, TAP 不动; '
                       'SoC 首次访问 JTAG 前仍先发 ≥5 个 TMS = 1, 每次访问结束也发 ≥5 个 TMS = 1 让 TAP 回到 Test-Logic-Reset; 转换器输入不得带 bus-hold。'
                       'DR1 → V2 方向 (TCK / TMS / TDI) 进转换器 A 口, V2 掉电时靠转换器 Ioff (最大值在 VCCA = 0、VI ≤2.625 V 条件下待 V2 选型核, «d:jtag_shift_part»), V3 不串阻。'
                       'A 口输出 (TDO) 进 DR1 ADC 复用球: DS1200 §4.2 注 3 "对端器件的驱动要求使用 FAST 配置或 slew rate > 3.3V/ns" 按对端驱动器设置理解, 快速 CMOS 转换器满足, 选型仍核 tr / tf («d:adc_se»); '
                       'B 口 TCK / TMS / TDI 与 FPGA 之间串 0Ω, 下载器插座 (官方 CB-V2 P5 脚位) 接 FPGA 侧, SoC / 下载器二选一 (D5)。V2 电路未画, 阻值为建议。',
                       '核心板原理图 p3; DS1103 表 3-23; DS1200 表 3-1 / 3-11; 用户 09-15 D5', '已定 (D5 要求; 器件与阻值为建议)'),
        'powerup': ('上电·两模组', '分开上电与 IDCODE 门控',
                    '用户 09-15 D6: 晶振在 LED 模组本地、电源不走接口、两模组分开上电; SoC 在读到桥片 JTAG IDCODE 之前不驱动 LVDS 与边带。DS1200 表 3-1: PL I/O 输入 ≤ VCCIO+0.3',
                    '① SoC 侧 (已定 D6): 上电后 20 対 LVDS 与 SB_RSTN / SB_UART_S2B 输出不使能 (高阻), 先经 JTAG 读 IDCODE, 读到后才使能; SB_ALIGNED 在释放 SB_RSTN 且读到 IDCODE 前不采信 (D4)。'
                    '② JTAG 是在位探测通道, SoC 在 LED 模组可能未上电时就会驱动 ⇒ 桥模组侧转换器必须带 Ioff («e:jtag_shift»); 在位以 IDCODE 精确等于 0x0001281B 为准; SoC 侧 TDO 弱上拉 (建议), LED 模组未上电时读到全 1 只作"不在位"提示。'
                    '③ 反方向 (建议, 非用户决定, 验证期按强制执行): SoC 模组未上电时桥片不得把 SB_ALIGNED / SB_UART_B2S 驱高 —— SB_RSTN 被桥侧 2.2 kΩ 下拉为低, 桥片 RTL 与核心板 flash 里的任何镜像都要在 SB_RSTN 为低期间把这两根输出为低或高阻 '
                    '(flash 见 sheet4 规划·核心板 flash, «d:core_flash»); JTAG TDO 由 B 口 10 kΩ 下拉 (必须) 保证静止为低 (无 TCK 进不了 Shift)。'
                    '桥片配置期片内弱上拉 (≤150 µA) 在 SB_ALIGNED 上: 下拉节点 (150 + 30) µA × 2.2 kΩ = 0.396 V, 经 V3 8.2 kΩ 后 DR1 焊盘 0.643 V < VIL 0.7 V (余 57 mV, «e:sideband_level»); '
                    'SB_UART_B2S 上无下拉, 为 ≤150 µA 注入 (< DS1200 表 3-8 每 I/O 直流 350 µA) («d:rtl_readback»)。'
                    '④ 上下电顺序 (建议, 验证期按改板方案 README v2.2 §5.7 硬规则强制执行): FS03 上电 → 闸门 (J_TP11、SENSE33、TP_TDO_A) → 加载 LVDS25 位流 (位流内 LVDS / SB_RSTN / SB_UART_S2B 保持不使能) '
                    '→ LED 模组 (V2 + 核心板 + V1) 上电 → SoC 轮询 IDCODE (不设失败超时, 只上报) → 读到后使能该面; 断电: LED 模组先断, FS03 最后断电。V3 是无源板, 不单独上电。'
                    'FS03 自身: VCCIO 晚于 VCCAUX 上电 (电路结构保证); 下电时 VCCIO 比 VCCAUX 晚掉几 ms 到十几 ms (τ ≈ 12 ms), DS1200 PDF p44 §3.1.5 允许, 不影响器件寿命; 此时 LED 模组已断电 (V3 G1)。'
                    'D6 的流程 (SoC 先经 JTAG 读 IDCODE) 容易让人先给 LED 模组上电: 此时未门控的桥片镜像把 SB_UART_B2S 空闲驱高到 2.5 V, 经 33 Ω 灌进未上电 DR1 bank 的钳位二极管, mA 级 (受驱动能力限定) ≫ 350 µA, '
                    '并经钳位管抬起 ADJ 岛 (改板模块肖特基 + 1 kΩ 泄放是第二道防线)。'
                    '⑤ 门控与被门控同 bank: 每面 SB_RSTN 与本面 SB_ALIGNED / SB_UART_B2S 同在 bank11 (sheet3 规划·单端), bank11 岛掉电 (J1 模块未装 / 松脱 / 失地) 时 SB_RSTN 同时变低, 门控不失效。'
                    '⑥ DR1 → 对端方向 (SB_RSTN / SB_UART_S2B / TCK / TMS / TDI) 在 V3 上不串阻, 依据: SB_RSTN / SB_UART_S2B 直连 GW5A VCCIO23 球 (U18 / U17), LED 模组未上电时靠 GW5A 热插拔特性 DS1103 表 3-8 IHS ≤150 µA (印刷页 50), 满足每 IO 350 µA '
                    '(串阻也帮不上: SB_RSTN 有 V2 2.2 kΩ 下拉, 分压要求串阻 ≲0.8 kΩ, 限不住 DC); TCK / TMS / TDI 进 V2 转换器 A 口, 靠转换器 Ioff, 最大值待 V2 选型后核实 («d:jtag_shift_part»)。',
                    '用户 09-15 D4 / D6; DS1200 表 3-1 / 3-8 / §3.1.5; DS1103 表 3-8 (IHS); UG304 §3.3; dr1v90/fs03_mod/README.md v2.2 §5.7 / §5.12; V3_design_inputs.md G1 / G3; 改板审查 v2 M3 与 v2.1 复核', '已定 (D6; 反方向做法与上下电顺序为建议, 验证期按强制执行)'),
        'cep27': ('管脚·FS03', 'CEP2.7 球位', 'FS03 手册 §16: CEP2 pin7 = Y19 (IO_R11P_31, bank31); FS03 原理图 P17: J12 pin7 旁标 Y9, 网络 CEP2_3P → R200 → BK11_L12P → Y9 (IO_L12P_11, GCLKIOT2)',
                  '该対 (L12_11) 是 GCLK 対; 未烧 toggle 位流确认 CEP2.7 之前不得作信号。D7 双面: 两面都不用, 作 V3 J_TP11 闸门测点 —— CEP2.7 / CEP2.8 (Y9 / Y8) 各串 10 kΩ 紧贴 CEP 母座再引到排针, 不接 FPC; '
                  '加载前弱上拉读 ≈VCCIO_11, 判 2.40~2.60 V; 闸门只读直流弱上拉, 不需要 toggle (V3_design_inputs.md B 组, README v2.2 §5.12.1)。JTAG 分配不得占用 CEP2.7 / CEP2.8, 否则 J_TP11 失效。'
                  '若启用 Error-8221 顶替 (用它顶替面 B 一个报错的 LVDS 対, 须先 toggle): V3 改版、闸门改 SENSE11。光电备选已被 K18 取代; 面 B 独立 JTAG 的 TCK / TMS 因 ADC 复用注 1 不可用。',
                  'FS03 手册 §16; FS03 原理图 P17 / P06; dr1v90/fs03_mod/V3_design_inputs.md B1 / B7', '待定'),
        'jumper': ('电源·FS03', 'bank 电压跳线 J1 / J2', 'FS03 电源只有 3.3 / 1.8 / 1.35 V; J1 (ADJ_BANK11) / J2 (ADJ_BANK33): 1 = VCC_3V3, 2 = ADJ, 3 = VCC_1V8',
                   'D7: 两个 CEP bank 都要 2.5V, 跳线只有 3.3V / 1.8V 两档 ⇒ J1 / J2 都拔帽改接 2.5V (改板方案 README v2.2, 未实施, «e:adapt»)。后果: ① 这块 FS03 不能再直驱 3.3V 屏 '
                   '(panel_pins_dr1.adc / td_pov 的 bank11 LVCMOS33; PANEL_BRINGUP_CHECKLIST #1 要求 J1 = 3.3V), 回退 = 拔模块插回跳帽 + 恢复位流; ② jtag_load 台架 (bank33 LVCMOS33, J2 = 3.3V) 与之互斥; '
                   '③ J1 / J2 对应丝印 BK13 / BK35 只是推断 (DXF 焊盘 x = 60.46 / 57.46 支持), 改板方案 README v2.2 以阶段 0 带电认座为决定性判据; '
                   '④ 动手前物理拆除 CEP1 上的 CB-V2 JTAG 台架飞线 (CEP1.4 / 5 / 15 / 18 = H20 / G15 / F21 / F17 → CB-V2 P5), CEP 全空才上电: 留着则 GW5A TDO 3.3 V 经 33 Ω 进 2.5 V bank 的 F21, '
                   '超 DS1200 表 3-1 绝对最大 VCCIO+0.3 = 2.8 V、注入约 6 mA; jtag_load 台架位流 (bank33 LVCMOS33) 不得在 2.5V 状态加载 (改板方案 README v2.2 §0.1 #4 / 阶段 −1 #2)。'
                   'v2 的单面跳线组合 (一个 bank 1.8V 出 LVDS18、另一个 3.3V 放边带) 已失效。',
                   'FS03 手册 §18; FS03 原理图 P08_PWR; PANEL_BRINGUP_CHECKLIST.md §4.2; panel_pins_dr1.adc', '已定 (事实)'),
        'oddr': ('管脚·DR1', 'ODDRx2 合法球位', 'ODDRx2 要求 .adc 指定合法 IOBE 球位, 合法表无公开文档 (只在 TD 数据库), 错了报 Error-8221; 判据: .area Detailed IO Report 的 PackReg = DDRX2, 计数 == 实例数',
                 f'bank33 现役 14 対一次过 (DDRX2 14/14, LVDS18)。D7 双面: 面 A 新球位 {len(A_NEWBALL)} 对 (阶段一 {len(A_NEW_PH1)} 对: {", ".join(A_NEW_PH1)}) 且 IOSTANDARD 改 LVDS25, 面 B 20 对全部新球位; '
                 f'两面 LVDS 余量都是 0, 能顶替报错球位的只有 {L12} (1 対, 须先 toggle)。旁证: td_panel 工程 bank11 的 AB10 / V12 PackReg = DDRX1 (LVCMOS33 单端 ODDR) —— 只说明 bank11 IOL 能打包寄存器, 不等于 ODDRx2 + LVDS25 合法。'
                 'V3 定稿前用 TD 一次试综合两面 40 対 .adc 并跑两 bank 同时 400 MHz pclk 时序 («d:soc_dual»)。',
                 'project_dr1_uplink_tx_probe; td_panel td_20260806_150332.log', '已定 (规则)'),
        'gw_cfgpins': ('管脚·GW5A', '避开 MIPI 硬核与配置复用脚',
                       'VCCIO45 22 対中 8 対带配置复用 (UG985 口径): ' + '; '.join(f'{k}({"/".join(t)})' for k, t in V45_CFG)
                       + '; IDE json 另列 ' + ', '.join(f'{k} 的 {"/".join(t)}' for k, t in V45_JSON_ONLY) + ' (UG985 无, 不计)'
                       '; MIPI D-PHY RX 硬核 = P2.50、P2.52~P2.60 (5 対; P2.49 / P2.51 = B6_L21 普通 IO); JTAG = P1.94 TDO / P1.96 TDI / P1.98 TMS / P1.100 TCK (P1.93 / 95 / 97 / 99 = B2_R7 / B2_R9 普通 IO)',
                       f'上行 20 対里 {len(UL_CFG)} 対带配置复用 ({", ".join(UL_CFG)}), 余下 2 対 (B5_B8、B5_B12) 不接。MSPI 模式下 CPU 并口 D03~D15 与 SSPI 脚不参与配置 (UG714 表 3-1), '
                       '但 Gowin EDA 默认按双用途脚处理, 要在 Project > Configuration > Dual-Purpose Pin 里放开 (UG714) —— 放开哪几项未试 («d:gw_cfgpins»)。避开 MIPI 与 JTAG。'
                       'IDE json 另列的 MCKTEST / ADCINCLK / ADCOTEST 已被 UG985 V1.7.2 删除、B5_B4 的 SDA / SCL UG985 未列, 均不计; 但 Gowin 工具按 json 判双用途脚, Dual-Purpose Pin 放开时按 json 口径 (含 I2C)。',
                       'UG985 V1.7.2 Pin List UG324; UG714; UBGA324.json; 核心板原理图 p1', '建议'),
        'mech': ('机械', '离心加速度', '转子 900 RPM, 68 ~ 136 g 离心加速度',
                 '连接器用带锁扣 ZIF + 点胶或直焊; 核心板 B2B 压条 / 螺丝固定; FS03 核心板 0.5 mm B2B 不是按这个加速度设计的。',
                 'project_pov3d_master_and_bridge_both_on_rotor; project_pov3d_bridge_stamp_module', '建议'),
        'nopower': ('电源·连接器', '模组间不走电源, 晶振在 LED 模组本地', '用户 09-15 D6; V2 / V1 从灯板取电, SoC 侧自供',
                    '契约不分配电源脚, 只有信号 + 地; FS03 CEP1.1 / CEP2.1 (VCC_CEP) 不接 (可能已是 5V, «d:cep_pin1»); JTAG 转换器 A 口参考电源取 LED 模组本地 2.5V, 不从接口取 («e:jtag_shift»); 两模组分开上电的规则见 «e:powerup»。',
                    '用户 09-15 D6; project_pov3d_adapter_board_and_uplink_bank', '已定 (用户 09-15 D6)'),
        'handshake': ('协议', '训练握手需要反向线', 'uplink_tx_frame: 退出训练要 rx_all_aligned (= 桥片 st_all_aligned) 连续稳定 TRAIN_HOLD = 64 个 pclk; 不能用 st_link_up (死锁)',
                      '契约已含 SB_ALIGNED (位置 62), SoC 侧外部下拉 2.2 kΩ + 释放 SB_RSTN 且读到 IDCODE 前不采信 (D4; sheet2 规定·单端边带, «e:sideband_level»); 验证板两端脚位见 sheet3 / sheet4; RTL 端口与门控待加 («d:rtl_readback»)。', 'uplink_tx_frame.v 文件头【训练握手】; uplink_rx_top.v', '已定 (契约包含)'),
        'soc_se': ('管脚·FS03', 'FS03 单端 (两面边带 + JTAG) 分配与上电态',
                   'DS1200 §2.8.2 表 2-6: bank33 强制下拉 D22 / A21, 强制上拉 33 球 (含 C22 / A17 / E20), 劈开対 R9 / R15 / R16 / R21; FS03 HSWAPEN (K16) = 0 ⇒ 其余用户 IO 配置期弱上拉; '
                   'DS1200 表 3-9 IPU @VCCIO 2.5V 83~153 µA; 表 3-11 LVCMOS25 门限; FS03 原理图 P17: 每根 CEP 线串 33 Ω (R187~R210, 排阻 4 路一只); '
                   'DS1200 §4.2 管脚定义注 (印刷页 62): ADC0P/N~ADC15P/N "可作复用 I/O 输入端口使用", 工作在 LVCMOS 时 ① 单一接口功能单元里 ADC 复用 I/O 和其他 PL I/O 不可混用 ② 对 clock duty 敏感时接口频率 < 30 MHz '
                   '③ 对端驱动 FAST 或 slew rate > 3.3 V/ns (LVDS 电平模式不涉及); pinmap: bank33 单端球 A16 ADC3P / A17 ADC3N / A21 ADC12P / A22 ADC12N / E19 ADC14P / E20 ADC14N, C22 / D22 与 bank11 无 ADC',
                   f'单端 {SOC_SUM["se_balls"]} 球全在改 2.5V 后的 CEP bank, LVCMOS25 直连, V3 无电平转换 (逐球见 sheet3 / sheet6)。排布 (F 步按 ADC 注与门控重排, 取代 P2 初排): '
                   '两面 JTAG 整组落 bank33 的 6 个 ADC 复用球 (TCK A21 / TMS E20 两面共用, TDI A16 / E19, TDO A17 / A22), 边带与 UART 全落非 ADC 球; '
                   '每面 SB_RSTN (W11 / W10) 与本面 SB_ALIGNED (U10 / U9)、SB_UART_B2S (U12 / U11) 同在 bank11 (门控同 bank); SB_UART_S2B 落 D22 / C22。'
                   '上电态: TCK = A21 强制下拉 ⇒ 配置期 TAP 不动; SB_RSTN 配置期弱上拉 × 桥侧 2.2 kΩ ≤0.34 V ⇒ 默认复位 (PULLTYPE 不得 PULLUP); JTAG_TDO PULLUP ⇒ 桥模组未上电读全 1, 只作"不在位"提示 (在位以 IDCODE = 0x0001281B 为准); '
                   'TCK PULLTYPE PULLDOWN (与 V2 A 口 2.2 kΩ 下拉同向, 静止低); TMS / TDI PULLTYPE PULLUP (与 V2 A 口 22 kΩ 上拉、E20 表 2-6 强制上拉 / A16·E19 配置期弱上拉同向, 静止高); '
                   'SB_ALIGNED NONE + V3 串 8.2 kΩ、2.2 kΩ 下拉在串阻的连接器侧 (D4); SB_UART_B2S 输入 NONE (V3 串 8.2 kΩ, 禁 PULLUP); SB_UART_S2B 输出 4 mA SLOW 且 PULLTYPE NONE (配置后不向未上电桥模组留弱上拉注入); 其余输出 8 mA SLOW。'
                   'V3 串 8.2 kΩ 的慢沿输入 (SB_ALIGNED / SB_UART_B2S) 全落 bank11 非 ADC 球 ✓。'
                   'ADC 注对本排布的未决项 (待安路确认, «d:adc_se»): ① ADC 复用球能否作 LVCMOS 输出 (TCK / TMS / TDI; 注原文只写"可作复用 I/O 输入端口"); '
                   '② 注 3 的摆率指焊盘处还是对端驱动器设置 —— 原文"对端器件的驱动要求使用 FAST 配置或 slew rate > 3.3V/ns", 按对端驱动器设置理解, V2 JTAG 转换器是快速 CMOS 输出, 满足; '
                   '若按焊盘处理解, 仅 FS03 板上 33 Ω × 约 20 pF 就只有约 1.4 V/ns, 任何方案都不满足, 不可能是此意; 故 TDO 落 ADC 球且 V3 不贴串阻 (0402 位默认 0 Ω); bank33 非 ADC 单端球只有 C22 / D22, 没有可挪的位置。'
                   'TCK ≤10 MHz 建议 (A 版 ≥15 MHz) 均 < 30 MHz ✓ (注 2)。'
                   '33 Ω 对单端是源端匹配 (有益)。',
                   'DS1200 §2.8.2 / §4.2 注 / 表 3-9 / 表 3-11; FS03 原理图 P17; pinmap.csv; dr1v90/jtag_load/fs03_io/out/cep_pin_table.tsv; 并行流程 P2 (初排)', '建议 (电平与上电态已核; ADC 复用注未决 «d:adc_se»; 未经 TD / 未上板)'),
        'jtag_share': ('JTAG·验证板', 'FS03 两面共用 JTAG_TCK / JTAG_TMS',
                       f'CEP 可作单端 {SOC_SUM["se_avail"]} (+ {L12} 待 toggle 2) vs 两面独立需求 16 (边带 8 + JTAG 8); 共用 TCK / TMS 需求 {SOC_SUM["se_balls"]}',
                       '验证板实现: TCK / TMS 各 1 球, V3 上分叉到两个连接器 (每支路 0402 串阻位, 默认 0 Ω), 每个连接器仍各 4 根 JTAG ⇒ 契约 D2 不变。约束: 两个 TAP 同步走状态, 不访问的一面 TDI 保持 1 (BYPASS), 两面不能并发; '
                       'SoC 侧 JTAG 主机按"两套 TDI / TDO 轮流用"实现; 分叉 SI 先低速验再升到契约 TCK; 一面 JTAG 短路拖垮两面; 运行期重载某面位流时 CEP1 上 JTAG 翻转紧邻面 A lane; '
                       '两面 V2 上下拉并联: TCK 下拉 1.1 kΩ (配置期 0.17 V, DR1 驱高 2.27 mA), TMS 上拉 22 kΩ ∥ 22 kΩ = 11 kΩ (DR1 驱低灌 0.23 mA); 一面 LED 模组未上电时 TMS 被分压到约 1.25 V, 此时 TCK ≤0.17 V 无沿, TAP 不动, 写明即可; '
                       'bank33 岛掉电时两只 TMS 上拉并联反灌 (2.625 − 0.5) / 11.03 kΩ = 193 µA ≤350 µA。'
                       f'两面独立 (方案 I) 原想 {L12} toggle 通过后用 Y9 / Y8 作面 B TCK / TMS, 但它们是 bank11 非 ADC 球, 与面 B TDI / TDO (bank33 ADC 复用球) 混用, 违反 DS1200 §4.2 注 1 ⇒ 须整组重排, 暂不可用 («d:adc_se»)。'
                       '不用"菊花链 + 共用 SB_RSTN" (破坏两面独立)。',
                       '并行流程 P2 / research:fs03; 用户 09-15 D2 / D3', '建议 (待验)'),
        'spin_sync': ('管脚·FS03', '光电开关 (转子索引) 输入',
                      'FS03 原理图 p16 (渲染图核): KEY2 = K18 ← R172 2.2 kΩ 上拉 VCC_3V3、C245 0.1 µF 到地、按键 K2; KEY3 = J18 (R176 / C246) 同构; KEY1 = L19 被 td_pov 作 rstn; bank32 VCCO = VCC_3V3; '
                      '现役 spin_sync_i = W6 LVCMOS33 无 PULLTYPE (td_pov fpga_pin.adc:35); DS1200 表 3-1 / 3-4 PL 输入上限',
                      'W6 在 D7 双面里是面 B LVDS, 且 bank11 改 2.5V 后 3.3V 传感器超输入上限 ⇒ 挪到 CEP 外 K18 (LVCMOS33, PULLTYPE NONE, 不受改板影响)。接法: 开集电极直接接 (R172 上拉, 勿上拉 5V); '
                      '推挽 3.3V 串 100 Ω; 推挽 5V 加 74LVC1G17 @3.3V。RC = 2.2 kΩ × 0.1 µF = 220 µs, 上升到 VIH 2.0 V 约 205 µs, 与 900 RPM × 360 片一片约 185 µs 同量级 ⇒ 建议拆 C245; 按 KEY2 产生假索引 ⇒ 可拆 K2。'
                      '传感器 3.3V 供电: 旧屏排线 / 接口板下线后另取 —— 从 LDO 插座小板 (或方案 S 引线) J1 路 D1 (肖特基) 之前的独立焊盘引出, 串 0.1 A 自恢复保险丝 (紧贴取电点), 供电线与地线单独走线、各占端子, 不经 V3 '
                      '(改板方案 README v2.2 §5.8 步骤 5, V3_design_inputs.md E3, 审查 v2 m4); 不取 D1 之后的 VIN_L、CEP pin1、J5 USB_VDD33。',
                      'FS03 原理图 p16; DS1200 表 3-1 / 3-4; td_pov fpga_pin.adc; 并行流程 P2 / research:fs03', '建议 (传感器输出类型未知, «d:spin_sensor»)'),
        'dr1_vi': ('电气·DR1 输入', 'DR1 PL 输入推荐上限 VCCIO+0.165 (2.5V 直连)',
                   'DS1200 表 3-4 推荐基本操作条件: PL I/O 直流输入 VI −0.2 ~ VCCIO+0.165 V; PL VCCIO @2.5V 2.375 / 2.5 / 2.625 V; TVCCIO 0.2~100 ms。表 3-1 (绝对最大): PL I/O 直流输入 −0.4 ~ VCCIO+0.3 V',
                   '桥 → SoC 单端 (SB_ALIGNED / SB_UART_B2S 由 GW5A VCCIO67 驱动, JTAG_TDO 由 V2 转换器 2.5V 口驱动) 进 DR1 2.5V bank: 标称 2.5 V < 2.665 V ✓; 两侧 VCCIO 各 ±5 % 反向最坏 2.625 V > 2.375 + 0.165 = 2.54 V ✘ '
                   '(«e:sideband_level» 用的是表 3-1 绝对最大 +0.3, 不超绝对值) ⇒ 推荐条件下两侧 2.5V 轨公差须 ≤ ±3.3 % (2.5 × (1 + t) ≤ 2.5 × (1 − t) + 0.165)。'
                   'FS03 侧按 DR1 VCCIO 闸门窗 2.40~2.60 V 放行 (改板方案 README v2.2 §5.9): 下限 2.40 V ⇒ 对端 VOH 须 ≤ 2.40 + 0.165 = 2.565 V (表 3-4), 对端 2.625 V 超 60 mV; '
                   'SB_ALIGNED / SB_UART_B2S 经 V3 串 8.2 kΩ 后焊盘被 IIH × Rs 限住, 不受此限; 对不串阻的 JTAG_TDO 仍有效。GW5A 核心板 VCC2P5 与 V2 本地 2.5V 精度未查。',
                   'DS1200 表 3-1 / 表 3-4', '待定 (核心板 VCC2P5 精度未查, «d:dr1_vi»)'),
    }
    assert set(C) == set(E_KEYS)
    R = []
    for key in E_KEYS:
        cat, item, val, concl, src, st = C[key]
        R.append(([ECODE[key], cat, item, val, concl, src, st], ['c', 'b', 'b', 't', 't', 't', st_style(st)]))
    return 'sheet5', '电气与机械约束', H, W, R


# ---------------------------------------------------------------- sheet6 CEP 全表
def cep_usage(impl):
    """v3 双面: 球 → (底色, 本接口用途, 状态)"""
    use = {}
    for f in ('A', 'B'):
        face = impl['faces'][f]
        for k in PAIR_ORDER:
            pr = face['pairs'][k]
            for pol, pos in zip('PN', CPOS[k]):
                ph = '' if k in PH1_KEYS else ', 阶段二'
                use[pr[pol]] = ('r' if pr['status'].startswith('待定') else 'y', f'面 {f} {sname(k)}_{pol} → 契约 {pos} (LVDS25{ph})', pr['status'])
        for grp in ('sideband', 'jtag'):
            for name, se in face[grp].items():
                if se.get('ball') is None:
                    continue
                d = SE_BY_NAME[name]['dir']
                txt = (f'两面共用 {name} → 两个连接器契约 {SE_POS[name]} (LVCMOS25, {d}; V3 分叉)' if se.get('shared_with')
                       else f'面 {f} {name} ↔ 契约 {SE_POS[name]} (LVCMOS25, {d})')
                use[se['ball']] = ('r' if se['status'].startswith('待定') else 'y', txt, se['status'])
    for r in impl.get('reserved') or []:
        for b in r['balls']:
            use[b] = ('r', r['use'], r['status'])
    ss = impl.get('spin_sync') or {}
    if ss.get('ball') in CEP_BY_BALL:
        use[ss['ball']] = ('y', '光电开关 SPIN_SYNC (不走契约)', ss['status'])
    return use


def sheet_cep():
    H = ['连接器.脚号', 'FS03 手册球位 (§16)', '原理图网名 (J11/J12 侧)', 'FS03 串阻 (位号 阻值 第几路)', 'FPGA 侧网名 (原理图)',
         '球位 (原理图链路)', 'bank', '管脚名', '差分对', 'P或N', '上电固定态 (DS1200 表 2-6)', 'GCLK', 'ADC 复用',
         '本接口用途 (v3 双面: 面 A = CEP1 · bank33 / 面 B = CEP2 · bank11)', '状态 (v3)', '备注']
    W = [10, 10, 12, 16, 16, 9, 6, 13, 9, 5, 22, 10, 9, 34, 22, 40]
    use = cep_usage(SOC_IMPL)
    v2_sb = {CEP_BY_PIN[cp]['ball']: f'v2 单面方案 A 此脚曾作边带 {n} (已失效)' for n, cp in SB_A.items()}
    v2_sb.update({CEP_BY_PIN[cp]['ball']: f'v2 单面方案 B 此脚曾作边带 {n} (已失效)' for n, cp in SB_B.items()})
    R = []
    for c in CHAIN:
        conn, pin = c['conn'], c['pin']
        if pin == 1:
            st = '已定 (不接, D6; pin1 电压 3.3V / 5V 待实测)'
            R.append(([f'{conn}.1', f'VCC_{conn}', f'VCC_{conn}', '—', 'VCC_3V3 经 L19/L18 (3A); VIN_5V0 经 L17/L16 (NC)', '—', '—', '—', '—', '—', '—', '—', '—',
                       '不接 (契约不走电源)', st, '手册: 1 脚默认 3.3V 输出, type-C 供电不够时可改磁珠作 5V 输入; 5V 灌入改法是否做过未记录 («d:cep_pin1»)'],
                      ['c', 'c', 't', 'c', 't', 'c', 'c', 't', 'c', 'c', 't', 't', 't', 't', st_style(st), 't']))
            continue
        if pin == 2:
            st = '建议 (G-P-N-G 地排)'
            R.append(([f'{conn}.2', 'GND', 'GND', '—', 'GND', '—', '—', '—', '—', '—', '—', '—', '—',
                       'V3 地条接回点 (该连接器唯一地脚)', st, '96 信号 : 2 地, 见 sheet5 «e:fs03_gnd»'],
                      ['c', 'c', 't', 'c', 't', 'c', 'c', 't', 'c', 'c', 't', 't', 't', 'y', st_style(st), 't']))
            continue
        b = c['ball']
        bank, name, pair, pol, alt = PM[b]
        gc, adc = alt_split(alt)
        state = pwr_state(b)
        if state == '随 HSWAPEN':
            state = '随 HSWAPEN (K16): 0 = 弱上拉 / 1 = 高阻'
        sp = False
        if bank == 33:
            _, sp = pair_pwr(PAIR_BALLS[pair]['P'], PAIR_BALLS[pair]['N'])
        fill, txt, st = use.get(b, ('t', '未用', '—'))
        notes = []
        ball_sty = 't'
        if c['manual'] != b:
            mn = PM.get(c['manual'])
            notes.append(f"手册写 {c['manual']}" + (f" ({mn[1]}, bank{mn[0]})" if mn else '') + f' 与原理图 {b} 不一致; 这一对是 GCLK 対, toggle 确认前不用 («d:cep27»)')
            ball_sty = 'risk'
        if sp:
            notes.append('上电劈开対 (表 2-6)')
        if c['label'] and c['label'] != b:
            notes.append(f"原理图 J 旁球位标注 {c['label']} 与网络链路不一致")
        if b in CUR_SIG_BY_BALL:
            notes.append(f'现役 uplink_pin.adc: {CUR_SIG_BY_BALL[b]} (LVDS18)')
        if b == SOC_POV_SPIN:
            notes.append('现役 td_pov spin_sync_i (光电开关, LVCMOS33) 在此球 ⇒ 挪到 ' + str((SOC_IMPL.get('spin_sync') or {}).get('ball')))
        elif b in PANEL_BALLS:
            notes.append('直驱屏 panel_pins_dr1.adc 用此球 (LVCMOS33; bank11 改 2.5V 后失效)')
        if b in v2_sb:
            notes.append(v2_sb[b])
        R.append(([f'{conn}.{pin}', c['manual'], c['net'], f"{c['res']} {c['rval']} 第{c['rch']}路", f"{c['bknet']} ({c['io']})",
                   b, str(bank), name, pair, pol, state + (' [劈开対]' if sp else ''), gc, adc, txt, st, '; '.join(notes)],
                  ['c', ball_sty, 't', 't', 't', ball_sty, 'c', 't', 'c', 'c', 'risk' if sp else 't', 't', 't', fill, st_style(st), 't']))
    return 'sheet6', 'DR1V90_FS03_CEP全表', H, W, R


# ---------------------------------------------------------------- sheet7 GW5A 连接器全表
def core_usage():
    use = {}
    for k, base in GW_MAP.items():
        for pol, pos in zip('PN', CPOS[k]):
            use[f'{base}_{pol}'] = ('建议', f'上行 {sname(k)} {pol} ← 契约 {pos}' + ('' if k in PH1_KEYS else ' (阶段二)'))
    for name, net in GW_SB.items():
        use[net] = ('建议', f'边带 {name} ↔ 契约 {SB_POS[name]} (LVCMOS25 2.5V)')
    for base in GW_SPARE:
        for pol in 'PN':
            use[f'{base}_{pol}'] = ('建议', '空置 (VCCIO45 余下, 不接契约)')
    for h in V45_HALF_FREE:
        use[h] = ('建议', '空置 (VCCIO45 半対; v2 曾放边带, v3 边带移到 2.5V 组)')
    for base in GUARD_ONLY:
        for pol in 'PN':
            use[f'{base}_{pol}'] = ('建议', '隔离対 (紧邻上行, 不作下行, 不接)')
    for k in DOWN_PAIRS:
        bank = FULL[k][0]['bank']
        for x in FULL[k]:
            if bank in (2, 6):
                use[x['net']] = ('待定', f'下行候选 (2.5V ELVDS); Bank{bank} {"Right" if bank == 2 else "Left"} 速率未证 («d:b2b6»)')
            else:
                use[x['net']] = ('建议', '下行候选 (2.5V ELVDS)')
    for h in DOWN_HALF:
        use[h] = ('建议', '下行单端候选 (2.5V)')
    return use


def sheet_core():
    H = ['连接器.脚号', '核心网名', 'CB-V2 官方底板用途 (参考)', 'FPGA 管脚', '球位', 'bank', '分区', 'VCCIO 组 (电压来源)', 'P或N', '対偶球',
         '対完整性', '差分能力', '配置复用 (UG985 口径)', 'GCLK / PLL (UG985 口径)', '本接口用途', '备注']
    W = [10, 14, 18, 10, 6, 6, 8, 30, 5, 8, 18, 34, 20, 22, 30, 40]
    PWR_NOTE = {
        'VCC3P3': ('底板 → 核心板 3.3V 输入; 核心板 VCCX / M0_VDDX / VCCIO10 由此供 (片内 100Ω 端接要求 VCCX = 3.3V)', '底板供 3.3V (干净)'),
        'VCCIO23': ('底板供 bank2/3 VCCIO (CB-V2: VCC3P3 经 FB5); 本规划 2.5V 作下行组 + 边带输入 (用户 09-15 D5, sheet5 «e:vccio23»)', '2.5V (V2 底板供, D5)'),
        'VCCIO45': ('底板供 bank4/5 VCCIO (CB-V2: VCC3P3 经 FB4); 核心板启动 flash、配置上拉、50M 晶振都在 VCC3P3 ⇒ 必须 3.3V (sheet5 «e:vccio45»)',
                    '3.3V 固定 (底板必须供 3.3V, 不可选)'),
        'VCCIO01': ('核心板自产: VCC1P5 经 FB4 (bank0/1 挂 DDR3) —— 底板勿另灌电源', '1.5V 固定, 底板只作测试点'),
        'VCCIO67': ('核心板自产: VCC2P5 经 FB3 —— 底板勿另灌电源', '2.5V 固定, 底板只作测试点'),
    }
    use_map = core_usage()
    R = []
    for c in CORE:
        pin = f"{c['conn']}.{c['pin']}"
        al = c['alias']
        if not c['net']:
            if al == 'GND':
                v = [pin, 'GND', '地', '—', '—', '—', '—', '—', '—', '—', '—', '—', '—', '—', '底板地', '']
                s = ['c'] + ['gray'] * 15
            elif al.startswith('VCC'):
                note, use = PWR_NOTE[al]
                v = [pin, al, '电源', '—', '—', '—', '—', al, '—', '—', '—', '—', '—', '—', use, note]
                s = ['c', 'b', 't', 'c', 'c', 'c', 'c', 't', 'c', 'c', 't', 't', 't', 't', 'y' if use.startswith('建议') else 't', 't']
            else:
                jt = next(j for j in JTAG if 'FPGA_' + j['tap'] == al)
                v = [pin, al, 'JTAG (CB-V2: P5 下载座)', f"{jt['fpga']} / {jt['tap']}", jt['ball'], '10', 'Right (专用)', 'VCCIO10 = VCCX = VCC3P3 (核心板 p3, 3.3V 固定)',
                     '—', '—', '—', '—', 'JTAG', '—',
                     f"程序加载 {jt['name']} ↔ 契约 {jt['pos']} (经 V2 电平转换 {jt['shift']}; 与 V2 下载器插座二选一)", 'UG714 表 3-5; 桥片位流不得回收成 GPIO (D3)']
                s = ['c', 'b', 't', 'c', 'c', 'c', 'c', 't', 'c', 'c', 't', 't', 't', 't', 'y', 't']
            R.append((v, s))
            continue
        net = c['net']
        if net.startswith('MIPI'):
            mate_name = c['fpga'][:-1] + ('N' if c['fpga'].endswith('P') else 'P')
            mate = next((x['ball'] for x in CORE if x['fpga'] == mate_name), '')
            v = [pin, net, al or '—', c['fpga'], c['ball'], 'MIPI 硬核', '—', '— (M0_VDDX = VCCX)', c['pol'], mate, '完整対',
                 'MIPI D-PHY RX 硬核专用脚 (DIO), 本表不作 LVDS / 通用 IO', '—', '—', '不可用', f"核心板原理图 p1 别名 {MIPI_ALIAS.get(str(c['pin']), '')}"]
            R.append((v, ['c', 't', 't', 'c', 'c', 'c', 'c', 't', 'c', 'c', 't', 't', 't', 't', 't', 't']))
            continue
        base = base_of(net)
        full = base in FULL
        grp = VG[c['bank']]
        gclk, cfg = gw_cfg_split(ug_cfg(c))
        if full:
            comp = '完整対'
            cap = {'VCCIO01': 'TLVDS 真差分; 本组 VCCIO 1.5V ⇒ 只能作差分输入 / 1.5V 单端, 不能 LVDS 输出',
                   'VCCIO23': 'TLVDS 真差分; 本组 2.5V (D5) ⇒ 差分输入 / TLVDS 输出 / ELVDS 输出均可',
                   'VCCIO45': 'TLVDS 真差分; 本组 3.3V 固定 ⇒ 差分输入 / TLVDS 输出 (VOS 1.125~1.375V) 可, ELVDS 输出不可',
                   'VCCIO67': 'TLVDS 真差分; 本组 2.5V 固定 ⇒ 差分输入 / TLVDS 输出 / ELVDS 输出均可'}[grp]
        else:
            comp = (f"半対 (対偶 {c['mate']} 未引出到连接器, 只能单端)" if c['mate'] else '半対 (UG324 封装里没有对偶脚, 只能单端)')
            cap = '单端'
        if net in use_map:
            ust, use = use_map[net]
        elif grp == 'VCCIO01':
            ust, use = '', '不用 (1.5V 组; CB-V2 接 LED / 按键)'
        else:
            ust, use = '', '未用'
        notes = []
        if cfg:
            notes.append(f'配置复用 {cfg}: 作普通 IO 需在 Dual-Purpose Pin 放开, 且确认核心板 MSPI 启动下不参与配置')
        dn = cfg_diff_note(c)
        if dn:
            notes.append(dn)
        if c['fpga'] == 'IOR14A':
            notes.append('核心板原理图 p4 符号标 IOR14A/ADCCLKTEST, UBGA324.json 与 UG985 此脚均无该功能 ⇒ 按普通 IO')
        if base == GW_MAP['CLK']:
            notes.append('建议上行转发时钟入口')
        if base == 'B4_B29':
            notes.append('対偶 P 端 T9 = 核心板 50M 时钟 CLK_G')
        if base == 'B4_B52':
            notes.append('対偶 P 端 N12 = MODE1 (R56 DNI/1K)')
        if not full and net in use_map and use.startswith('边带'):
            notes.append('半対单脚, 只放准静态 / 低速信号')
        use_sty = {'已定': 'g', '建议': 'y', '待定': 'r'}.get(ust, 't')
        v = [pin, net, al or '—', c['fpga'], c['ball'], str(c['bank']), part_of(c['fpga']), f'{grp} · {VG_NOTE[grp]}', c['pol'],
             c['mate'] if full else (f"{c['mate']} (未引出)" if c['mate'] else '— (封装无)'), comp, cap, cfg, gclk, use, '; '.join(notes)]
        R.append((v, ['c', 't', 't', 'c', 'c', 'c', 'c', 't', 'c', 'c', 't', 't', 't', 't', use_sty, 't']))
    return 'sheet7', 'GW5A_ACG525-CORE-V2连接器全表', H, W, R


# ---------------------------------------------------------------- sheet8 bank 预算
def sheet_budget():
    H = ['VCCIO 组 / bank / 核算', '包含 bank · 分区', '电压 (来源)', '引出完整対', '引出半対 (单端脚)', '带配置复用的対 (GW5A: UG985 口径) / 上电劈开対 (FS03)', 'GCLK / PLL 输入対',
         '上行占用 (GW5A 收 / FS03 发)', '边带占用 (FS03: 边带 + JTAG 单端)', '空置 / 隔离 / 预留', '下行可用: 対', '下行可用: 单端', '余量 / 结论', '状态']
    W = [22, 14, 30, 10, 20, 36, 34, 22, 40, 30, 9, 9, 64, 18]

    def cfgs(keys):
        return fmt_list([f"{k}({'/'.join(t)})" for k, t in cfg_pairs(keys)])

    def clks(keys):
        return fmt_list([f"{k}({'/'.join(t)})" for k, t in clk_pairs(keys)])

    R = [
        ['VCCIO01', '0 / 1 · Top', 'VCC1P5 经 FB4 (核心板自产; DDR3 在 bank0/1) —— 1.5V 固定', len(V01), fmt_list(grp_half('VCCIO01')), cfgs(V01), clks(V01),
         0, 0, '—', 0, 0, '1.5V 不满足 TLVDS 输出 (2.5/3.3V) 与 ELVDS (2.5V) ⇒ 不给接口用; CB-V2 上接 LED / 按键', '已定'],
        ['VCCIO23', '2 · Right (IOR) / 3 · Bottom (IOB)', '底板经 P1.5/7 供 —— 2.5V (用户 09-15 D5; CB-V2 为 3.3V)', len(V23), fmt_list(grp_half('VCCIO23')), cfgs(V23), clks(V23),
         0, f'2 (完整対 {SB_PAIRS[0]} 两脚: SB_RSTN / SB_UART_S2B 输入)', f'隔离 {len(GUARD_ONLY)}: ' + ', '.join(GUARD_ONLY) + ' (紧邻上行 P1.29/30; N 端 DOUT 悬空)',
         len(V23) - len(DOWN_GUARD), len([h for h in DOWN_HALF if VG[CORE_BY_NET[h]['bank']] == 'VCCIO23']),
         f'下行 ELVDS 组 + 边带输入。原隔离対 {SB_PAIRS[0]} 改作边带 (紧挨上行的 P1.32 放准静态 SB_RSTN)。bank2 13 対在 Right 分区, 速率未证 («e:b2b6»)。VCCIO23 是一路电源, bank2 与 bank3 不能分压。'
         'B2_R7 / B2_R9 与 JTAG P1.94~100 面对面 (sheet4), 作高速下行有串扰风险, 本核算未扣。', '建议'],
        ['VCCIO45', '4 · Bottom (IOB) / 5 · Bottom (IOB)', '底板经 P1.6/8 供 —— 3.3V 固定 (核心板启动电路, «e:vccio45»)', len(V45), fmt_list(grp_half('VCCIO45')), cfgs(V45), clks(V45),
         f'20 (阶段一 14 = bank4 {GW_PH1_BANK[4]} + bank5 {GW_PH1_BANK[5]})', '0 (v2 放这里的 4 根边带已移到 2.5V 组)',
         '空置 2 対: ' + ', '.join(GW_SPARE) + ' (B5_B8_P = SSPI SO, 悬空勿接地); 空置 4 半対: ' + ', '.join(V45_HALF_FREE), 0, 0,
         f'上行接收组: 22 対用 20, 余 2 (都带配置复用); 上行対中 {len(UL_CFG)} 対带配置复用 (SSPI 类放阶段二)。3.3V 组不能 ELVDS 下行, 也不能放 2.5V 边带 (3.3V 输出超 DR1 2.5V bank 输入上限 2.8 V)。', '建议 (电压已定)'],
        ['VCCIO67', '6 · Left (IOL) / 7 · Top (IOT)', 'VCC2P5 经 FB3 (核心板自产) —— 2.5V 固定', len(V67), fmt_list(grp_half('VCCIO67')), cfgs(V67), clks(V67),
         0, f'2 半対单脚: {", ".join(SB_HALF)} (SB_ALIGNED / SB_UART_B2S 输出)', '—', len(V67), len([h for h in DOWN_HALF if VG[CORE_BY_NET[h]['bank']] == 'VCCIO67']),
         '下行 ELVDS 组 + 边带输出 (本组由核心板固定 2.5V, 不随 V2 的 VCCIO23 选择变)。bank6 8 対在 Left 分区, 速率未证 («e:b2b6»)。另有 MIPI 硬核 5 対 (P2.50、P2.52~60) 不计入, 不可用。', '建议'],
        ['MIPI 硬核', '—', 'M0_VDDX = VCCX', 5, '0', '—', '—', 0, 0, '—', 0, 0, 'D-PHY RX 专用脚, 不作 LVDS', '已定'],
    ]
    tot_full = len(V01) + len(V23) + len(V45) + len(V67)
    R.append(['合计', '—', '—', f'{tot_full} (+MIPI 5 = {tot_full + 5})', sum(len(grp_half(g)) for g in ('VCCIO01', 'VCCIO23', 'VCCIO45', 'VCCIO67')), '—', '—',
              20, 4, f'{len(GW_SPARE)} 空置対 + {len(V45_HALF_FREE)} 空置半対 + {len(GUARD_ONLY)} 隔离対', len(DOWN_PAIRS), len(DOWN_HALF),
              f'2.5V 下行可用 = VCCIO23 {len(V23) - len(DOWN_GUARD)} + VCCIO67 {len(V67)} = {len(DOWN_PAIRS)} 対 + {len(DOWN_HALF)} 单端 ({", ".join(DOWN_HALF)}); '
              f'2.5V 边带 = {SB_PAIRS[0]} 两脚 + {len(SB_HALF)} 个半対; JTAG 走 bank10 专用脚, 不占 IO', '已定 (计数)'])
    R.append(['上行核算', '45', '—', '需求: 20 対 (18 数据 + 1 校验 + 1 时钟)', '—', '—', '—', 20, 0, '—', '—', '—',
              '20 ≤ VCCIO45 22 対 ⇒ 够, 余 2 (空置)。零隔离 (sheet5 «e:b2b»)。边带不在本组 (见 边带核算)。', '建议'])
    R.append(['边带核算 (2.5V)', '23 + 67', '—', '需求: 4 单端 LVCMOS25 (桥 → SoC 输出 2 + SoC → 桥 输入 2); JTAG 4 根走 bank10 专用脚, 不占 IO', '—', '—', '—', 0, 4, '—', '—', '—',
              f'输出 2 根 → VCCIO67 半対 {", ".join(SB_HALF)} (固定 2.5V); 输入 2 根 → VCCIO23 原隔离対 {SB_PAIRS[0]}。代价: 下行单端候选 4 → {len(DOWN_HALF)}, 核算 A 余量 {NA_V2[1]} → {NA[1]} 対; 下行差分対数不变 ({len(DOWN_PAIRS)})。'
              f'备选 (未采用): 4 根都用 2.5V 半対 ⇒ 下行单端 0, 核算 A 余 {need(37, 9, len(DOWN_PAIRS), 0)[1]}, 且桥 → SoC 输出会落 VCCIO23 (V2 跳 3.3V 时有 3.3V 进 SoC 的风险); '
              '4 根都放隔离対 B3_B65 / B3_B71 ⇒ 要用 B3_B65_N (DOUT 配置脚) 且 UART 紧邻上行。', '建议'])
    R.append(['下行核算 A', '23 + 67', '—', '需求: 36 数据対 + 1 时钟対 (板上扇出 IC) + 9 单端', '—', '—', '—', '—', '—', '—', NA[0], len(DOWN_HALF),
              f'需 36 + 1 + 拆 {NA[2]} 对补 {9 - len(DOWN_HALF)} 单端 = {NA[0]} 対 ≤ 可用 {len(DOWN_PAIRS)} 対 ⇒ 余 {NA[1]} 対: 够 (v2 余 {NA_V2[1]}; 前提 B2/B6 可用, 见核算 C)', '建议'])
    R.append(['下行核算 B', '23 + 67', '—', '需求: 36 数据対 + 12 时钟対 (FPGA 直出) + 9 单端', '—', '—', '—', '—', '—', '—', NB[0], len(DOWN_HALF),
              f'需 36 + 12 + {NB[2]} = {NB[0]} 対 > 可用 {len(DOWN_PAIRS)} 対 ⇒ 缺 {-NB[1]} 対 (收回隔离対 {"/".join(GUARD_ONLY)} 仍缺 {-NB[1] - len(GUARD_ONLY)}): 不够 ⇒ 用扇出 IC («d:down_clk»)', '待定'])
    R.append(['下行核算 C', '3 + 7 (剔除 2 / 6)', '—', '剔除 Bank2 / Bank6 的差分, 单端仍放 B2/B6; 需求同 A', '—', '—', '—', '—', '—', '—', NC[0], '—',
              f'bank3 + bank7 可用 {len(DOWN_TB)} 対 (已扣隔离) < 37 ⇒ 缺 {-NC[1]} 対 (收回隔离対 {"/".join(GUARD_ONLY)} 缺 {-NC[1] - len(GUARD_ONLY)}); 单端 9 根放 B2/B6 (低速) 够。⇒ B2/B6 速率是承重未证项 («d:b2b6»)', '待定'])
    R.append(['下行核算 D', '3 + 7 (剔除 2 / 6)', '—', '剔除 Bank2 / Bank6, 需求同 B (12 时钟直出)', '—', '—', '—', '—', '—', '—', ND[0], '—',
              f'{len(DOWN_TB)} 対 < 48 ⇒ 缺 {-ND[1]} 対: 不够', '待定'])
    R.append(['备用: 3.3V 伪差分', '23', '—', 'VCCIO23 改 3.3V, bank2/3 用 LVCMOS33D + 外部 5R 网络', '—', '—', '—', '—', '—', '—', len(V23) - len(DOWN_GUARD), '—',
              'DS1103 表 2-6: LVCMOS33D 输出 VCCIO 3.3; 电阻网络沿用 EG4 现役 5R (RS 150 / RP 140 / Rpd 430, 共模 1.203 V, 在 ICND2260 VIC 1.1~1.3 V 内)。対数不变 (24 + VCCIO67 21 = 45), '
              f'代价: 每対 5 只电阻 ({(len(V23) - len(DOWN_GUARD)) * 5} 只)、LVCMOS33D 速率本包未查; VCCIO23 一路电源, bank2 / bank3 不能分压; 不解决 B2 未证项。仅作 VCCIO23 不能用 2.5V 时的退路; 且与 D5 冲突 (VCCIO23 已定 2.5V, 边带输入 B3_B71 在本组, 需另找边带位置)。', '待定 (备用)'])
    # ---- SoC 侧 (FS03, D7 双面; 前提两 bank 改 2.5V)
    g33 = [p for p in B33_PAIRS if is_gclk_pair(p)]
    b11 = sorted({v[2] for v in PM.values() if v[0] == 11}, key=lambda p: int(p[1:-3]))
    g11 = [p for p in b11 if is_gclk_pair(p)]
    ses = [(f, n, se) for f in 'AB' for g in ('sideband', 'jtag') for n, se in SOC_IMPL['faces'][f][g].items()]

    def se_names(b):
        return '/'.join(sorted({('AB.' if se.get('shared_with') else f'{f}.') + n for f, n, se in ses if se['ball'] == b}))

    se33 = sorted({se['ball'] for _f, _n, se in ses if PM[se['ball']][0] == 33})
    se11 = sorted({se['ball'] for _f, _n, se in ses if PM[se['ball']][0] == 11})
    n_se, avail, rsv = SOC_SUM['se_balls'], SOC_SUM['se_avail'], SOC_SUM['rsv']
    st_f = '建议 (前提: 改 2.5V 的改板方案待定)'
    R += [
        ['FS03 bank33 (CEP1, 面 A)', '33 · PL', 'ADJ_BANK33 ← J2 pin2: 改 2.5V (D7; 改板方案待定; 原跳线只有 3.3V / 1.8V)', len(B33_PAIRS), '0',
         f'上电劈开 {len(SPLIT33)}: ' + ', '.join(SPLIT33), fmt_list(g33), '20 (面 A LVDS25 发; 阶段一 14)',
         f'{len(se33)} 单端 (劈开対): ' + ', '.join(f'{b} {se_names(b)}' for b in se33), '—', '—', '—',
         f'24 対 = 面 A LVDS 20 + 劈开 {len(SPLIT33)} 対作单端 {len(se33)} ⇒ LVDS 余量 0; 上电 ~90 ms {len(A_UP)} 対 P/N 同上拉 + {len(A_FREE)} 対随 HSWAPEN; '
         'VCCIO_33 属"必须供电" (DS1200 表 3-5), 改板模块掉线则配置异常', st_f],
        ['FS03 bank11 (CEP2, 面 B)', '11 · PL', 'ADJ_BANK11 ← J1 pin2: 改 2.5V (D7; 改板方案待定)', len(b11), '0', '—', fmt_list(g11), '20 (面 B LVDS25 发; 阶段一 14)',
         f'{len(se11)} 单端 (余量対 {", ".join(B_SPARE)}): ' + ', '.join(f'{b} {se_names(b)}' for b in se11), f'预留 {L12} (CEP2.7/8, toggle 未验; 作 V3 J_TP11 闸门测点, 各串 10 kΩ 引到排针)', '—', '—',
         f'24 対 = 面 B LVDS 20 + 余量 {len(B_SPARE)} 対作单端 + 预留 1 ⇒ LVDS 余量 0 (能顶替 Error-8221 的只有 {L12}); 20 対上电随 HSWAPEN; VCCIO_11 可选择性供电 (表 3-5)', st_f],
        ['FS03 bank32 (CEP 外)', '32 · PL', 'VCC_3V3 固定 (不受 J1 / J2 改板影响)', '—', '—', '—', '—', 0, f'1 单端: {SOC_SUM["spin"]} 光电开关 SPIN_SYNC (KEY2; 不走契约)',
         '备选 J18 (KEY3)', '—', '—',
         'CEP 外能接 3.3V 单端的只有按键焊盘: KEY1 = L19 (td_pov rstn 占用) / KEY2 = K18 / KEY3 = J18, 各带 2.2 kΩ 上拉 + 0.1 µF; LED 脚经 LED + 2.2 kΩ 只能输出; MIPI CAM_* 为 1.8V (并行流程 research:fs03)', '建议'],
    ]
    for nm, need_, stx in (('S 两面共用 TCK / TMS, 光电 CEP 外 (本表)', n_se, '建议 (本表采用)'), ('S+ 共用 TCK / TMS, 光电上 CEP', n_se + 1, '待定 (备选)'),
                           ('I JTAG 两面独立, 光电 CEP 外', n_se + 2, '待定 (备选; 须 L12 toggle)'), ('I+ JTAG 两面独立, 光电上 CEP', n_se + 3, '待定 (不够)')):
        R.append([f'FS03 单端核算 {nm}', '33 + 11', '2.5V (改板后)',
                  '需求: 两面边带 8 + JTAG ' + ('6 (TCK / TMS 共用)' if nm.startswith('S') else '8') + (' + 光电 1' if '上 CEP' in nm else ''),
                  '—', '—', '—', '—', need_, '—', '—', '—',
                  f'CEP 可作单端 {avail} (劈开 {2 * len(SPLIT33)} + bank11 余 {2 * len(B_SPARE)}) ⇒ 余 {avail - need_}; {L12} toggle 通过 (+{rsv}) ⇒ 余 {avail + rsv - need_}', stx])
    assert [avail - n for n in (n_se, n_se + 1, n_se + 2, n_se + 3)] == [0, -1, -2, -3] and avail + rsv - n_se - 3 == -1 and len(g33) == 4
    out = []
    for v in R:
        st = v[-1]
        out.append(([str(x) for x in v], ['b', 'c', 't', 'c', 't', 't', 't', 't', 't', 't', 'c', 'c', 't', st_style(st)]))
    return 'sheet8', 'bank预算_GW5A模块与FS03', H, W, out


# ---------------------------------------------------------------- sheet9 待定事项
def sheet_tbd():
    H = ['编号', '事项', '影响', '建议', '谁定', '关联位置', '状态']
    W = [6, 30, 52, 70, 14, 24, 8]
    T = {
        'freeze': ('契约冻结项确认 (本表起草)',
                   f'契约是永久接口: 位置号 / 脚序 ({TOTAL_POS} 芯)、连接器形态与型号、TCK 频率、UART 波特率与回读帧 —— 定了两块模组都按它画, 事后改要两边一起改',
                   '逐项确认 sheet2。用户 09-15 已定: 20 対 / 角色 / LVDS25 / 100 Ω / G-S-S-G / 桥侧端接 / 800 Mbps (D1)、两面相同 (D2)、JTAG 4 根 (D3)、边带 4 根与 2.2 kΩ 下拉 (D4)、单端 2.5V (D5)、上电与 IDCODE 规则 (D6); '
                   '其余 (脚序、上下拉阻值、TCK 频率) 为本表建议; 契约无备用位, 是否留 1~2 个 NC 备用位待定', '用户 + 硬件', 'sheet2 全表'),
        'rtl_nlane': ('RTL: lane 数参数化 13 → 19 物理 lane', '阶段二要 18 数据 + 1 校验; 现 RTL 多处写死 13 / 12',
                      'uplink_rx_defs.vh UL_NLANE 13 → 19; bridge_defs.vh BR_NLANE_DATA 12 → 18、BR_LANE_CHK 12 → 18、BR_PIX_PER_BEAT 24 → 36、BR_GRP_PER_BEAT 8 → 12、BR_BEAT_PER_SLOT 3 → 2 (beat_phase 0/1); '
                      'BR_CHECK_DEFS 里 UL_NLANE != 13 的断言要改; ul_dispatch 链号 = 12·beat_phase + g; chk_early CRC 覆盖 36 字节; uplink_tx_frame / uplink_tx_top 的 NLANE; SoC .adc 与 GW5A .cst 按 sheet3 / sheet4 出 19 + 1 対',
                      'RTL', 'sheet2 逻辑角色列'),
        'rtl_framemiss': ('RTL: FRAME_MISS 判据', 'uplink_rx_top 参数 FRAME_MISS = 4 (连丢 4 个帧头判丢帧并请求重训练); lane 数与 beat 结构变化后, 帧头检测与丢帧窗口要重核',
                          '随 13 → 19 参数化一起改; 仿真注入"单 lane 失锁"与"帧头丢失"两种故障看判据', 'RTL', 'uplink_rx_top.v (rtl_v3 / rtl_x8) 第 48 / 62 行'),
        'rtl_fifo': ('RTL: 800 Mbps 下分发 FIFO 加深',
                     f'bridge_defs.vh §6 的 BR_FIFO_SLOTS = 384 按 12 lane 9.45 Gbps 算 (链路比 tx 慢, 靠预存)。18 lane 时链路比 tx 快, 按 §6 通式估峰值积压 ≈ 1728 × (1 − t_link / t_tx): '
                     f'800 / 700 / 600 Mbps ≈ {FIFO[800]} / {FIFO[700]} / {FIFO[600]} 字槽 (dclk 150 MHz, DR1 满速突发; 估算)',
                     f'800 Mbps 时深度 ≥ {FIFO[800]} (如 768) 或 DR1 按 ≤700 Mbps 等效速率发; 用 tb_ul_dispatch 真实节拍复测占用峰值', 'RTL', 'bridge_defs.vh §6'),
        'rtl_readback': ('RTL: 回读口端口; SB_ALIGNED 采信与 IDCODE 门控; SoC 侧 JTAG 主机',
                         '契约有 SB_ALIGNED / SB_UART_B2S / SB_UART_S2B / SB_RSTN, 但桥片顶层只有 dbg_st 占位, SoC 侧没有 UART / rx_all_aligned 引脚 / bridge_rstn 输出; '
                         'SB_ALIGNED 只在桥片已配置且已出复位时有意义 —— 外部下拉只保证桥片不驱动时读 0, 而 uplink_tx_frame 见 rx_all_aligned 连续 TRAIN_HOLD = 64 拍为 1 即出训练',
                         '桥片顶层加 UART TX/RX + st_all_aligned 输出; SoC 侧加 UART RX/TX + bridge_rstn 输出 + rx_all_aligned 输入; 回读帧格式另定。'
                         'SoC 侧门控: rx_all_aligned = SB_ALIGNED 两级同步 & bridge_rstn 已释放 & 已读到桥片 IDCODE (D4), 门控不满足时强制为 0; SB_ALIGNED 长时间不起时上报"桥片未配置 / 未对齐", 不在训练态无限等; '
                         'SoC 侧 LVDS / SB_RSTN / SB_UART_S2B 输出使能受 IDCODE 门控 (D6); SoC 侧加 JTAG 主机 (PL 移位器 + 位流下发; A 版 GW5A-25 要 TCK ≥15 MHz 时不能软件 bit-bang, «d:bridge_ver»); '
                         '桥侧 SB_RSTN 为低时 SB_ALIGNED / UART TX 不驱高 (建议, 验证期按强制执行; 桥片 flash 镜像同样要满足 «d:core_flash»); SoC 侧 JTAG 主机每次访问先发 ≥5 个 TMS = 1 的 TCK 复位 TAP, 访问结束再发 ≥5 个 TMS = 1 回 Test-Logic-Reset (TDO 残余风险, «d:soc_inject»), '
                         'IDCODE 轮询不设失败超时 (只上报), 能等 LED 模组后上电; 在位判据 = IDCODE 精确等于 0x0001281B, TDO 读到全 1 只作"不在位"提示; '
                         'SB_ALIGNED / SB_UART_B2S 输入 PULLTYPE = NONE, 读到 IDCODE 之前不采信 UART RX; 台架下载器模式的调试旁路 («d:jtag_shift_part»)',
                         'RTL', 'sheet2 位置 62~66 / 68~72; sheet2 规定·单端边带 / 规定·上电'),
        'proto_12bit': ('协议: 12-bit 定义; 8-bit 降速档 700 / 600 Mbps 是否允许',
                        f'UL_WORDBITS = 8; 12-bit 18 lane 占用 {OCC12} % 只能 800 Mbps; 00_目标电路总览.md 写 EG4A20BG256 装不下 12-bit; '
                        f'契约 (sheet2 规定2) 只冻结 800 Mbps 标称, 8-bit 18 lane 降到 700 / 600 Mbps (占用 {OCC[700]} / {OCC[600]} %) 可换 DR1 发端时序与 SI 余量, 但收端训练与分发 FIFO 要按允许的最低档算',
                        '先把 8-bit 18 lane 定为阶段二默认; 12-bit 的字对齐单位、训练码、字节映射另立协议, 与桥片选型一起定; 降速档是否作契约允许档与 12-bit 一起定 (FIFO 深度见 «d:rtl_fifo»)',
                        '用户 + RTL', 'sheet2 规定2; sheet5 «e:occupancy»'),
        'ph1_unused': ('阶段一未用的 UL_D[17:12] 6 対: 发端驱不驱', '物理接通但现 RTL 13 lane 不例化: 发端不驱动 ⇒ 收端片内 100 Ω 上差分≈0、易被串扰翻转 (不影响阶段一逻辑, 但这几对上板量不到有意义的东西)',
                       '阶段一 SoC 侧对这 6 対输出固定 0x35 训练码 (不进协议), 桥侧不例化或只计数; V2 / V3 照常布线', 'RTL + 硬件', 'sheet2 UL_D[17:12]'),
        'soc_dual': ('FS03 双面实现 (D7) 上板前未决: TD 试综合 / JTAG 共用 / 余量',
                     f'SoC 侧双面已合并 (sheet3 / sheet6 / sheet8): 面 A bank33 20 対 (时钟 {SOC_SUM["clk"]["A"]}) + 面 B bank11 20 対 (时钟 {SOC_SUM["clk"]["B"]}) + 单端 {SOC_SUM["se_balls"]} 球 (两面共用 TCK / TMS) '
                     f'+ 光电开关 {SOC_SUM["spin"]}, CEP {SOC_SUM["cep_io"]} 个 IO 全部分配。未决: ① 两 bank 40 対 ODDRx2 + LVDS25 合法性 (Error-8221) 与两 bank 同时 400 MHz pclk 时序未经 TD, 两面 LVDS 余量都是 0; '
                     f'② 两面共用 TCK / TMS 是否接受 (不共用须 {L12} toggle 且另受 ADC 复用注约束, 须整组重排); ③ 现役 uplink_pin.adc (tools/gen_uplink_adc.py 生成) 与 uplink_tx_top.v (200 MHz) 需按双面重出; '
                     '④ 单端排布受 DS1200 ADC 复用注约束, 输出 / 摆率未决 («d:adc_se»); 以上全部以两 bank 改 2.5V 为前提 («d:fs03_25v»)',
                     f'V3 定稿前: 用 TD 一次综合两面 20 + 20 対 .adc (判据 PackReg = DDRX2 计数 == 实例数) 并跑两 bank 400 MHz 时序; 报错 1 対以内用 {L12} 顶替 (同一次烧 toggle 位流验 CEP2.7), '
                     '超过 1 対则重排或降对数 (顶替后 V3 改版、bank11 闸门改 SENSE11); JTAG 主机按两套 TDI / TDO 轮流实现, 分叉先低速验再升到契约 TCK', '用户 + 硬件 + RTL (TD)', 'sheet3; sheet6; sheet8 FS03 行; 脚本 SOC_IMPL'),
        'fs03_25v': ('FS03 两个 CEP bank VCCIO 改 2.5V 的改板实施 (D7 已定要改; 方案见 README v2.2)',
                     '改板方案见 dr1v90/fs03_mod/README.md v2.2 (未实施; V3 设计输入见 dr1v90/fs03_mod/V3_design_inputs.md): J1 / J2 各一路: 肖特基 + TPS73625DBVR + 0.2 Ω 采样 + 10 µF + 1 kΩ 泄放; '
                     '插座小板 (方案 P) 或引线直焊 (方案 S); 每 bank 设计 200 mA, > 300 mA 停 (公用轨不能改分压、无空贴位)。'
                     '独立审查 v2 = 0 critical / 3 major / 7 minor, v2.1 已给落实做法 (M1 预插测试线 / M2 J_TP11 + SENSE33 + TP_TDO_A / M3 插座小板·地线双线 + V3 串阻); v2.1 复核 (R3, v2.2 已落实) 另提 J_TP 电阻隔离与焊后断电阻值检查。'
                     'sheet3 / sheet6 全部 SoC 分配以此为前提',
                     '① 按 README v2.2 §5.9 分阶段实施 (带电读数一律断电预插测试线; 焊接或插上后先做断电阻值检查); ② 动手前 (阶段 −1): SW1 拨 JTAG 并拔 TF 卡; 物理拆除 CEP1 上 CB-V2 JTAG 飞线 (CEP1.4 / 5 / 15 / 18 → P5; '
                     '留着则 GW5A TDO 3.3 V 进 2.5 V bank 超绝对最大 2.8 V, 约 6 mA 注入), CEP1 / CEP2 全空后才上电; jtag_load 台架位流 (bank33 LVCMOS33) 不得在 2.5V 状态加载; 实测 CEP pin1 («d:cep_pin1»); '
                     '③ FS03 上电 → 闸门 (J_TP11、SENSE33、TP_TDO_A) → 加载 LVDS25 位流 (LVDS / SB_RSTN / SB_UART_S2B 不使能) → LED 模组上电 → SoC 轮询 IDCODE → 读到后使能该面; 断电: LED 模组先断, FS03 最后断电 (sheet2 规定5 / sheet5 «e:powerup»); '
                     '④ 画 V3 前按 V3_design_inputs.md 落实闸门测点 (J_TP11 各串 10 kΩ、TP_TDO_A 47 kΩ 隔离、SENSE33 10 kΩ)、对端 → DR1 串阻 (SB 线 8.2 kΩ, TDO 不串) 与 J1 / J2 开窗, 见 sheet3 规划·V3 / 规划·单端; '
                     '⑤ 改后该 FS03 不能直驱 3.3V 屏, 与 jtag_load 台架 (J2 = 3.3V) 互斥; ⑥ 中心抽头量 VOCM ≈1.25 V',
                     '硬件 (上板)', 'sheet5 «e:adapt» / «e:jumper»'),
        'res33': ('FS03 CEP 线上 33Ω 串阻处置', '96 根 CEP 信号都串 33Ω; 对 800 Mbps LVDS 有阻抗台阶 / RC 低通; 改 2.5V 后改板流程估 FPGA 焊盘处 VOH ≈1.54 V (表 3-14 VOH ≤1.5 V, 估算); 与记忆库"排阻为编造"冲突',
                  '① 先量实装阻值: 断电, 万用表电阻档量 CEP 排针脚 ↔ 对应排阻 FPGA 侧焊盘 (R187~R210 逐路), ≈33 Ω 即实装 (不用"上电驱高、排针挂 100 Ω"法: 需 25~33 mA, '
                  '超过 DR1 最大 16 mA 驱动档, DS1200 表 3-11 的 VOH 只保证到额定 IOH, 驱动塌落与串阻压降分不开); ② 若为 33Ω, 选一个面的排阻 (面 A: R187~R198 / CEP1; 面 B: R199~R210 / CEP2) 换 0Ω 作对照变量, '
                  '眼图 / 误码两态比较后再定; 排阻 4 路一只、与单端混用, 换 0Ω 连带同只排阻上的单端 (对低速单端无害)',
                  '硬件', 'sheet5 «e:swing33»; sheet6 串阻列'),
        'b2b6': ('GW5A Bank2 / Bank6 (Left/Right) 速率实测', f'DS1103 表 2-11 注[3] 只说"偏低"无数字; 下行规划 {len(DOWN_B26)} 対在 B2/B6, 剔除后缺 {-NC[1]} 対 (核算 A) —— 下行规划的承重未证项',
                 '在 bank2 / bank6 与 bank3 / bank7 上对照跑 ELVDS 300 Mbps 输出与 TLVDS 800 Mbps 输入 PRBS (CB-V2 上 bank2/3 为 3.3V, 测 2.5V ELVDS 要改 FB5 供电或等 V2); 不达标则下行减对数 (扇出 IC) 或放另一颗 FPGA',
                 '硬件 + RTL', 'sheet8 下行核算 C / D'),
        'bridge_ver': ('TCK 频率与桥片 GW5A-25 A / B 版本',
                       'UG714-1.0.6: A 版芯片 TCK 不得低于 15 MHz (其他版本无下限); 契约口径 TCK ≤10 MHz (建议) 对 A 版不可用; IDCODE A / B 相同, 读 ID 分不出; 本包 UG714-1.0.1 无此注',
                       '① 看核心板 GW5A 丝印 Date Code 判版本 (并行流程 research:gw5a 引 DS1103-1.0.9 §4.2 注[2]: 第 5 位为版本号, 本表未复核); ② 若为 A 版: 契约 TCK 改为窗口 (如 15~25 MHz, 依转换器与线长定), '
                       'SoC 侧须用 PL JTAG 移位器, 转换器速率与连接器 SI 按 ≥15 MHz 核; ③ 若为 B 版: 保留 ≤10 MHz; ④ 目标板桥片若不是 GW5A, 按其手册重定。TCK 频率定之前契约只冻结"4 根 / 方向 / 2.5V"',
                       '用户 + 硬件 + RTL', 'sheet2 JTAG_TCK; sheet5 «e:jtag»'),
        'jtag_shift_part': ('V2 JTAG 电平转换器选型与下载器二选一',
                            'D5 定了"固定方向、带 Ioff 的双电源转换器", 型号未选; A 口 VIH @VCCA 2.5V、Ioff 最大值 (VCCA = 0、VI ≤2.625 V: DR1 → V2 方向 TCK / TMS / TDI 在 V3 上不串阻, V2 掉电时只靠它限流)、传播延迟 (TCK → TDO 往返经两级转换, 限制最高 TCK) 未查手册; 下载器模式下 SoC 读不到 IDCODE, 按 D6 不驱 LVDS',
                            '选 SN74LVC1T45 ×4 / LVC2T45 ×2 或带 OE 的 4 位固定方向件 (目标板 TDO 路带 OE、由 SoC 侧供电的信号门控, «d:tdo_oe»), 查手册核 VIH / Ioff / 延迟 (本包无手册); 0Ω 选择或 2×3 跳线; 下载器模式时 SoC 固件提供调试旁路 (台架专用, 不读 IDCODE 也允许驱 LVDS)',
                            '硬件 + RTL', 'sheet4 规划·JTAG; sheet5 «e:jtag_shift»'),
        'gw_hclk': ('GW5A 转发时钟入口与 HCLK / PLL 路径', '上行 20 対跨 bank4 / bank5; 转发时钟直驱 HCLK → IDES8.FCLK 或经 BPLL 再生, 均未综合',
                    'V2 开画前用 Gowin 工具按 sheet4 脚位综合一次 (TLVDS_IBUF × 20 + IDES8 × 19, 时钟 B4_B33 GCLKT_9A / BPLL_T_IN1); 不行换 B4_B35 (GCLKT_8) 或 B5_B26 (GCLKT_9B), 同步调 lane 分配; '
                    '同一次定下 V2 上 P/N 对调的 lane (RTL 在 IDES8 输出、lane 对齐逻辑前取反) 与 UL_CLK 是否允许反相, 写进 .cst / RTL 参数 (P1 对内 N 小脚号、P2 P 小脚号)',
                    'RTL (Gowin)', 'sheet4 UL_CLK 行 / 规划·P/N 脚序'),
        'gw_cfgpins': ('GW5A 配置复用対作上行输入', f'VCCIO45 22 対里 8 対带 CPU 并口 / SSPI / EMCCLK 复用 (UG985 口径; IDE json 另列 B5_B4 的 SDA / SCL), 上行用了 {len(UL_CFG)} 対; Dual-Purpose Pin 放开项未试; MSPI 失败回落 SSPI 时 SSPI 脚被采样',
                       '综合时在 Dual-Purpose Pin 放开 SSPI / CPU 并口 (及 json 列出的 I2C) 作普通 IO, 确认无报错; SO 所在 B5_B8 不接; 上板时故意擦 flash, 验证回落 SSPI 时上行线不被驱乱', 'RTL + 硬件',
                       'sheet4; sheet5 «e:gw_cfgpins» / «e:pwr_gw»'),
        'odt_part': ('GW5A 片内 100 Ω 分区限制: 资料冲突', 'UG304-1.3 (本包) §3.3.2 写"所有分区支持"; 任务口径引 UG304-1.3.7 "仅 Top/Bottom" (本包无该版); DS1103 表 3-26 未注分区; 工具在 bank2 接受 DIFF_RESISTOR=ON',
                     '拿到 UG304-1.3.7 原文核对; 本规划上行在 Bottom (bank4/5), 不受影响; 将来若在 bank2 / bank6 做差分输入, 以新版原文为准或板上外加 100 Ω', '硬件 (查资料)', 'sheet5 «e:odt»'),
        'down_clk': ('下行时钟对数: 1 対 + 扇出 IC 还是 12 対直出', f'2.5V 下行可用 {len(DOWN_PAIRS)} 対 + {len(DOWN_HALF)} 单端 (已扣隔离): 1 対 + 扇出够 (余 {NA[1]}); 12 対直出缺 {-NB[1]} 対',
                     f'保留 CDCLVD1212 扇出位; 12 対直出即使收回隔离対 {"/".join(GUARD_ONLY)} 仍缺 {-NB[1] - len(GUARD_ONLY)} 対 ⇒ 建议扇出 IC', '硬件 + 用户', 'sheet8 下行核算 A / B'),
        'v2_vccio23': ('V2 底板 VCCIO23 = 2.5V 与官方 CB-V2 (3.3V) 不同', 'gw5a_loop 自测位流按 BANK_VCCIO=3.3 约束 bank2/3, 插到 V2 上会电平不符; VCCIO23 上有边带输入 SB_RSTN / SB_UART_S2B, 3.3V 档下接 SoC 模组有门限余量不足、被自测位流驱 3.3V 的风险',
                       'V2 上 VCCIO23 供电经 0Ω 二选一 (2.5V / 3.3V, 默认 2.5V), 便于回到 3.3V 跑官方自测; 3.3V 档时必须断开 SoC 模组 (丝印注明); 自测位流另出一版 2.5V 约束', '硬件 + RTL', 'sheet8 VCCIO23; sheet5 «e:vccio23»'),
        'cep27': ('CEP2.7 球位: 手册 Y19 vs 原理图 Y9', '这一対 (L12_11) 是 GCLK 対; 若手册对, CEP2.7 上挂着残桩',
                  '原理图两处都指向 Y9; 烧 toggle 位流确认前不作信号; D7 双面两面都不用, 作 V3 J_TP11 闸门测点 (CEP2.7 / CEP2.8 各串 10 kΩ 引到排针, 不接 FPC; 只读直流弱上拉, 不需 toggle); '
                  'JTAG 分配不得占用 CEP2.7 / CEP2.8, 否则 J_TP11 失效; 若启用 Error-8221 顶替 (须先 toggle), V3 改版、闸门改 SENSE11', '硬件 (上板一次)', 'sheet6 CEP2.7 / CEP2.8; sheet5 «e:cep27»; V3_design_inputs.md B1 / B7'),
        'vccio0167': ('核心板 VCCIO01 / VCCIO67 由核心板自产并引到连接器', '核心板原理图 p3: VCCIO01 ← VCC1P5 经 FB4, VCCIO67 ← VCC2P5 经 FB3; 与记忆库"四组都由底板供"冲突; 底板另灌电源会与核心板电源打架',
                      'V2 底板 P1.9/10、P2.97/99 只作测试点或悬空; 向小梅哥确认 FB3 / FB4 实装, 以及 VCCIO23 / VCCIO45 核心板上确实没有自产', '硬件 (问供应商)', 'sheet5 «e:vccio_groups»; sheet7 电源行'),
        'fpc': ('连接器型号 / 芯数 / 固定方式 (两面各一套)', f'契约 {TOTAL_POS} 芯 × 2 面 (D2); 68~136 g 离心下 ZIF 靠摩擦保持是风险',
                f'按 {TOTAL_POS} 芯 (或 80 芯含备用) 0.5 mm 带锁扣 ZIF + 点胶或直焊选型; JTAG 已进契约 (D3), V2 另留下载器插座供停机调试 (D5)', '硬件 + 结构', 'sheet5 «e:mech» / «e:pinorder»'),
        'target_doc': ('pcb/00_目标电路总览.md 仍是 13 + 1 対口径', '总览 §2.2 / §4 写上行 13 対 + 1 対钟、桥片侧 GCLKIOL (EG4 口径)、配置 5~6 根 3.3V 从串; 与 09-15 的 20 対契约、JTAG 4 根 2.5V (D3 / D5) 不一致, 画目标板的人可能照旧口径',
                       '按本表 sheet2 更新总览的板间接口表 (本任务未改该文件)', '用户 / 文档', 'sheet1 资料冲突 #3'),
        'spin_sensor': ('光电传感器输出类型与 KEY2 的 RC / 按键处置',
                        '决定 K18 接法 (开集电极直接接 / 推挽 3.3V 串 100 Ω / 推挽 5V 加 74LVC1G17 @3.3V) 与 C245 去留: RC 220 µs 使上升沿到 VIH 约 205 µs, 与 900 RPM × 360 片一片约 185 µs 同量级 '
                        '(RTL 用上升沿, 并行流程 P2 读); 按 KEY2 = 假索引; 传感器类型查到的仍是未知 (并行流程 P2 引早期接线文档"3.3V 供电、FPGA 内部上拉", 暗示开集电极, 未证实)',
                        '查传感器型号 / 示波器量输出; 建议拆 C245 (和 K2); 若确认开集电极, 也可 RTL 改用下降沿 (下拉放电快); 飞线焊在转子上的 KEY2 焊盘做机械固定', '硬件 + RTL', 'sheet3 SPIN_SYNC 行; sheet5 «e:spin_sync»'),
        'soc_inject': ('DR1 弱上拉向未上电的 LED 模组注入 (及反向; 含 JTAG 访问中掉电的 TDO 残余风险)',
                       'D6 只管 DR1 配置后: 上电 → 加载完成 (最坏 ~90 ms) DR1 用户 IO 弱上拉 (≤153 µA @2.5V / 球, < 表 3-8 350 µA; 表 2-6 强制上拉球同为上拉) 经 20 対 LVDS 与直连的 SB_UART_S2B 灌入未上电的 LED 模组 '
                       '(JTAG 经 V2 Ioff 转换器不灌); 若 SB_UART_S2B 配置后设 PULLUP, 读到 IDCODE 前 RTL 三态期间仍持续注入 —— 本表已改 NONE; GW5A 未上电时 IO 注入容限未查。'
                       '反向: LED 模组先上电时, 未门控的桥片镜像把 SB_UART_B2S / SB_ALIGNED 驱高, 经 33 Ω 灌进未上电 DR1 bank 钳位二极管 (mA 级 ≫ 350 µA) 并抬 ADJ 岛与改板 LDO; '
                       '运行中 bank 岛掉电 (模块松脱 / 失地) 而 LED 模组仍上电时: SB 线经 V3 8.2 kΩ ≤282 µA ✓; JTAG_TDO 不串阻, 靠 TCK 停 ⇒ TAP 不在 Shift ⇒ TDO 被 V2 B 口下拉为低, '
                       '残余风险 = JTAG 访问进行中掉电 (TDO 可能停在高, 经 33 Ω 注入 mA 级), 暴露窗口只在访问进行中 (位流加载约数秒, 另有 IDCODE 轮询); '
                       'TMS / TDI 的 V2 22 kΩ 上拉反灌: TDI 96 µA、共用 TMS 两只并联 11 kΩ 193 µA, 均 ≤350 µA ✓',
                       '按 sheet2 规定5 / sheet5 «e:powerup» ④ 的验证期上下电顺序 (FS03 先上电、最后断电, 改板方案 README v2.2 §5.7) 执行 ⇒ LED 模组晚于 FS03 加载完成上电, 正反两向注入都不出现; '
                       '仍查 DS1103 / UG304 的未上电 IO 注入规格作余量 (DS1103 表 3-8 IHS ≤150 µA 已用于 SB_RSTN / SB_UART_S2B); 桥片 RTL 与 flash 镜像按 SB_RSTN 门控 («d:core_flash»); V3 对 SB_UART_B2S / SB_ALIGNED 串 8.2 kΩ (sheet3 规划·V3); '
                       'TDO 残余风险: SoC 每次 JTAG 访问结束都发 ≥5 个 TMS = 1 让 TAP 回到 Test-Logic-Reset ⇒ 静止时 GW5A TDO 高阻、被 V2 B 口下拉、转换器输出低, 无注入; '
                       '验证期 FS03 先上电、最后断电, 访问中 FS03 掉电属违规场景, 接受此风险; 运行中监视 SENSE33 / 电流, 岛电压跌出 2.40~2.60 V 先断 LED 模组 (README v2.2 §5.9 阶段 5); '
                       '目标板 TDO 转换器带 OE 见 «d:tdo_oe»; '
                       '改板模块已有肖特基反向阻断 + 1 kΩ 泄放 (第二道防线)', '硬件',
                       'sheet3 规划·上电与门控; sheet5 «e:powerup» / «e:pwr_dr1»'),
        'cep_pin1': ('FS03 CEP pin1 实际电压 (3.3V / 5V)',
                     'pin1 出厂经磁珠 L19 / L18 接 VCC_3V3 (L17 / L16 NC); PANEL_BRINGUP_CHECKLIST §4.2 #3 "5V 灌入改法" (贴 L16 / L17、拆 L18 / L19) 若做过则 CEP1.1 与 CEP2.1 都是 VIN_5V0, 未记录; '
                     '并行流程结论不一 (改板读图判恒 3.3V、审查与 research:fs03 指出可能 5V)',
                     '断电量 CEP1.1 / CEP2.1 分别导通到 VCC_3V3 还是 VIN_5V0 网; V3 默认不接 pin1, 与 CEP bank 信号相关的上拉 / 供电 (含光电传感器供电) 不以它为参考', '硬件 (上板一次)',
                     'sheet3 VCC_CEP 行; sheet6 CEPx.1'),
        'dr1_vi': ('DR1 输入推荐上限 VCCIO+0.165 与 2.5V 直连公差',
                   '桥 → SoC 单端 2.5V 直驱 DR1: 两侧 VCCIO 各 ±5 % 反向最坏 2.625 V > 2.54 V (DS1200 表 3-4 推荐), 未超绝对最大 2.675 V (表 3-1)',
                   '查 GW5A 核心板 VCC2P5 与 V2 本地 2.5V 轨的稳压精度, 两侧都 ≤ ±3.3 % 即满足; FS03 侧按 DR1 VCCIO 闸门窗 2.40~2.60 V 放行, 下限 2.40 V 时对端 VOH 须 ≤2.565 V; '
                   'SB_ALIGNED / SB_UART_B2S 经 V3 8.2 kΩ 后不受此限, 对不串阻的 JTAG_TDO 仍有效 (不满足则 TDO 转换器 VCCA 取更低容差轨或选更高精度稳压)', '硬件', 'sheet5 «e:dr1_vi» / «e:sideband_level»'),
        'adc_se': ('DS1200 ADC 复用 IO 作 LVCMOS 单端的限制 (FS03 JTAG 排布; 待安路确认两点)',
                   'DS1200 §4.2 管脚定义注 (印刷页 62): ADC0P/N~ADC15P/N 可作复用 I/O 输入端口; LVCMOS 模式下 ① 同一接口功能单元不与其他 PL I/O 混用 ② 对时钟占空比敏感时 < 30 MHz ③ 对端驱动 FAST 或 slew rate > 3.3 V/ns '
                   '(LVDS 不涉及)。FS03 bank33 的 8 个单端球里 6 个是 ADC 复用 (A16 / A17 / A21 / A22 / E19 / E20), 非 ADC 单端球只有 C22 / D22, 没有可挪的位置; 本表采用现排布: 每面 JTAG 4 根全落 ADC 球 (不混用, 注 1 ✓), '
                   '串 8.2 kΩ 的慢沿输入 (SB_ALIGNED / SB_UART_B2S) 全落 bank11 非 ADC 球 ✓; TDO 落 ADC 输入球且 V3 不贴串阻 (方案 a)。'
                   '待安路确认两点: ① ADC 复用球能否作 LVCMOS 输出 (TCK / TMS / TDI; 注原文只写"可作复用 I/O 输入端口"); '
                   '② 注 3 的摆率是指焊盘处还是对端驱动器设置 —— 原文"对端器件的驱动要求使用 FAST 配置或 slew rate > 3.3V/ns", 本表按对端驱动器设置理解 (V2 JTAG 转换器是快速 CMOS 输出, 满足); '
                   '若按焊盘处理解, 仅 FS03 板上 33 Ω × 约 20 pF 就只有约 1.4 V/ns, 任何方案都不满足, 故不可能是此意',
                   '① 问安路 FAE 或 TD 试综合: ADC 复用球设 LVCMOS25 输出是否允许、有无额外延时; 同时确认注 3 按对端驱动器设置理解; ② V2 转换器选型核 A 口输出 tr / tf (2.5 V 摆幅 > 3.3 V/ns ⇒ 0~100 % < 0.76 ns, 10~90 % 约 < 0.61 ns), '
                   'TDO 线 V3 不贴串阻 (0402 位默认 0 Ω)、走线短, 上板示波器在 V2 转换器输出端量 TDO 边沿; ③ 若 ① 不允许: 输出只能落非 ADC 球, 非 ADC 单端球只有 8 个 (C22 / D22 + bank11 余量 6), '
                   '不够两面 JTAG 6 + SB_RSTN 2 + SB_UART_S2B 2 + 串阻慢沿输入 4 = 14, 加 L12_11 (Y9 / Y8, 须先 toggle) 也只有 10 ⇒ 须减线 (如停用 SB_UART_S2B) 或改方案; '
                   '且 L12_11 是 J_TP11 闸门测点, 占用则 V3 改版、闸门改 SENSE11; 届时整体重排',
                   '硬件 + RTL (TD / 安路)', 'sheet3 规划·单端 / JTAG 行; sheet5 «e:soc_se» / «e:jtag_shift»'),
        'core_flash': ('验证期核心板 flash 镜像 (接 V2 / V3 / FS03 前擦除或换安全镜像)',
                       'ACG525-CORE-V2 板载 GD25Q128E MSPI 上电自启; openFPGALoader 每次写 GW5A SRAM 前先 RELOAD 从 flash 重配 ⇒ flash 镜像在 SoC 读 IDCODE 前与每次加载时运行。'
                       '包内 n13_l800 自测镜像把 V2 规划的上行接收球 U13 / V13 (UL_D[3])、R11 / T11 (UL_D[2])、U16 / V16 (UL_D[5]) 当 TLVDS 输出 (与 DR1 对驱), 把 SB_UART_S2B / SB_RSTN (U17 / U18) 当开 100 Ω 端接的 LVDS 接收; '
                       '出厂镜像脚位未查; 镜像是否按 SB_RSTN 门控边带输出无从保证',
                       '核心板接入 V2 / V3 / FS03 前: 擦除 flash, 或烧入与 V2 脚位一致的安全镜像 (上行球全输入且不开端接; SB_RSTN / SB_UART_S2B 为输入; SB_ALIGNED / SB_UART_B2S 受 SB_RSTN 门控, 为低时输出低或高阻); '
                       '自测镜像只在官方 CB-V2 上用; 擦 flash 会丢出厂镜像, 须用户确认 (并行流程 wf_3cee62db doc R28); flash 空时 openFPGALoader 走额外分支, 加载判据按 jtag_load sw/README 执行',
                       '用户 + 硬件 + RTL', 'sheet4 规划·核心板 flash; sheet5 «e:pwr_gw» / «e:powerup»'),
    }
    T['tdo_oe'] = ('目标板: V2 TDO 转换器带 OE, 由 SoC 侧供电的信号门控',
                   'JTAG_TDO 在 SoC 侧不串限流电阻, 直流保护靠"访问结束 TAP 回 Test-Logic-Reset ⇒ TDO 高阻被 B 口下拉 ⇒ 转换器输出低"; '
                   'JTAG 访问进行中 SoC IO 岛掉电时 TDO 可能停在高, 经 33 Ω 注入 mA 级 ≫ 350 µA。验证期按 FS03 先上电、最后断电, 访问中掉电属违规场景, 已接受; 目标板要去掉这个窗口',
                   'V2 的 TDO 转换器 (B → A 方向) 选带 OE 的型号, OE 由 SoC 侧供电的信号门控 ⇒ SoC 掉电即高阻。候选 SB_RSTN (SoC 模组未上电时被桥侧 2.2 kΩ 下拉为低), '
                   '但要核它与"复位"语义是否冲突: SoC 在读到 IDCODE 之前保持 SB_RSTN 为低, OE 直接接 SB_RSTN 则 IDCODE 读不到, 需另定时序或另设信号; 与 «d:jtag_shift_part» 选型一起定',
                   '硬件 + 用户', 'sheet2 JTAG_TDO; sheet9 «d:soc_inject» / «d:jtag_shift_part»')
    assert set(T) == set(D_KEYS)
    R = []
    for key in D_KEYS:
        item, imp, sug, who, where = T[key]
        R.append(([DCODE[key], item, imp, sug, who, where, '待定'], ['c', 'b', 't', 't', 't', 't', 'tbd']))
    return 'sheet9', '待定事项', H, W, R


def finalize(sheets):
    out = []
    for sid, name, H, W, body in sheets:
        nb = []
        for vals, stys in body:
            nv = [resolve_refs(x) if isinstance(x, str) else x for x in vals]
            for x in nv:
                assert not (isinstance(x, str) and '«' in x), (name, x)
            nb.append((nv, stys))
        out.append((sid, name, H, W, nb))
    return out


STALE_FORBID = [r'VCCIO45\s*[=:：·]?\s*(建议\s*)?2\.5', r'16 lane', r'16 数据 lane', r'预留\(16', r'FPC\.5\d', r'隔一対用一対', r'上行接口总表', r'14 対为契约',
                # v3 新增: 配置预留 / 77 芯 / 旧规定编号 / 边带在 VCCIO45 或 3.3V 直连
                r'CFG_(CLK|DIN|DOUT|CSN|PROGN|INITN|DONE)', r'配置预留', r'1~77', r'62~77', r'sheet2 规定3', r'边带 4 根用 VCCIO45', r'LVCMOS33 与 GW5A VCCIO45', r'VCCIO45 的 4 个半対单脚']
STALE_V3_PATS = STALE_FORBID[8:]
STALE_MERGE = [r'待合并', r'推荐 B', r'两案', r'方案 A 用途', r'方案 B 用途', r'二选一失效',      # M 合并后绝对禁词
               # F 步: 改板方案 v1 状态 / 旧 JTAG 上电态论证 / 旧电平适配口径
               r'双 bank 版在出', r'1 critical \+ 4 major', r'适配放 V3', r'板上 ADC 网络未查', r'SW1 拨 JTAG 或拔 TF', r'验证板不涉及', r'母座扣',
               r'TAP 只停在', r'TCK 停高', r'TMS = 1 与 HSWAPEN 无关', r'落表 2-6 强制下拉球', r'TMS / TDO 落强制上拉球',
               # G 步: 与 FS03 改板 README v2.2 / V3_design_inputs.md 统一口径后禁用的旧写法
               r'≤330 Ω', r'330 Ω~1 kΩ', r'串 1 kΩ', r'≤1 MHz', r'V3 / 灯板', r'灯板 / V3', r'V3 上电', r'LDO 要求精度', r'±2 %', r'≥20 mm', r'开槽',
               r'TMS / TDI 10 kΩ 下拉', r'TMS / TDI 各 10 kΩ 下拉', r'A 口下拉 10 kΩ', r'TCK / TMS / TDI PULLTYPE PULLDOWN', r'SB_UART_B2S 输入 PULLUP', r'早于其?掉电',
               r'0\.58 V', r'0\.33 \+ 0\.25', r'全 1 = ', r'改板方案另附', r'README\.md v2 ', r'改板方案 v2 ', r'只引测试焊盘', r'不接任何元件', r'0 Ω 引到 J_TP', r'TP_TDO_B \(', r'74LVC1G17 @2\.5V',
               # 09-15 拍板: TMS / TDI 上拉 22 kΩ (取代 10 kΩ; 共用 TMS 反灌 422 µA 的问题已解决)
               r'10 kΩ 上拉', r'上拉 10 kΩ', r'10 kΩ 到桥模组', r'10 kΩ ∥ 10 kΩ', r'上拉 5 kΩ', r'并联 5 kΩ', r'422 µA', r'212 µA', r'10\.03 kΩ']
STALE_V3_OK = ('取代', 'v2 为', 'v2 的', 'v2 口径', '已失效', 'v2 曾', 'v2 放')      # 说明"已被取代"的语境里允许出现 v3 禁词
STALE_14_OK = ('阶段一', '现役', '子集', '探针', 'v1', '14/14', '旧')


def stale_check(sheets):
    hits, ok14 = [], 0
    for _sid, name, H, _W, body in sheets:
        for vals, _s in [(H, None)] + body:
            for x in vals:
                if not isinstance(x, str):
                    continue
                for pat in STALE_FORBID:
                    if re.search(pat, x) and not (pat in STALE_V3_PATS and any(w in x for w in STALE_V3_OK)):
                        hits.append((name, pat, x[:80]))
                for pat in STALE_MERGE:
                    if re.search(pat, x):
                        hits.append((name, pat, x[:80]))
                if '14 対' in x:
                    if not any(w in x for w in STALE_14_OK):
                        hits.append((name, '14 対 (无子集 / 现役语境)', x[:120]))
                    else:
                        ok14 += 1
    return hits, ok14



# =============================================================================
# 3. OOXML 写出
# =============================================================================
STYLE_ID = {'default': 0, 'h': 1, 't': 2, 'c': 3, 'ok': 4, 'sug': 5, 'tbd': 6, 'risk': 7,
            'g': 8, 'y': 9, 'r': 10, 'gray': 11, 'b': 12}
FONT = '<name val="微软雅黑"/><family val="2"/><charset val="134"/>'
STYLES = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
          '<fonts count="7">'
          f'<font><sz val="10"/>{FONT}</font>'
          f'<font><b/><sz val="10"/><color rgb="FF1F3864"/>{FONT}</font>'
          f'<font><b/><sz val="10"/><color rgb="FF006100"/>{FONT}</font>'
          f'<font><b/><sz val="10"/><color rgb="FF9C5700"/>{FONT}</font>'
          f'<font><b/><sz val="10"/><color rgb="FF9C0006"/>{FONT}</font>'
          f'<font><b/><sz val="10"/>{FONT}</font>'
          f'<font><sz val="10"/><color rgb="FF9C0006"/>{FONT}</font>'
          '</fonts>'
          '<fills count="7">'
          '<fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>'
          '<fill><patternFill patternType="solid"><fgColor rgb="FFBDD7EE"/><bgColor indexed="64"/></patternFill></fill>'
          '<fill><patternFill patternType="solid"><fgColor rgb="FFC6EFCE"/><bgColor indexed="64"/></patternFill></fill>'
          '<fill><patternFill patternType="solid"><fgColor rgb="FFFFEB9C"/><bgColor indexed="64"/></patternFill></fill>'
          '<fill><patternFill patternType="solid"><fgColor rgb="FFFFC7CE"/><bgColor indexed="64"/></patternFill></fill>'
          '<fill><patternFill patternType="solid"><fgColor rgb="FFEDEDED"/><bgColor indexed="64"/></patternFill></fill>'
          '</fills>'
          '<borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border>'
          '<border><left style="thin"><color rgb="FFBFBFBF"/></left><right style="thin"><color rgb="FFBFBFBF"/></right>'
          '<top style="thin"><color rgb="FFBFBFBF"/></top><bottom style="thin"><color rgb="FFBFBFBF"/></bottom><diagonal/></border></borders>'
          '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
          '<cellXfs count="13">'
          '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
          + ''.join(
              f'<xf numFmtId="0" fontId="{fo}" fillId="{fi}" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">'
              f'<alignment horizontal="{ha}" vertical="{va}" wrapText="1"/></xf>'
              for fo, fi, ha, va in [
                  (1, 2, 'center', 'center'),   # 1 h 表头
                  (0, 0, 'left', 'top'),        # 2 t 正文
                  (0, 0, 'center', 'top'),      # 3 c 居中
                  (2, 3, 'center', 'top'),      # 4 ok 已定
                  (3, 4, 'center', 'top'),      # 5 sug 建议
                  (4, 5, 'center', 'top'),      # 6 tbd 待定
                  (6, 5, 'left', 'top'),        # 7 risk 红底红字
                  (0, 3, 'left', 'top'),        # 8 g 绿底
                  (0, 4, 'left', 'top'),        # 9 y 黄底
                  (0, 5, 'left', 'top'),        # 10 r 红底
                  (0, 6, 'left', 'top'),        # 11 gray
                  (5, 0, 'left', 'top'),        # 12 b 加粗
              ])
          + '</cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
          '<dxfs count="0"/><tableStyles count="0" defaultTableStyle="TableStyleMedium2" defaultPivotStyle="PivotStyleLight16"/>'
          '</styleSheet>')

_CTRL = re.compile(r'[\x00-\x08\x0b\x0c\x0e-\x1f]')


def esc(s):
    s = _CTRL.sub('', str(s))
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;')


def col_letter(i):
    s, i = '', i + 1
    while i:
        i, r = divmod(i - 1, 26)
        s = chr(65 + r) + s
    return s


def disp_w(s):
    return sum(2 if ord(ch) > 0x2E80 else 1 for ch in s)


def row_height(vals, widths):
    n = 1
    for v, w in zip(vals, widths):
        lines = 0
        for seg in str(v).split('\n'):
            lines += max(1, math.ceil(disp_w(seg) / max(w * 1.15 - 1, 1)))
        n = max(n, lines)
    return min(409.0, 15.0 * n + 3)


def cell_xml(ref, val, sty):
    s = STYLE_ID[sty]
    if val is None or val == '':
        return f'<c r="{ref}" s="{s}"/>'
    if isinstance(val, int) and not isinstance(val, bool):
        return f'<c r="{ref}" s="{s}"><v>{val}</v></c>'
    return f'<c r="{ref}" s="{s}" t="inlineStr"><is><t xml:space="preserve">{esc(val)}</t></is></c>'


def sheet_xml(H, W, body, selected):
    ncol = len(H)
    last_col = col_letter(ncol - 1)
    nrow = len(body) + 1
    cols = ''.join(f'<col min="{i + 1}" max="{i + 1}" width="{w}" customWidth="1"/>' for i, w in enumerate(W))
    out = [f'<row r="1" ht="{row_height(H, W):.1f}" customHeight="1">' +
           ''.join(cell_xml(f'{col_letter(i)}1', h, 'h') for i, h in enumerate(H)) + '</row>']
    for r, (vals, stys) in enumerate(body, start=2):
        assert len(vals) == ncol and len(stys) == ncol, (H[0], r, len(vals), len(stys))
        out.append(f'<row r="{r}" ht="{row_height(vals, W):.1f}" customHeight="1">' +
                   ''.join(cell_xml(f'{col_letter(i)}{r}', v, s) for i, (v, s) in enumerate(zip(vals, stys))) + '</row>')
    tab = ' tabSelected="1"' if selected else ''
    return ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            f'<dimension ref="A1:{last_col}{nrow}"/>'
            f'<sheetViews><sheetView{tab} zoomScale="100" workbookViewId="0">'
            '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
            '<selection pane="bottomLeft" activeCell="A2" sqref="A2"/></sheetView></sheetViews>'
            f'<sheetFormatPr defaultRowHeight="15"/><cols>{cols}</cols>'
            f'<sheetData>{"".join(out)}</sheetData>'
            f'<autoFilter ref="A1:{last_col}{nrow}"/>'
            '<pageMargins left="0.4" right="0.4" top="0.5" bottom="0.5" header="0.3" footer="0.3"/>'
            '<pageSetup paperSize="9" orientation="landscape"/>'
            '</worksheet>')


def write_xlsx(path, sheets):
    wb_sheets, rels, ctypes, names = [], [], [], []
    for k, (_id, name, H, W, body) in enumerate(sheets, 1):
        assert len(name) <= 31 and not re.search(r'[\[\]:*?/\\]', name), name
        wb_sheets.append(f'<sheet name="{esc(name)}" sheetId="{k}" r:id="rId{k}"/>')
        rels.append(f'<Relationship Id="rId{k}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet{k}.xml"/>')
        ctypes.append(f'<Override PartName="/xl/worksheets/sheet{k}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>')
        last = f"${col_letter(len(H) - 1)}${len(body) + 1}"
        names.append(f'<definedName name="_xlnm._FilterDatabase" localSheetId="{k - 1}" hidden="1">\'{esc(name)}\'!$A$1:{last}</definedName>')
    n = len(sheets)
    rels.append(f'<Relationship Id="rId{n + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>')
    workbook = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
                'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
                '<bookViews><workbookView xWindow="0" yWindow="0" windowWidth="28800" windowHeight="15000" activeTab="0"/></bookViews>'
                f'<sheets>{"".join(wb_sheets)}</sheets><definedNames>{"".join(names)}</definedNames></workbook>')
    content_types = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                     '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
                     '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
                     '<Default Extension="xml" ContentType="application/xml"/>'
                     '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
                     '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
                     '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
                     '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
                     + ''.join(ctypes) + '</Types>')
    root_rels = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                 '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                 '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
                 '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
                 '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
                 '</Relationships>')
    core = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
            'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" '
            'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
            '<dc:title>DR1V90 主控 ↔ GW5A 桥接模块 对接关系表</dc:title>'
            f'<dc:description>POV3D 模组间接口契约 (20 対/面) + 验证板实现 {VERSION}</dc:description>'
            f'<dcterms:created xsi:type="dcterms:W3CDTF">{DATE}T00:00:00Z</dcterms:created>'
            '</cp:coreProperties>')
    app = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
           '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">'
           '<Application>POV3D mkxlsx (stdlib)</Application></Properties>')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + '.tmp'
    with zipfile.ZipFile(tmp, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('[Content_Types].xml', content_types)
        z.writestr('_rels/.rels', root_rels)
        z.writestr('docProps/core.xml', core)
        z.writestr('docProps/app.xml', app)
        z.writestr('xl/workbook.xml', workbook)
        z.writestr('xl/_rels/workbook.xml.rels',
                   '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                   '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' + ''.join(rels) + '</Relationships>')
        z.writestr('xl/styles.xml', STYLES)
        for k, (_id, name, H, W, body) in enumerate(sheets, 1):
            z.writestr(f'xl/worksheets/sheet{k}.xml', sheet_xml(H, W, body, k == 1))
    try:
        os.replace(tmp, path)
    except PermissionError:
        os.remove(tmp)
        sys.exit(f'[输出失败] {path} 被占用 (多半是 Excel 正打开着, 同目录有 ~$ 锁文件): 关闭后重跑, 或给输出路径参数 (argv[1])')


# =============================================================================
# 4. 源数据核对 (只用标准库能读的源) 与回读自检
# =============================================================================
def parse_ug985_ug324(lines):
    # UG985 pdftotext -layout 文本 → {管脚名: dict(ball, bank, cfg)}; 只解析 Pin List UG324 段, 处理管脚名 / 配置功能折行
    s = next(i for i, l in enumerate(lines) if l.strip() == 'Pin List UG324')
    e = next(i for i in range(s + 1, len(lines)) if lines[i].strip().startswith('Pin List ') and lines[i].strip() != 'Pin List UG324')
    seg = lines[s:e]
    main_re = re.compile(r'\sI/O\s+\d+\s.*\s([A-V]\d{1,2})\s*$')
    pin_re = re.compile(r'^IO[TBLR]\d+[AB]')
    res = {}
    for i, l in enumerate(seg):
        if not main_re.search(l):
            continue
        toks = l.split()
        wrapped = l[:1].isspace()
        rest = toks if wrapped else toks[1:]
        k = 3 + (1 if rest[2].startswith('bus') else 0)
        tail = rest[k:]
        mid = tail[:-2]
        if mid and re.match(r'^(True_of|Comp_of)_', mid[-1]):
            mid = mid[:-1]
        if wrapped:
            pf, qf = re.split(r'\s{2,}', seg[i - 1].strip()), re.split(r'\s{2,}', seg[i + 1].strip())
            if not pin_re.match(pf[0]) or pin_re.match(qf[0]):
                raise ValueError('UG985 折行解析失败: ' + l.strip())
            name, cfg = pf[0] + qf[0], (pf[1] if len(pf) > 1 else '') + (qf[1] if len(qf) > 1 else '')
        else:
            if len(mid) > 1:
                raise ValueError('UG985 行解析失败: ' + l.strip())
            name, cfg = toks[0], (mid[0] if mid else '')
        res[name.split('/')[0]] = dict(ball=tail[-1], bank=int(rest[1]), cfg=cfg)
    return res


def verify():
    bad, msgs = [], []
    p = SRC['pinmap']
    if os.path.exists(p):
        pm = {r['ball']: r for r in csv.DictReader(open(p, encoding='utf-8-sig'))}
        for b, (bank, name, pair, pol, alt) in PM.items():
            r = pm.get(b)
            if not r or [r['bank'], r['name'], r['pair'], r['pol'], r['alt']] != [str(bank), name, pair, pol, alt]:
                bad.append(f'pinmap.csv 与嵌入数据不一致: {b}')
        for c in CHAIN:
            if c['ball'] and pm[c['ball']]['name'] != c['io']:
                bad.append(f"FS03 链路管脚名与 pinmap 不一致: {c['conn']}.{c['pin']}")
        msgs.append(f'pinmap.csv: 核对 {len(PM)} 球')
        for b, rec in SOC_EXTRA.items():
            r = pm.get(b)
            if not r or [r['bank'], r['name'], r['pair'], r['pol'], r['alt']] != [str(x) for x in rec]:
                bad.append(f'pinmap.csv 与 SOC_EXTRA 不一致: {b}')
        msgs.append(f'pinmap.csv: CEP 外 {len(SOC_EXTRA)} 球 ({" / ".join(SOC_EXTRA)}) 核对')
    else:
        msgs.append('pinmap.csv 不在, 跳过')
    p = SRC['adc']
    if os.path.exists(p):
        cur = []
        for line in open(p, encoding='utf-8'):
            m = re.search(r'\{ (tx\[\d+\]|txclk) \}\s+\{ LOCATION = (\w+); IOSTANDARD = (\w+);.*?#\s*(.*)$', line)
            if m:
                cur.append([m.group(1), m.group(2), m.group(3), m.group(4).strip()])
        if cur != DATA['adc']:
            bad.append('uplink_pin.adc 已变, 与嵌入的 14 対不一致')
        msgs.append(f'uplink_pin.adc: {len(cur)} 条')
    else:
        msgs.append('uplink_pin.adc 不在, 跳过')
    for key in ('pov_adc', 'panel_adc'):
        p = SRC[key]
        if not os.path.exists(p):
            msgs.append(f'{key} 不在, 跳过')
            continue
        locs = dict(re.findall(r'\{ (\S+) \}\s+\{ LOCATION = (\w+);', open(p, encoding='utf-8').read()))
        b11 = {b for b in locs.values() if b in PM and PM[b][0] == 11}
        if locs.get('spin_sync_i') != SOC_POV_SPIN:
            bad.append(f'{key}: spin_sync_i = {locs.get("spin_sync_i")} ≠ {SOC_POV_SPIN}')
        if b11 != PANEL_BALLS:
            bad.append(f'{key}: bank11 球集合与 PANEL_BALLS 不一致')
        if set(SOC_EXTRA) & set(locs.values()):
            bad.append(f'{key}: 已占用 {sorted(set(SOC_EXTRA) & set(locs.values()))}')
        msgs.append(f'{os.path.basename(p)}: spin_sync_i = {locs.get("spin_sync_i")}, bank11 {len(b11)} 球, 不占 {" / ".join(SOC_EXTRA)}')
    p = SRC['pkg']
    if os.path.exists(p):
        pdat = json.load(open(p))['PIN_DATA']
        byname = {x['NAME'].split('/')[0]: x for x in pdat}
        byball = {x['INDEX']: x for x in pdat}
        n = 0
        for c in CORE:
            if not c['net']:
                continue
            n += 1
            if c['fpga'].startswith('IO'):
                x = byname[c['fpga']]
                mate = byname.get(x.get('PAIR', ''), {}).get('INDEX', '')
                if (x['INDEX'], x.get('BANK'), x.get('CFG', '') or '', mate) != (c['ball'], c['bank'], c['cfg'], c['mate']):
                    bad.append(f"UBGA324.json 不一致: {c['conn']}.{c['pin']} {c['net']}")
            elif byball[c['ball']]['NAME'] != c['fpga']:
                bad.append(f"UBGA324.json MIPI 脚不一致: {c['conn']}.{c['pin']}")
        for j in JTAG:
            x = byball.get(j['ball'], {})
            if (x.get('NAME'), x.get('BANK'), x.get('CFG')) != (j['fpga'], 10, j['tap']):
                bad.append(f"UBGA324.json JTAG 脚不一致: {j['name']} {j['ball']} → {x.get('NAME')} bank{x.get('BANK')} {x.get('CFG')}")
        msgs.append(f'UBGA324.json: 核对 {n} 个信号脚 + JTAG 4 球 (A17 TCK / B18 TMS / D15 TDI / D16 TDO, bank10)')
    else:
        msgs.append('UBGA324.json 不在 (Gowin IDE 未装), 跳过')
    p = SRC['tsv']
    if os.path.exists(p):
        byp = {(c['conn'], c['pin']): c for c in CORE}
        n = 0
        for r in csv.DictReader(open(p, encoding='utf-8'), delimiter='\t'):
            n += 1
            conn, pin = r['conn_pin'].split('.')
            c = byp[(conn, int(pin))]
            if (c['net'], c['ball'], str(c['bank']), c['mate'], c['cfg']) != (r['core_net'], r['ball'], r['bank'], r['pair_ball'], r['cfg']):
                bad.append(f"pins_v2.tsv 不一致: {r['conn_pin']}")
        msgs.append(f'pins_v2.tsv: 核对 {n} 行')
    else:
        msgs.append('pins_v2.tsv 不在, 跳过')
    p = SRC['ug985']
    if os.path.exists(p) and shutil.which('pdftotext'):
        with tempfile.TemporaryDirectory() as td:
            t = os.path.join(td, 'ug985.txt')
            subprocess.run(['pdftotext', '-layout', p, t], check=True)
            ug = parse_ug985_ug324(open(t, encoding='utf-8').read().split('\n'))
        n = 0
        for c in CORE:
            if c['net'] and c['fpga'].startswith('IO'):
                n += 1
                u = ug.get(c['fpga'])
                if not u or (u['ball'], u['bank'], u['cfg']) != (c['ball'], c['bank'], ug_cfg(c)):
                    bad.append(f"UG985 Pin List UG324 不一致: {c['conn']}.{c['pin']} {c['fpga']}")
        by_fpga = {c['fpga']: c for c in CORE if c['fpga']}
        for f, (_ball, cfg, _ln) in UG985_CFG.items():
            if cfg == (by_fpga[f]['cfg'] or ''):
                bad.append(f'ug985_cfg 冗余 (与 json 相同): {f}')
        msgs.append(f'UG985 PDF: 核对 {n} 个 IO 脚 (球位 / bank / 配置功能), 其中 {len(UG985_CFG)} 脚与 json 不同')
    else:
        msgs.append('UG985 PDF 或 pdftotext 不在, 跳过')
    # 结构性自洽
    if len(CORE) != 200 or len(CHAIN) != 100:
        bad.append('嵌入数据行数不对')
    if len(FULL) != 73 or len(HALF) != 8:
        bad.append(f'核心板対数不对: 完整 {len(FULL)} 半 {len(HALF)}')
    return bad, msgs


def selfcheck(path, sheets):
    ns = {'m': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main',
          'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}
    z = zipfile.ZipFile(path)
    assert z.testzip() is None
    for name in z.namelist():
        ET.fromstring(z.read(name))                       # 每个部件都必须是良构 XML
    wb = ET.fromstring(z.read('xl/workbook.xml'))
    rel = ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))
    target = {r.get('Id'): r.get('Target') for r in rel}
    report = []
    for (sid, name, H, W, body), sh in zip(sheets, wb.find('m:sheets', ns)):
        assert sh.get('name') == name
        root = ET.fromstring(z.read('xl/' + target[sh.get(f"{{{ns['r']}}}id")]))
        rows = root.findall('m:sheetData/m:row', ns)
        assert len(rows) == len(body) + 1, (name, len(rows), len(body) + 1)
        for r in rows:
            assert len(r.findall('m:c', ns)) == len(H), (name, r.get('r'))
        assert root.find('m:sheetViews/m:sheetView/m:pane', ns).get('state') == 'frozen'
        assert root.find('m:autoFilter', ns) is not None
        stat = {}
        for vals, stys in body:
            for v, s in zip(vals, stys):
                if s in ('ok', 'sug', 'tbd'):
                    stat[s] = stat.get(s, 0) + 1
                    word = {'ok': '已定', 'sug': '建议', 'tbd': '待定'}[s]
                    t = str(v)
                    assert t.startswith(word), ('状态格颜色与开头词不符', name, t[:40])
                    rest, prev = t[2:], None
                    while prev != rest:                                   # 去掉括号补充后不得再出现第二个状态词
                        prev, rest = rest, re.sub(r'\([^()]*\)', '', rest)
                    assert not any(w in rest for w in ('已定', '建议', '待定')), ('状态格括号外出现第二个状态', name, t[:60])
                elif str(v).startswith(('已定', '建议', '待定')):                      # 反向: 以状态词开头的格必须是状态样式
                    raise AssertionError(('非状态样式的格以状态词开头', name, str(v)[:40]))
        report.append((name, len(rows), len(H), stat))
    return report


def v3_sheet_checks(sheets):
    """v3 新增的产物级断言: 契约与 LED 侧的边带 / JTAG 行内容"""
    by = {name: body for _sid, name, _H, _W, body in sheets}
    con = {v[1]: v for v, _s in by['模组间接口契约'] if isinstance(v[0], int)}
    assert len(con) == TOTAL_POS - len(DIFF_GND) - len(SB_GND) + 1, len(con)      # 40 差分 + 8 单端 + 'GND' 名合并为 1
    for s in SE_ALL:
        v = con[s['name']]
        assert v[0] == s['pos'] and v[3] == s['dir'] and 'LVCMOS25' in v[7] and 'LVCMOS33 (3.3 V 单端)' not in v[7], s['name']
        assert str(v[12]).startswith('已定'), (s['name'], v[12])
    assert con['JTAG_TCK'][10].startswith('单独成组'), con['JTAG_TCK'][10]
    assert all('2.2 kΩ' in con[n][7] for n in ('SB_ALIGNED', 'SB_RSTN'))
    led = {v[1]: v for v, _s in by['验证板实现-LED侧_GW5A_ACG525'] if str(v[1]).startswith(('SB_', 'JTAG_'))}
    assert set(led) == {s['name'] for s in SE_ALL}
    for s in SB:
        v = led[s['name']]
        assert v[11].split(' ')[0] in SB_25_GROUPS and v[13].startswith('LVCMOS25') and v[7] == GW_SB[s['name']], s['name']
    for j in JTAG:
        v = led[j['name']]
        assert v[6] == f"P1.{j['core_pin']}" and v[7] == 'FPGA_' + j['tap'] and v[9] == j['ball'] and v[10] == '10', j['name']
    assert not any('CFG_' in str(x) for _sid, _n, _H, _W, body in sheets for v, _s in body for x in v)
    soc, rows_by = by['验证板实现-SoC侧_DR1V90_FS03'], {}
    for v, _s in soc:
        rows_by.setdefault(str(v[1]), v)
    n_pair = 0
    for k in PAIR_ORDER:
        for pol in 'PN':
            v = rows_by[f'{sname(k)}_{pol}']
            assert (v[7], v[13]) == (SOC_IMPL['faces']['A']['pairs'][k][pol], SOC_IMPL['faces']['B']['pairs'][k][pol]) and v[17].startswith('LVDS25'), (k, pol, v[7], v[13])
            n_pair += 1
    for s in SE_ALL:
        v, grp = rows_by[s['name']], ('sideband' if s['name'].startswith('SB_') else 'jtag')
        assert (v[7], v[13]) == (SOC_IMPL['faces']['A'][grp][s['name']]['ball'], SOC_IMPL['faces']['B'][grp][s['name']]['ball']) and 'LVCMOS25' in v[17], s['name']
    spin = [v for v, _s in soc if str(v[1]).startswith('SPIN_SYNC')]
    assert len(spin) == 1 and spin[0][7] == SOC_IMPL['spin_sync']['ball']
    assert sum(1 for v, _s in soc if v[0] == '规划') == len(SOC_IMPL.get('plan') or [])
    io_rows = [v for v, _s in by['DR1V90_FS03_CEP全表'] if v[5] != '—']
    assert len(io_rows) == SOC_SUM['cep_io'] and all(v[13] != '未用' for v in io_rows), [v[0] for v in io_rows if v[13] == '未用']
    return len(con), len(led), n_pair


def main():
    global SOC_IMPL, SOC_SUM
    si = next((a.split('=', 1)[1] for a in sys.argv[1:] if a.startswith('--soc-impl=')), None)
    if si:
        SOC_IMPL = json.load(open(si, encoding='utf-8'))
    probs = check_soc_impl(SOC_IMPL)
    for p in probs:
        print('[SOC_IMPL 校验失败]', p)
    if probs:
        sys.exit(3)
    try:
        SOC_SUM = soc_merge_asserts(SOC_IMPL)
    except AssertionError as e:
        print('[SOC_IMPL 合并断言失败]', e)
        sys.exit(4)
    print(f"[SoC 侧] {('--soc-impl ' + si) if si else '内嵌 SOC_IMPL (P2)'}: check_soc_impl 通过; 合并断言通过 —— 两面各 20 対 (时钟 A {SOC_SUM['clk']['A']} / B {SOC_SUM['clk']['B']}, 均 GCLK)、"
          f"LVDS 不占劈开対、CEP IO 已用 {SOC_SUM['cep_used']}/{SOC_SUM['cep_io']} 无重复 (LVDS {SOC_SUM['lvds']} + 单端 {SOC_SUM['se_balls']} 球 + 预留 {SOC_SUM['rsv']})、光电开关 {SOC_SUM['spin']}")
    if '--no-verify' not in sys.argv:
        bad, msgs = verify()
        for m in msgs:
            print('[核对]', m)
        if bad:
            for b in bad:
                print('[核对失败]', b)
            sys.exit(2)
    sheets = finalize([sheet_readme(), sheet_contract(), sheet_soc(), sheet_led(), sheet_constraints(), sheet_cep(), sheet_core(),
                       sheet_budget(), sheet_tbd()])
    hits, ok14 = stale_check(sheets)
    for h in hits:
        print('[旧说法残留]', h)
    assert not hits, f'{len(hits)} 处旧说法残留'
    print(f'[旧说法检查] 0 残留; 含 "14 対" 的格 {ok14} 个, 均带 阶段一/现役/子集/探针/旧 语境')
    pos_args = [a for a in sys.argv[1:] if not a.startswith('--')]
    out = pos_args[0] if pos_args else next((a.split('=', 1)[1] for a in sys.argv[1:] if a.startswith('--out=')), None)
    if not out:
        sys.exit(f'[用法] 必须给输出路径 (argv[1] 或 --out=); 不再缺省写包内文件。正式发布到包内时显式给: {OUT}')
    out = os.path.abspath(out)
    nc, nl, npair = v3_sheet_checks(sheets)
    print(f'[v3 断言] 契约 {nc} 个信号名 (含 GND) / LED 侧边带 + JTAG {nl} 行: 边带全部 LVCMOS25 落 2.5V 组、JTAG 四脚 P1.94/96/98/100 与球位一致、无 CFG_ 残留')
    print(f'[合并断言·产物] sheet3 差分 {npair} 行 + 单端 {len(SE_ALL)} 行球位 = SOC_IMPL, 光电开关行 1, 规划行 {len(SOC_IMPL.get("plan") or [])}; sheet6 {SOC_SUM["cep_io"]} 个 IO 无"未用"; 无"待合并"残留')
    write_xlsx(out, sheets)
    print('[输出]', out, f'{os.path.getsize(out) / 1024:.1f} KB')
    for name, nrows, ncol, stat in selfcheck(out, sheets):
        print(f"[自检] {name}: {nrows} 行 (含表头) × {ncol} 列 · 已定 {stat.get('ok', 0)} / 建议 {stat.get('sug', 0)} / 待定 {stat.get('tbd', 0)}")


if __name__ == '__main__':
    main()
