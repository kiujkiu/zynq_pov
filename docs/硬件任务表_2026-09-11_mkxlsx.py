# -*- coding: utf-8 -*-
"""06 硬件任务表 xlsx (rev.4): 两个版本 → 小目标 → 交付物
复用旧 xlsx 的 styles/rels, 只换两张表 (环境里没有 openpyxl)
用法: python3 本脚本 <旧xlsx作样式模板> <输出xlsx>"""
import sys, zipfile

SRC, DST = sys.argv[1], sys.argv[2]

# 样式号 (沿用旧 styles.xml): 1 表头 / 2 待填表头(黄) / 3 正文 / 4 居中 / 5 粗体居中
#                             6 待填格 / 7 待填日期 / 8 红底粗体 / 9 绿底粗体 / 10 灰底粗体
RED, GREEN, GRAY = 8, 9, 10

# (编号, 版本, 线, 小目标, 交付物, 验收判据, 前置, 支撑谁·提供什么, 着色)
ROWS = [
 ('1-1', '版本一 验证板', '—', '开画前定案',
  '① 桥片选型报告：型号，V2 自研还是用核心板，采购确认的价格、货期和供货（询价单 B01）\n② 模组间接口契约 ICD v1，含通信速率结论',
  '两份文档出齐；ICD 四条冻结：対数、电平与共模、阻抗与地线、lane 映射与协议，覆盖 FS03 和自研 SOC 两种；速率输入见 03 §2',
  '—',
  '→ 1-2：V2 / V3 才能开画\n→ 2A-2：T1 沿用同一颗桥片\n→ 2B-1：ICD 定下 SOC 板要引出多少対', RED),
 ('1-2', '版本一 验证板', '—', '三块板回板并点亮',
  'V1 / V2 / V3 的设计文件和实物，加点亮记录',
  'FPGA 能配置、时钟锁定；12 颗 2260 全部点亮、无坏区；收到 CRC 正确的 ACK 回包',
  '1-1',
  '→ 1-3：提供被测对象\n→ 2A-3：FS03 + V3 当 T1 的测试台架\n→ 2B-3：V1 + V2 当 T2 的测试台架\n→ 软件侧：调固件用的台架', RED),
 ('1-3', '版本一 验证板', '—', '三条硬轴测试报告',
  '测试报告 + 给目标板的设计输入清单（端接方式、线速率、每面対数）',
  '① 桥片 IO 内部相位与预算一致 ② LVDS 驱 2260 共模落在 1.1~1.3 V 窗内 ③ 上行环回 800M / 700M 两档误码为 0',
  '1-2',
  '→ 2A-2 / 2B-2：设计输入清单\n🔴 版本二唯一硬门槛：不全过，目标板不能画', RED),
 ('2A-1', '版本二 目标板', '2A LED 板线', 'LED 板定案',
  '① 屏体路线结论：自制还是 COB\n② 亮度实测结论，两条路线分别给',
  '成本、周期、迭代次数、良率、亮度五项都有数字并选定一条；回答"48 W 下够不够亮"（自制用现有 2260 台架实测，COB 先用厂家样品或数据、打样回来复测）；定下电流、功耗和屏体形式',
  '无，现在就能开始，版本一期间并行',
  '→ 2A-2：屏体形式、电流、功耗\n→ 2C-2：功耗和亮度能否达标的依据\n目标板可能改 COB，亮度跟屏体走；COB 打样 3 个月，定晚了拖住 2A-2', GREEN),
 ('2A-2', '版本二 目标板', '2A LED 板线', 'LED 板设计投产',
  '原理图、8 层 HDI layout、SI 仿真报告、投产回执',
  'SI 仿真通过、评审通过、投产',
  '1-3、2A-1（桥片来自 1-1）',
  '→ 2A-3：T1 实物', GRAY),
 ('2A-3', '版本二 目标板', '2A LED 板线', 'LED 板单板点亮',
  '点亮记录、实拍照片',
  '接验证版 SOC 侧（FS03 + V3）驱动，192×216 全阵列点亮、无坏区，链路误码为 0',
  '2A-2（台架来自 1-2）',
  '→ 2C-1：一块单独验证过的 T1；不用等 T2', GRAY),
 ('2B-1', '版本二 目标板', '2B SOC 板线', 'SOC 板定案',
  '① 主 SOC 选型报告\n② 板级需求清单',
  '在 XC7Z020 / DR1V90 中选定，附采购确认的价格、货期和供货（询价单 A01）；电源轨（含 2.5 V）、DDR、存储、模组间接口対数（按 ICD）列清',
  '选型现在就能开始，版本一期间并行；接口対数等 1-1 的 ICD',
  '→ 2B-2：SOC 型号和板级需求；SOC 看货期，定晚了拖住 2B-2', GREEN),
 ('2B-2', '版本二 目标板', '2B SOC 板线', 'SOC 板设计投产',
  '原理图、layout、评审记录、投产回执（参考 FS03 硬件包；选 DR1V90 可参考 DR1V90 核心板交接包）',
  '评审通过、投产',
  '1-3、2B-1',
  '→ 2B-3：T2 实物', GRAY),
 ('2B-3', '版本二 目标板', '2B SOC 板线', 'SOC 板单板 bring-up',
  'bring-up 记录',
  '上电时序、启动、DDR 测试通过；接验证版 LED 侧（V1 + V2）跑通，链路误码为 0',
  '2B-2（台架来自 1-2）',
  '→ 2C-1：一块单独验证过的 T2；不用等 T1', GRAY),
 ('2C-1', '版本二 目标板', '2C 整机联调', '双面联调',
  '联调记录',
  'T2 驱动两块 T1，双面点亮，误码为 0',
  '2A-3、2B-3',
  '→ 2C-2：联调通过的整套电气系统', GRAY),
 ('2C-2', '版本二 目标板', '2C 整机联调', '上转子达标',
  '整机验收报告',
  '900 RPM 连续运转 · 体帧率 30 Hz · 整机功耗在 48 W 内；转子结构和动平衡由结构负责，硬件负责电气',
  '2C-1（功耗依据来自 2A-1）',
  '→ 版本二目标：整机达标', GRAY),
]
HDR1 = ['编号', '版本', '线', '小目标', '交付物', '验收判据', '前置', '支撑谁 · 提供什么', '负责人', '计划开始', '计划完成', '状态']
W1 = [7, 13, 12, 16, 34, 44, 20, 32, 11, 13, 13, 11]

# (编号, 版本, 板, 是什么, 连接)
BOARDS = [
 ('V1', '版本一', 'LED 灯板', '在现役灯板基础上改板，装 12 颗 2260。改动见《04 灯板改动清单》', '邮票孔 → V2'),
 ('V2', '版本一', '桥板', '放桥接 FPGA：下行驱动 V1 的 2260，上行接收 SOC 数据；自研还是用核心板由硬件评估（1-1）', '邮票孔 → V1；模组间接口 → V3'),
 ('V3', '版本一', 'FS03 转接板', '把 FS03 的 CEP1/CEP2 排针转成模组间接口；补地是核心。依据见《05 转接板接口与拓扑》', '排针 → FS03；模组间接口 → V2'),
 ('T1', '版本二', 'LED 板 ×2', 'V1 + V2 合并：桥接 FPGA 直接贴片，24 颗 2260，192×216，无邮票孔；屏体按 2A-1 定（自制或 COB）；转子两面各一块', '模组间接口 → T2'),
 ('T2', '版本二', 'SOC 板', 'FS03 + V3 合并：自研 SOC 板，主 SOC 按 2B-1 定；直接引出模组间接口', '模组间接口 → T1 ×2'),
]
HDR2 = ['编号', '版本', '板', '是什么', '连接']
W2 = [7, 9, 13, 60, 30]


def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def col(i):
    return chr(65 + i)


def cell(ref, val, st):
    if val == '':
        return f'<c r="{ref}" s="{st}"/>'
    return f'<c r="{ref}" s="{st}" t="inlineStr"><is><t xml:space="preserve">{esc(val)}</t></is></c>'


def sheet(hdr, widths, body, nfill, selected):
    ncol = len(hdr)
    cols = ''.join(f'<col min="{i+1}" max="{i+1}" width="{w}" customWidth="1"/>' for i, w in enumerate(widths))
    hs = [1] * (ncol - nfill) + [2] * nfill
    rows = [f'<row r="1" ht="30.0" customHeight="1">' +
            ''.join(cell(f'{col(i)}1', h, hs[i]) for i, h in enumerate(hdr)) + '</row>']
    for r, (vals, styles, ht) in enumerate(body, start=2):
        rows.append(f'<row r="{r}" ht="{ht}" customHeight="1">' +
                    ''.join(cell(f'{col(i)}{r}', v, styles[i]) for i, v in enumerate(vals)) + '</row>')
    last = f'{col(ncol-1)}{len(body)+1}'
    tab = ' tabSelected="1"' if selected else ''
    return ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            f'<dimension ref="A1:{last}"/><sheetViews><sheetView{tab} zoomScale="100" workbookViewId="0">'
            '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
            '<selection pane="bottomLeft" activeCell="A2" sqref="A2"/></sheetView></sheetViews>'
            f'<sheetFormatPr defaultRowHeight="15"/><cols>{cols}</cols><sheetData>{"".join(rows)}</sheetData>'
            '<pageMargins left="0.5" right="0.5" top="0.6" bottom="0.6" header="0.3" footer="0.3"/></worksheet>')


b1 = [([rid, ver, line, goal, dlv, acc, pre, sup, '', '', '', ''],
       [tint, 4, 4, 5, 3, 3, 3, 3, 6, 7, 7, 6], 72.0)
      for rid, ver, line, goal, dlv, acc, pre, sup, tint in ROWS]
b2 = [([bid, ver, name, what, conn], [5, 4, 5, 3, 3], 36.0) for bid, ver, name, what, conn in BOARDS]

zin = zipfile.ZipFile(SRC)
zout = zipfile.ZipFile(DST, 'w', zipfile.ZIP_DEFLATED)
for n in zin.namelist():
    data = zin.read(n)
    if n == 'xl/worksheets/sheet1.xml':
        data = sheet(HDR1, W1, b1, 4, True).encode()
    elif n == 'xl/worksheets/sheet2.xml':
        data = sheet(HDR2, W2, b2, 0, False).encode()
    elif n in ('xl/workbook.xml', 'docProps/app.xml'):
        data = (data.decode().replace('任务表', '小目标').replace('交付物', '小目标')
                .replace('关键节点', '板清单').encode())
    zout.writestr(n, data)
zout.close()
print('ok', DST)
