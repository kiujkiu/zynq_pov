# -*- coding: utf-8 -*-
"""GW5A 转 LED 灯板转接板 —— 逐球引脚分配表 (2026-09-16, 回复硬件 V01 原理图"高云引脚不够")

纯标准库 (zipfile 手写 OOXML)。
用法:
    python3 GW5A转LED转接板_逐球引脚分配_mkxlsx.py 输出目录
产物 (输出目录下):
    GW5A转LED转接板_逐球引脚分配_2026-09-16.xlsx
    gw5a_led_adapter.cst          Gowin 管脚约束 (工具试布局布线用, 也给固件)
    pinplan.json                  全部分配数据 (HTML 渲染用)

【输入 (只读)】
  V3_XLSX  pov3d/POV3D_接口交付包_v3_2026-09-15/02_DR1V90主控_GW5A桥接模块_对接关系表_v3_2026-09-15.xlsx
           sheet "GW5A_ACG525-CORE-V2连接器全表" (P1/P2 200 脚: 网名/球位/bank/対偶/配置复用, 09-15 已与核心板原理图逐脚核过)
           sheet "模组间接口契约" (契约 72 位) / "验证板实现-LED侧_GW5A_ACG525" (上行 20 対 + 边带 + JTAG 球位)
  HW_PDF   C:/Users/wanqi.liu/Downloads/高云转LED灯转接板.pdf (硬件 V01 原理图 "FPGA LVDS CONNETC V01", 09-16)
           pdftotext -bbox 取 CN1~CN4 逐脚网名与 R5~R140 0Ω 的两端网名; U1~U4 通道对应 (8 路 ×4) 为读图录入

【口径 (09-16 与用户对齐)】
  - ACK_O 12 根直连 FPGA (不走 mux); ACK_I 12 根不进 FPGA, 每根 100k 上拉 VDDD
  - 上行按契约 20 対 (UL_D[17:0]+UL_CHK+UL_CLK) + 边带 4 + JTAG 4, 球位沿用对接表 v3 (bank4/5 = Bottom, 3.3V)
  - 下行 48 対 = 12 组 × (CLK + D0/B + D1/G + D2/R), 12 対时钟 FPGA 直出; 链号 c: c=0 ↔ 灯板 CLKI/SDI*, c=k ↔ CLKOk/SDO*k
  - 结果: 154 个 IO 全用 (零余量), bank0/1 的 8 个 1.5V 脚放 ACK_O
"""
import json, os, re, subprocess, sys, zipfile, html
import xml.etree.ElementTree as ET
from collections import Counter, OrderedDict

ROOT = '/mnt/d/claude_workspace/pov3d'
V3_XLSX = ROOT + '/POV3D_接口交付包_v3_2026-09-15/02_DR1V90主控_GW5A桥接模块_对接关系表_v3_2026-09-15.xlsx'
HW_PDF = '/mnt/c/Users/wanqi.liu/Downloads/高云转LED灯转接板.pdf'
DATE = '2026-09-16'
XLSX_NAME = f'GW5A转LED转接板_逐球引脚分配_{DATE}.xlsx'

# ---------------------------------------------------------------- 读 v3 xlsx
NS = {'m': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}


def read_xlsx(path):
    z = zipfile.ZipFile(path)
    ss = []
    if 'xl/sharedStrings.xml' in z.namelist():
        for si in ET.fromstring(z.read('xl/sharedStrings.xml')).findall('m:si', NS):
            ss.append(''.join(t.text or '' for t in si.iter('{%s}t' % NS['m'])))
    wb = ET.fromstring(z.read('xl/workbook.xml'))
    rels = {r.get('Id'): r.get('Target') for r in ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))}
    out = OrderedDict()
    for s in wb.find('m:sheets', NS):
        rid = s.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id')
        tgt = rels[rid].lstrip('/')
        tgt = tgt if tgt.startswith('xl/') else 'xl/' + tgt
        rows = []
        for row in ET.fromstring(z.read(tgt)).iter('{%s}row' % NS['m']):
            vals = {}
            for c in row.findall('m:c', NS):
                col = re.match(r'[A-Z]+', c.get('r')).group(0)
                idx = 0
                for ch in col:
                    idx = idx * 26 + ord(ch) - 64
                t = c.get('t'); v = c.find('m:v', NS); is_ = c.find('m:is', NS)
                if t == 's' and v is not None:
                    x = ss[int(v.text)]
                elif t == 'inlineStr' and is_ is not None:
                    x = ''.join(tt.text or '' for tt in is_.iter('{%s}t' % NS['m']))
                else:
                    x = v.text if v is not None else ''
                vals[idx - 1] = x
            if vals:
                rows.append([vals.get(i, '') for i in range(max(vals) + 1)])
        out[s.get('name')] = rows
    return out


def table(rows, key0):
    """首列等于 key0 的行作表头, 其后行转 dict"""
    i = next(k for k, r in enumerate(rows) if r and r[0] == key0)
    hdr = rows[i]
    return [dict(zip(hdr, r + [''] * (len(hdr) - len(r)))) for r in rows[i + 1:]]


v3 = read_xlsx(V3_XLSX)
CORE = [r for r in table(v3['GW5A_ACG525-CORE-V2连接器全表'], '连接器.脚号') if re.fullmatch(r'P[12]\.\d+', r['连接器.脚号'])]
assert len(CORE) == 200
BYPIN = {r['连接器.脚号']: r for r in CORE}
BYNET = {r['核心网名']: r for r in CORE if r['核心网名'] not in ('GND', 'VCC3P3', 'VCCIO23', 'VCCIO45', 'VCCIO01', 'VCCIO67')}
IO_NETS = [r['核心网名'] for r in CORE if re.fullmatch(r'B\d+_[TBLR]\d+(_CK)?_[PN]', r['核心网名'])]
assert len(IO_NETS) == 154, len(IO_NETS)
CONTRACT = [r for r in table(v3['模组间接口契约'], '契约位置号 (建议脚序)') if r['契约位置号 (建议脚序)'].isdigit()]
CONTRACT = [r for r in CONTRACT if 1 <= int(r['契约位置号 (建议脚序)']) <= 72]
assert len(CONTRACT) == 72
LEDV3 = [r for r in table(v3['验证板实现-LED侧_GW5A_ACG525'], '契约位置') if r['契约位置'].isdigit()]
assert len(LEDV3) == 48


def vccio(net):
    g = BYNET[net]['VCCIO 组 (电压来源)']
    for k, v in (('VCCIO23', 2.5), ('VCCIO45', 3.3), ('VCCIO67', 2.5), ('VCCIO01', 1.5)):
        if g.startswith(k):
            return k, v
    raise ValueError(net)


def pair_ok(base):
    p, n = BYNET.get(base + '_P'), BYNET.get(base + '_N')
    return p and n and p['対完整性'].startswith('完整対') and n['対完整性'].startswith('完整対') and p['対偶球'] == n['球位']


# ---------------------------------------------------------------- 读硬件 V01 原理图
def pdf_words(pdf):
    out = subprocess.run(['pdftotext', '-bbox', pdf, '-'], capture_output=True, check=True).stdout.decode('utf-8')
    return [(float(m[1]), float(m[2]), float(m[3]), float(m[4]), html.unescape(m[5]))
            for m in re.finditer(r'<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" yMax="([\d.]+)">(.*?)</word>', out)]


W = pdf_words(HW_PDF)
CORE_RE = re.compile(r'B\d+_[TBLR]\d+(_CK)?_[PN]$')


def parse_connectors():
    res = {}
    for t in [w for w in W if w[4] in ('CN1', 'CN2', 'CN3', 'CN4')]:
        tx, ty = t[0], t[1]
        nums = [w for w in W if re.fullmatch(r'\d+', w[4]) and tx - 20 <= w[0] <= tx + 45 and ty < w[1] < ty + 390]
        xs = sorted(round(w[0]) for w in nums)
        oddx, evenx = xs[0], xs[-1]
        pins = {}
        for outer, xr in (([w for w in nums if w[0] < tx and int(w[4]) % 2 == 1], (tx - 160, oddx - 3)),
                          ([w for w in nums if w[0] >= tx + 33 and int(w[4]) % 2 == 0], (evenx + 6, evenx + 160))):
            for pw in outer:
                yl = pw[1] - 1.7
                pins[int(pw[4])] = [w[4] for w in sorted(w for w in W if xr[0] <= w[0] <= xr[1] and abs(w[1] - yl) < 0.8)]
        assert sorted(pins) == list(range(1, 101)), (t[4], len(pins))
        res[t[4]] = pins
    return res


def parse_resistors():
    ym = lambda w: (w[1] + w[3]) / 2
    out = {}
    for r in [w for w in W if re.fullmatch(r'R\d+', w[4]) and w[1] > 520]:
        n = int(r[4][1:])
        row = [w for w in W if abs(ym(w) - ym(r)) < 2.0]
        L = sorted([w for w in row if w[2] <= r[0] + 0.5 and r[0] - w[2] < 160], key=lambda w: r[0] - w[2])
        R = sorted([w for w in row if w[0] >= r[2] - 0.5 and w[0] - r[2] < 170], key=lambda w: w[0] - r[2])
        if 5 <= n <= 100:
            out[n] = dict(led=L[0][4], core=next(w[4] for w in R if CORE_RE.match(w[4])))
        elif 101 <= n <= 140:
            out[n] = dict(core=next(w[4] for w in L if CORE_RE.match(w[4])), dr1v=next(w[4] for w in R if w[4].startswith('DR1V_')),
                          fpc=next(w[4] for w in R if re.fullmatch(r'\d+', w[4]) and w[0] - r[2] > 40))
    assert sorted(out) == list(range(5, 141)), sorted(set(range(5, 141)) - set(out))
    return out


HWCN = parse_connectors()
HWR = parse_resistors()
# CN3 = 核心板 P1, CN4 = P2: 逐脚网名核对
for cn, p in (('CN3', 'P1'), ('CN4', 'P2')):
    for k in range(1, 101):
        net = BYPIN[f'{p}.{k}']['核心网名']
        if re.fullmatch(r'B\d+_[TBLR]\d+(_CK)?_[PN]|MIPI_\w+|FPGA_T\w+', net):
            assert net in HWCN[cn][k], (cn, k, net, HWCN[cn][k])
LED_CN = {}
for cn in ('CN1', 'CN2'):
    for k, labs in HWCN[cn].items():
        for l in labs:
            assert l not in LED_CN, l
            LED_CN[l] = f'{cn}.{k}'
V01_LED2CORE = {v['led']: (f'R{n}', v['core']) for n, v in HWR.items() if n <= 100}
V01_CORE = {}  # core net → V01 用途
for n, v in HWR.items():
    if n <= 100:
        V01_CORE[v['core']] = f"R{n} → 灯板 {v['led']}"
    else:
        V01_CORE[v['core']] = f"R{n} → FPC1.{v['fpc']} {v['dr1v']}"
# U1~U4 通道 (读图录入, 原理图 A_k ↔ B_k)
V01_XLT = {
    'U1': [('B4_B29_N', '4ACK_I'), ('B4_B52_N', '4ACK_O'), ('B3_B87_P', '3ACK_I'), ('B2_R24_P', '3ACK_O'),
           ('B5_B2_P', '2ACK_I'), ('B5_B18_N', '2ACK_O'), ('B7_T11_P', '1ACK_I'), ('B7_T11_N', '1ACK_O')],
    'U2': [('B6_L5_CK_P', '6ACK_I'), ('B6_L5_CK_N', '6ACK_O'), (None, '5ACK_I'), (None, '5ACK_O'),
           (None, '8ACK_I'), (None, '8ACK_O'), (None, '7ACK_I'), (None, '7ACK_O')],
    'U3': [('B1_T91_N', '12ACK_I'), ('B1_T91_P', '12ACK_O'), ('B1_T87_N', '11ACK_I'), ('B1_T87_P', '11ACK_O'),
           ('B1_T89_N', '10ACK_I'), ('B1_T89_P', '10ACK_O'), ('B0_T58_P', '9ACK_I'), ('B0_T58_N', '9ACK_O')],
    'U4': [(None, 'RSTN'), (None, 'SYNC1'), (None, 'SYNC2'), (None, 'SYNC3')],
}
for u, chs in V01_XLT.items():
    for i, (core, led) in enumerate(chs):
        assert led in LED_CN, led
        if core:
            assert core not in V01_CORE, core
            V01_CORE[core] = f'{u}.A{i + 1} ↔ 灯板 {led} (电平转换)'
for k, j in ((94, 'FPGA_TDO'), (96, 'FPGA_TDI'), (98, 'FPGA_TMS'), (100, 'FPGA_TCK')):
    V01_CORE[j] = 'CN5 JTAG 座 (未上 FPC)'
assert all(n in V01_CORE for n in IO_NETS), [n for n in IO_NETS if n not in V01_CORE]

# ---------------------------------------------------------------- 分配
LANES = ['CLK', 'D0', 'D1', 'D2']
LANE_CH = {'CLK': '时钟', 'D0': 'B 通道 (lane0)', 'D1': 'G 通道 (lane1)', 'D2': 'R 通道 (lane2)'}


def led_nets(c, lane):
    if c == 0:
        return {'CLK': ('CLKIP', 'CLKIN'), 'D0': ('SDIB1_D0IP', 'SDIB2_D0IN'), 'D1': ('SDIG1_D1IP', 'SDIG2_D1IN'), 'D2': ('SDIR1_D2IP', 'SDIR2_D2IN')}[lane]
    return {'CLK': (f'CLKOP{c}', f'CLKON{c}'), 'D0': (f'SDOB1_D0OP{c}', f'SDOB2_D0ON{c}'),
            'D1': (f'SDOG1_D1OP{c}', f'SDOG2_D1ON{c}'), 'D2': (f'SDOR1_D2OP{c}', f'SDOR2_D2ON{c}')}[lane]


def fpga_sig(c, lane):
    return f'SCR_CLK[{c}]' if lane == 'CLK' else f'SCR_D[{c * 3 + LANES.index(lane) - 1}]'


def base(net):
    return net[:-2]


# V01 基底 (按灯板 P 网取 core, 去 _P/_N)
V01_BASE = {}
for c in range(12):
    for lane in LANES:
        p, n = led_nets(c, lane)
        assert p in LED_CN and n in LED_CN, (p, n)
        V01_BASE[(c, lane)] = base(V01_LED2CORE[p][1])
DOWN = {
    0: ['B7_T15', 'B7_T7', 'B7_T25', 'B7_T23'],
    1: ['B7_T17', 'B7_T1', 'B7_T3', 'B7_T9'],
    2: ['B7_T27', 'B7_T19', 'B7_T11', 'B7_T13'],
    3: ['B6_L3_CK', 'B6_L12', 'B6_L14', 'B6_L18'],
    4: ['B6_L21', 'B6_L5_CK', 'B6_L9', 'B6_L16'],
    5: ['B5_B8', 'B5_B12', 'B7_T21', 'B2_R16'],
}
for c in range(6, 12):
    DOWN[c] = [V01_BASE[(c, l)] for l in LANES]
assert DOWN[10][2] == 'B3_B71'
DOWN[10][2] = 'B3_B67'  # B3_B71 按 v3 给边带 SB_RSTN / SB_UART_S2B

UPLINK = {}  # net → dict
for r in LEDV3:
    UPLINK[r['核心网名']] = r

# ACK_O 与屏侧单端 (A 口 = FPGA 侧)
XLT = OrderedDict()
XLT['T1'] = dict(vcca='1.5V (取核心板 VCCIO01 = P1.9/P1.10, 只作参考电源)', dir='B→A (灯板→FPGA)', bank='VCCIO01 (bank0/1, DDR3 组)', chs=[
    ('B1_T91_N', '8ACK_O'), ('B1_T91_P', '12ACK_O'), ('B1_T87_N', '7ACK_O'), ('B1_T87_P', '11ACK_O'),
    ('B1_T89_N', '6ACK_O'), ('B1_T89_P', '10ACK_O'), ('B0_T58_P', '5ACK_O'), ('B0_T58_N', '9ACK_O')])
XLT['T2'] = dict(vcca='3.3V (VCCIO45 同轨)', dir='B→A (灯板→FPGA)', bank='VCCIO45 (bank4/5 半対)', chs=[
    ('B4_B29_N', '3ACK_O'), ('B4_B52_N', '4ACK_O'), ('B5_B2_P', '1ACK_O'), ('B5_B18_N', '2ACK_O'),
    (None, None), (None, None), (None, None), (None, None)])
XLT['T3'] = dict(vcca='2.5V (VCCIO23 同轨)', dir='A→B (FPGA→灯板)', bank='VCCIO23 (bank2/3 半対)', chs=[
    ('B2_R24_P', 'RSTN'), ('B3_B87_P', 'SYNC1'), ('B3_B87_P', 'SYNC2'), ('B3_B87_P', 'SYNC3'),
    (None, None), (None, None), (None, None), (None, None)])

A = OrderedDict()  # core net → 分配记录


def put(net, **kw):
    assert net in BYNET, net
    assert net not in A, (net, A.get(net), kw)
    A[net] = kw


for c in range(12):
    for li, lane in enumerate(LANES):
        b = DOWN[c][li]
        assert pair_ok(b), b
        pl, nl = led_nets(c, lane)
        for pn, ln in (('P', pl), ('N', nl)):
            vg, vv = vccio(f'{b}_{pn}')
            put(f'{b}_{pn}', cls='下行 LVDS', sig=f'{fpga_sig(c, lane)}_{pn}', pn=pn, dir='FPGA→灯板', chain=c, lane=lane,
                iotype=f'LVDS25 (TLVDS_OBUF) BANK_VCCIO={vv}', peer=f'0Ω → 灯板 {ln} ({LED_CN[ln]})', led=ln)
for net, r in UPLINK.items():
    sig = r['信号名']
    if sig.startswith('UL_'):
        put(net, cls='上行 LVDS', sig=sig, pn=r['P/N'], dir='SoC→FPGA', pos=int(r['契约位置']),
            iotype='LVDS25 (TLVDS_IBUF) DIFF_RESISTOR=ON BANK_VCCIO=3.3', peer=f"FPC 契约位 {r['契约位置']}", phase=r['阶段'])
    elif sig.startswith('SB_'):
        d = 'SoC→FPGA' if sig in ('SB_RSTN', 'SB_UART_S2B') else 'FPGA→SoC'
        put(net, cls='边带', sig=sig, pn='单端', dir=d, pos=int(r['契约位置']), iotype='LVCMOS25 BANK_VCCIO=2.5',
            peer=f"FPC 契约位 {r['契约位置']} (对接表 v3 球位不变)", phase=r['阶段'])
for t, x in XLT.items():
    for i, (core, led) in enumerate(x['chs']):
        if not core or core in A:
            continue
        vg, vv = vccio(core)
        if led.endswith('ACK_O'):
            put(core, cls='ACK 回读', sig=f'ACK_O{led[:-5]}', pn='单端', dir='灯板→FPGA', iotype=f'LVCMOS{str(vv).replace(".", "")} BANK_VCCIO={vv} (输入)',
                peer=f'{t}.A{i + 1} ↔ {t}.B{i + 1} ↔ 灯板 {led} ({LED_CN[led]})', led=led, xlt=t)
        elif led == 'RSTN':
            put(core, cls='屏控制', sig='PANEL_RSTN', pn='单端', dir='FPGA→灯板', iotype='LVCMOS25 BANK_VCCIO=2.5',
                peer=f'{t}.A{i + 1} → 灯板 RSTN ({LED_CN["RSTN"]})', led='RSTN', xlt=t)
        elif led.startswith('SYNC'):
            put(core, cls='屏控制', sig='I_SYNC', pn='单端', dir='FPGA→灯板', iotype='LVCMOS25 BANK_VCCIO=2.5',
                peer=f'{t}.A2/A3/A4 并联 → 灯板 SYNC1/SYNC2/SYNC3 ({LED_CN["SYNC1"]}/{LED_CN["SYNC2"]}/{LED_CN["SYNC3"]})', led='SYNC1~3', xlt=t)

# ---------------------------------------------------------------- 断言
assert sorted(A) == sorted(IO_NETS), (set(IO_NETS) - set(A), set(A) - set(IO_NETS))
cnt = Counter(v['cls'] for v in A.values())
assert cnt == {'下行 LVDS': 96, '上行 LVDS': 40, '边带': 4, 'ACK 回读': 12, '屏控制': 2}, cnt
for net, v in A.items():
    if 'LVDS' in v['cls']:
        assert net.endswith('_' + v['pn']), net                      # P 信号落 P 球
        assert BYNET[net]['対完整性'].startswith('完整対'), net
    vg, vv = vccio(net)
    assert f'BANK_VCCIO={vv}' in v['iotype'], (net, v['iotype'])      # IO 电压 = bank 组电压
# 同一 VCCIO 组 IO 电压唯一
for g in ('VCCIO23', 'VCCIO45', 'VCCIO67', 'VCCIO01'):
    assert len({re.search(r'BANK_VCCIO=([\d.]+)', v['iotype']).group(1) for n, v in A.items() if vccio(n)[0] == g}) == 1, g
# 上行 = v3 LED 侧逐球
for r in LEDV3:
    if r['核心网名'].startswith('B'):
        assert A[r['核心网名']]['sig'] == r['信号名'] and BYNET[r['核心网名']]['连接器.脚号'] == r['核心板连接器.脚号']
up_bases = {base(n) for n, v in A.items() if v['cls'] == '上行 LVDS'}
assert up_bases == {b for b in {base(n) for n in IO_NETS} if b.startswith('B4_') and pair_ok(b)} | {'B5_B20', 'B5_B16', 'B5_B24', 'B5_B6', 'B5_B26', 'B5_B22', 'B5_B14', 'B5_B4', 'B5_B10'}
assert all(v['cls'] != '上行 LVDS' for n, v in A.items() if BYNET[n]['分区'] in ('Left', 'Right'))   # 上行不进 bank2/6
# 灯板 LVDS 网 96 根各出现一次
leds = [v['led'] for v in A.values() if v['cls'] == '下行 LVDS']
assert len(leds) == 96 == len(set(leds))
# ACK_O 12 根各一次, ACK_I 不进 FPGA
acks = sorted(v['led'] for v in A.values() if v['cls'] == 'ACK 回读')
assert acks == sorted(f'{i}ACK_O' for i in range(1, 13)), acks
assert not any('ACK_I' in str(v.get('led')) for v in A.values())
# bank0/1 只放输入
assert all(A[n]['dir'] == '灯板→FPGA' for n in IO_NETS if vccio(n)[0] == 'VCCIO01')


# 改动判定
def v01_of(net):
    return V01_CORE[net]


def change_of(net):
    v, old = A[net], V01_CORE[net]
    if v['cls'] == '下行 LVDS':
        m = re.match(r'R(\d+) → 灯板 (\S+)', old)
        if m and m.group(2) == v['led']:
            return '不变'
        return '改接'
    if v['cls'] == 'ACK 回读':
        m = re.match(r'U\d\.A\d ↔ 灯板 (\S+)', old)
        if m and m.group(1) == v['led']:
            return '信号不变, 转换器改'
        return '改接'
    return '改接'


for n in A:
    A[n]['v01'] = V01_CORE[n]
    A[n]['chg'] = change_of(n)
CHG = Counter(A[n]['chg'] for n in A)

# 下行按芯片逐行 (含 V01 位号)
DOWN_ROWS = []
for c in range(12):
    for li, lane in enumerate(LANES):
        for pn in 'PN':
            b = DOWN[c][li]; net = f'{b}_{pn}'; r = BYNET[net]; v = A[net]
            ln = v['led']; rid, oldcore = V01_LED2CORE[ln]
            DOWN_ROWS.append(OrderedDict([
                ('链 c', c), ('灯板组 (V01 网名后缀)', 'I' if c == 0 else str(c)), ('lane', LANE_CH[lane]), ('FPGA 信号', v['sig']),
                ('灯板网名', ln), ('灯板连接器脚', LED_CN[ln]), ('0Ω 位号 (V01)', rid),
                ('核心板连接器脚 (CN3=P1 / CN4=P2)', r['连接器.脚号']), ('核心网名', net), ('球位', r['球位']), ('bank', r['bank']), ('分区', r['分区']),
                ('VCCIO', f"{vccio(net)[0]} {vccio(net)[1]}V"), ('V01 原接', oldcore), ('改动', '不变' if oldcore == net else '改接'),
                ('备注', ''),
            ]))


def note_for(net):
    r = BYNET[net]; notes = []
    if r['分区'] in ('Left', 'Right') and A[net]['cls'] == '下行 LVDS':
        notes.append('bank2/6 (Left/Right): DS1103 表 2-11 注[3] 速率偏低, 332 Mbps 未验证 (v3 D11)')
    cfg = r['配置复用 (UG985 口径)']
    if cfg:
        notes.append(f'配置复用 {cfg}: 综合时在 Dual-Purpose Pin 放开为 GPIO')
    b = base(net)
    if b in ('B5_B8', 'B5_B12'):
        notes.append('v3 原留空的余量対; 同排/对排是上行阶段二 lane (UL_D[13]/[15]/[16]/[17], 阶段一不跑数据)')
    if b == 'B3_B65':
        notes.append('v3 原作隔离対 (紧邻上行 P1.29/30), 零余量下改作下行')
    if b in ('B2_R7', 'B2_R9'):
        notes.append('与 JTAG P1.94~100 面对面 (v3 sheet4)')
    if net in ('B4_B29_N', 'B4_B52_N'):
        notes.append('紧邻上行 UL_D[0] (P1.16/18) / UL_CLK (P1.19/21): 转换器 A 口出串 330Ω 放缓边沿')
    if net in ('B5_B2_P', 'B5_B18_N'):
        notes.append('紧邻上行 UL_D[16]/[17] (P2.67~77, 阶段二 lane): A 口出串 330Ω')
    if net in ('B7_T21_N', 'B6_L5_CK_P') or base(net) == 'B6_L3_CK':
        notes.append('与边带 P2.32/P2.34 相邻 (v3 已记: GW5A 输出限摆率)')
    if vccio(net)[0] == 'VCCIO01':
        notes.append('bank0/1 与 DDR3 同 bank, VCCIO 锁 1.5V')
    if A[net]['cls'] == '下行 LVDS' and A[net]['chain'] == 5:
        notes.append('第 5 组 4 対跨 VCCIO45/67/23 与 CN3/CN4 两个连接器: 转接板上做组内等长')
    return '; '.join(notes)


for row in DOWN_ROWS:
    row['备注'] = note_for(row['核心网名'])
for n in A:
    A[n]['note'] = note_for(n)

# ---------------------------------------------------------------- 各 sheet 内容
S = OrderedDict()

readme = [
    ['GW5A 转 LED 灯板转接板 —— 逐球引脚分配表', ''],
    ['日期 / 版本', f'{DATE} · 对应硬件原理图 "FPGA LVDS CONNETC V01" (创建 09-14 / 更新 09-16) 的修改输入'],
    ['核心板', 'ACG525-CORE-V2 (GW5A-LV25UG324), 连接器 P1 = 转接板 CN3, P2 = CN4 (V01 原理图 168 个 IO 脚网名与本表逐脚核对 0 差异)'],
    ['数据来源', '核心板连接器 200 脚: 对接表 v3 (09-15, 与核心板原理图逐脚核过) · 上行/边带/JTAG 球位: 对接表 v3 LED 侧 · 灯板网名与 V01 现状: V01 原理图 PDF 机读'],
    ['', ''],
    ['一、口径', ''],
    ['ACK', 'ACK_O 12 根直连 FPGA (经电平转换, 不走 mux); ACK_I 12 根不进 FPGA, 每根 100kΩ 上拉到 VDDD (不级联时手册允许浮空, 上拉防串扰; "单颗能否回包"仍待 FAE 确认)'],
    ['上行', '按模组间接口契约: 20 対 LVDS (UL_D[17:0] + UL_CHK + UL_CLK) + 边带 4 + JTAG 4, 全部球位沿用对接表 v3 (上行在 bank4/5 = Bottom 3.3V)'],
    ['下行', '12 组 × (CLK + D0/B + D1/G + D2/R) = 48 対, 12 対时钟 FPGA 直出; 链号 c=0 ↔ 灯板 CLKI/SDI*, c=k ↔ CLKOk/SDO*k (与 RTL scr_d[c×3+lane] 一致)'],
    ['屏控制', 'PANEL_RSTN 1 根; I_SYNC 1 根, 在转换器上并成 SYNC1/2/3 三路 (同 V01 做法)'],
    ['', ''],
    ['二、引脚账', ''],
    ['可用', '核心板连接器 73 完整対 + 8 半対 = 154 IO (MIPI 5 対为 D-PHY 专用不可用; JTAG 在 bank10 专用不占 IO)'],
    ['占用', f"下行 96 + 上行 40 + 边带 4 + ACK_O 12 + RSTN 1 + SYNC 1 = {len(A)} ⇒ 154/154, 零余量"],
    ['差分対', '2.5/3.3V 可用 69 対, 用 68 対 (下行 48 + 上行 20); 剩 1 対 (B3_B71) 按 v3 拆作边带单端'],
    ['单端', 'bank0/1 (1.5V, 与 DDR3 同 bank) 8 脚 → ACK_O×8 (全是输入); bank4/5 半対 4 脚 (3.3V) → ACK_O×4; bank2/3 半対 2 脚 (2.5V) → RSTN / SYNC; bank6/7 半対 2 脚 + B3_B71 → 边带 4'],
    ['与 V01 相比', f"154 脚中 {CHG.get('不变', 0)} 脚不变, {CHG.get('信号不变, 转换器改', 0)} 脚信号不变但转换器要改, {CHG.get('改接', 0)} 脚改接 (明细见 V01改线清单)"],
    ['', ''],
    ['三、必须改的 (V01 → V02)', ''],
    ['1', '上行 20 対从 bank6/7 挪到 bank4/5 (v3 球位); bank2/6 手册注明速率偏低, 800M 上行不能放 (DS1103 表 2-11 注[3])'],
    ['2', 'FPC: 18 対 → 契约 20 対 + 边带 4 + JTAG 4, 按契约 72 位 G-S-S-G 排, 60P 座子不够 (本表 sheet "上行FPC_契约72位")'],
    ['3', 'ACK_I 不接 FPGA, 改 100kΩ 上拉 VDDD (灯板上紧靠芯片 N12; 灯板没做就放转接板 CN2 旁)'],
    ['4', '电平转换重排为 T1/T2/T3 三颗, 每颗单方向、单电压; SN74LVC8T245 两侧最低 1.65V 接不了 1.5V, T1 要换 1.1V 起的型号 (如 LXC8T245 类, 下单前核手册与脚位)'],
    ['5', 'V01 两对 P/N 接反 (R49/R50、R51/R52): 本表第 5 组已按 P→P 重排'],
    ['6', 'VCCIO01 (P1.9/10) 与 VCCIO67 (P2.97/99) 是核心板自产, 转接板不许往里供电; VCC3P3 (P1.1~4)、VCCIO23 2.5V (P1.5/7)、VCCIO45 3.3V (P1.6/8) 由转接板供 (V01 页上没有电源部分)'],
    ['', ''],
    ['四、零余量的代价 (知情选择)', ''],
    ['a', '9-09 接口里的 EN_3V8 / EN_2V8 两根电源使能放不下 (灯板电源不归 FPGA 管)'],
    ['b', '下行有 21 対在 bank2/6 (第 3/4/6/7/8 组 + 第 5 组 R), 332 Mbps 未验证 (v3 D11); 跑不了没有备用脚可挪'],
    ['c', 'v3 留空的余量対 B5_B8/B5_B12 与隔离対 B3_B65 都用掉了 (前两者邻近的是上行阶段二 lane, 阶段一影响小)'],
    ['d', '转换器 OE# 没有脚控制 ⇒ 常使能; RSTN 靠 FPGA 侧 2.2kΩ 下拉保证配置期间屏保持复位'],
    ['e', '想留余量: ACK_O 改 2×8:1 mux 可空出 7 脚 (bank0/1 的 8 个 1.5V 脚几乎全部腾空)'],
    ['', ''],
    ['五、工具验证', 'gw5a_led_adapter.cst 已用 Gowin V1.9.12.03 对 GW5A-LV25UG324C2/I1 (device_version A、B) 布局布线出 bit: 154 端口球位/电平与本表 0 差异, 0 错误 0 警告 (明细见 sheet "余量与待定")'],
    ['固件注意', '工程必须 set_option -use_sspi_as_gpio 1 / -use_i2c_as_gpio 1 / -use_cpu_as_gpio 1, 否则 B5_B8/B5_B12/B5_B14/B5_B4/B5_B10 报 PR2017 (JTAG、MSPI 不许放开)'],
]
S['说明'] = dict(header=None, rows=readme, widths=[22, 150])

core_rows = []
for r in CORE:
    pin, net = r['连接器.脚号'], r['核心网名']
    cn = 'CN3' if pin.startswith('P1') else 'CN4'
    v = A.get(net)
    if v:
        use, sig, d, io, peer, old, chg, note = v['cls'], v['sig'], v['dir'], v['iotype'], v['peer'], v['v01'], v['chg'], v['note']
    elif net.startswith('FPGA_T'):
        use, sig, d = 'JTAG (bank10 专用)', 'JTAG_' + net[5:], ('FPGA→SoC' if net == 'FPGA_TDO' else 'SoC→FPGA')
        io = 'LVCMOS33 (bank10 固定 3.3V)'; pos = {'FPGA_TCK': 68, 'FPGA_TMS': 70, 'FPGA_TDI': 71, 'FPGA_TDO': 72}[net]
        peer = f'T4 (2.5V↔3.3V) ↔ FPC 契约位 {pos}; 0Ω 二选一接 CN5 下载座'; old = V01_CORE[net]; chg = '改接'; note = '转换与上下拉按对接表 v3 规划·JTAG'
    elif net.startswith('MIPI'):
        use, sig, d, io, peer, old, chg, note = 'MIPI D-PHY 专用', '—', '—', '—', '不接', '未用', '不变', '硬核专用脚, 不能当 GPIO'
    elif net == 'GND':
        use, sig, d, io, peer, old, chg, note = '地', 'GND', '—', '—', '转接板地平面', 'GND', '不变', ''
    else:
        use, sig, d, io = '电源', net, '—', '—'
        peer = {'VCC3P3': '转接板供 3.3V (干净, 核心板 VCCX 由此来)', 'VCCIO23': '转接板供 2.5V', 'VCCIO45': '转接板供 3.3V',
                'VCCIO01': '核心板自产 1.5V: 不许供电; 可作 T1 的 VCCA 参考', 'VCCIO67': '核心板自产 2.5V: 不许供电'}[net]
        old, chg, note = net, '不变', ''
    core_rows.append([cn + '.' + pin.split('.')[1], pin, net, r['FPGA 管脚'], r['球位'], r['bank'], r['分区'], r['VCCIO 组 (电压来源)'].split('(')[0].strip(),
                      r['P或N'], r['対偶球'], r['配置复用 (UG985 口径)'], r['GCLK / PLL (UG985 口径)'],
                      use, sig, d, io, peer, old, chg, note])
S['核心板连接器逐脚'] = dict(header=['转接板脚', '核心板脚', '核心网名', 'GW5A 管脚', '球位', 'bank', '分区', 'VCCIO 组', 'P/N', '対偶球', '配置复用', 'GCLK/PLL',
                                 '用途', '信号名', '方向', 'IO 标准 (约束)', '对端 / 走向', 'V01 原接', '改动', '备注'],
                         rows=core_rows, widths=[9, 8, 13, 10, 6, 5, 7, 22, 5, 9, 16, 16, 11, 16, 11, 30, 44, 34, 12, 60], chgcol=18)

S['下行_按芯片'] = dict(header=list(DOWN_ROWS[0].keys()), rows=[list(r.values()) for r in DOWN_ROWS],
                     widths=[5, 9, 13, 16, 15, 10, 9, 14, 13, 6, 5, 7, 13, 13, 7, 70], chgcol=14)

fpc_rows = []
for r in CONTRACT:
    pos = int(r['契约位置号 (建议脚序)']); sig = r['信号名']
    lv = next((x for x in LEDV3 if int(x['契约位置']) == pos), None)
    if sig == 'GND':
        fpc_rows.append([pos, 'GND', '—', '—', '地', '—', '—', '—', '—', '—', 'G-S-S-G 的地'])
        continue
    if lv['核心网名'].startswith('FPGA_T'):
        via = 'T4 电平转换 (2.5V↔3.3V) → 0Ω 选择 (与 CN5 下载座二选一)'
    else:
        if sig.startswith('UL_'):
            via = '直连 (上行: 桥侧片内 100Ω 端接, 不外加)'
        else:
            extra = re.sub(r'^待设计: 契约位置 \d+ → B2B P\d\.\d+;?\s*', '', lv['V2 底板 (待设计)']).strip()
            via = '直连 (LVCMOS25)' + (f'; {extra}' if extra else '')
    fpc_rows.append([pos, sig, r['对内 P/N'], r['方向'], r['信号类'], lv['阶段'], lv['核心板连接器.脚号'], lv['核心网名'], lv['球位'], lv['bank'], via])
S['上行FPC_契约72位'] = dict(header=['FPC 脚 = 契约位', '信号', 'P/N', '方向', '信号类', '阶段', '核心板脚', '核心网名', '球位', 'bank', '转接板上的处理'],
                          rows=fpc_rows, widths=[10, 14, 5, 10, 12, 8, 9, 13, 6, 5, 50])

xrows = []
for t, x in XLT.items():
    for i, (core, led) in enumerate(x['chs']):
        if core:
            r = BYNET[core]
            xrows.append([t, f'A{i + 1}/B{i + 1}', x['dir'], x['vcca'], '灯板 VDDD 同轨 (V01 为 3V8, 以灯板为准)', r['连接器.脚号'], core, r['球位'], A[core]['sig'],
                          led, LED_CN[led],
                          ('A 口出串 330Ω; B 口 10kΩ 上拉 VDDD' if 'ACK' in led else
                           ('A 口 2.2kΩ 下拉 (配置期保持复位); B 口 10kΩ 下拉' if led == 'RSTN' else 'A 口预留下拉位 (DNP)'))])
        else:
            xrows.append([t, f'A{i + 1}/B{i + 1}', x['dir'], x['vcca'], '', '', '未用', '', '', '', '', '未用通道按所选型号手册处理 (输入不悬空)'])
for sig, pin, pos, d in (('JTAG_TCK', 'P1.100', 68, 'A→B'), ('JTAG_TMS', 'P1.98', 70, 'A→B'), ('JTAG_TDI', 'P1.96', 71, 'A→B'), ('JTAG_TDO', 'P1.94', 72, 'B→A')):
    r = BYPIN[pin]
    xrows.append(['T4 (JTAG)', sig[5:], d, 'A 口 2.5V (契约侧)', 'B 口 3.3V (bank10)', pin, r['核心网名'], r['球位'], sig, f'FPC 契约位 {pos}', '—',
                  '按对接表 v3 规划·JTAG: 固定方向带 Ioff; TCK A 口 2.2k 下拉/B 口 4.7k 下拉; TMS/TDI A 口 22k 上拉; TDO B 口 10k 下拉 (必须); TCK/TMS/TDI 0Ω 与 CN5 二选一'])
xrows.append(['—', 'ACK_I ×12', '—', '—', '—', '—', '不进 FPGA', '—', '—', '1ACK_I ~ 12ACK_I', 'CN2.77~98 (偶/奇)', '每根 100kΩ 上拉 VDDD (灯板靠近芯片 N12; 灯板未做则放 CN2 旁)'])
xrows.append(['OE#', '全部', '—', '—', '—', '—', '—', '—', '—', '—', '—', 'T1~T3 的 OE# 经 0Ω 接地常使能 (零余量, 无控制脚)'])
S['单端与电平转换'] = dict(header=['转换器', '通道', '方向', 'VCCA (FPGA 侧)', 'VCCB (灯板侧)', '核心板脚', '核心网名', '球位', 'FPGA 信号', '灯板网名', '灯板连接器脚', '上下拉 / 串阻'],
                        rows=xrows, widths=[9, 9, 14, 30, 26, 9, 12, 6, 12, 16, 14, 70])

chg_rows = []
for n in range(5, 101):
    led = HWR[n]['led']; oldcore = HWR[n]['core']
    newcore = next(k for k, v in A.items() if v.get('led') == led)
    chg_rows.append([f'R{n}', led, LED_CN[led], oldcore, BYNET[oldcore]['连接器.脚号'], newcore, BYNET[newcore]['连接器.脚号'],
                     '不变' if oldcore == newcore else '改接', ('P/N 接反已纠正' if n in (49, 50, 51, 52) else '')])
for n in range(101, 141):
    h = HWR[n]
    chg_rows.append([f'R{n}', f"{h['dr1v']} (FPC1.{h['fpc']})", '—', h['core'], BYNET[h['core']]['连接器.脚号'], '—', '—', '删除/按契约重排', 'FPC 整体按 sheet "上行FPC_契约72位" 重画'])
for u, chs in V01_XLT.items():
    for i, (core, led) in enumerate(chs):
        new = next((k for k, v in A.items() if v.get('led') == led or (led.startswith('SYNC') and v.get('led') == 'SYNC1~3')), None)
        act = '删除 (ACK_I 改上拉)' if led.endswith('ACK_I') else ('不变 (转换器改)' if new == core else '改接')
        chg_rows.append([f'{u}.A{i + 1}', led, LED_CN[led], core or '(未接)', BYNET[core]['连接器.脚号'] if core else '', new or '—',
                         BYNET[new]['连接器.脚号'] if new else '', act, ''])
S['V01改线清单'] = dict(header=['位号', '灯板/FPC 侧网名', '灯板连接器脚', 'V01 核心网名', 'V01 核心板脚', '新核心网名', '新核心板脚', '动作', '备注'],
                      rows=chg_rows, widths=[9, 24, 11, 13, 10, 13, 10, 16, 40], chgcol=7)

S['余量与待定'] = dict(header=['项', '内容', '状态'], rows=[], widths=[16, 120, 14])  # 工具结果由 --tool 填

# ---------------------------------------------------------------- 输出
def cst_text():
    out = [f'// GW5A 转 LED 转接板 引脚约束 —— 由 {os.path.basename(__file__)} 生成 ({DATE}); 与 xlsx 同源',
           '// 器件 GW5A-LV25UG324C2/I1 (ACG525-CORE-V2); 工程须 set_option -use_sspi_as_gpio 1 -use_i2c_as_gpio 1 -use_cpu_as_gpio 1 (JTAG/MSPI 不放开)',
           '// 下行 scr_*: TLVDS_OBUF; 上行 ul_*: TLVDS_IBUF 片内 100 欧; 链号 c: scr_clk[c], scr_d[c*3+lane], lane0=B/1=G/2=R; ack_o[n-1] = 灯板 nACK_O', '']
    diffs = OrderedDict()
    for n, v in A.items():
        if 'LVDS' in v['cls'] and v['pn'] == 'P':
            diffs[n] = v
    for n, v in diffs.items():
        sig = v['sig'][:-2]
        port = re.sub(r'^SCR_CLK\[(\d+)\]$', r'scr_clk_p[\1]', sig)
        port = re.sub(r'^SCR_D\[(\d+)\]$', r'scr_d_p[\1]', port)
        port = re.sub(r'^UL_D\[(\d+)\]$', r'ul_d_p[\1]', port)
        port = {'UL_CLK': 'ul_clk_p', 'UL_CHK': 'ul_chk_p'}.get(port, port)
        bp, bn = BYNET[n]['球位'], BYNET[n[:-1] + 'N']['球位']
        io = v['iotype'].replace(' (TLVDS_OBUF)', '').replace(' (TLVDS_IBUF)', '')
        out.append(f'IO_LOC "{port}" {bp},{bn};')
        out.append(f'IO_PORT "{port}" IO_TYPE={io};')
    for n, v in A.items():
        if 'LVDS' in v['cls']:
            continue
        port = {'SB_ALIGNED': 'sb_aligned', 'SB_RSTN': 'sb_rstn', 'SB_UART_B2S': 'sb_uart_b2s', 'SB_UART_S2B': 'sb_uart_s2b',
                'PANEL_RSTN': 'panel_rstn', 'I_SYNC': 'i_sync'}.get(v['sig'])
        if not port:
            port = f"ack_o[{int(v['sig'][5:]) - 1}]"
        io = v['iotype'].replace(' (输入)', '')
        out.append(f'IO_LOC "{port}" {BYNET[n]["球位"]};')
        out.append(f'IO_PORT "{port}" IO_TYPE={io} PULL_MODE=NONE;')
    return '\n'.join(out) + '\n'


def col_letter(i):
    s = ''
    i += 1
    while i:
        i, r = divmod(i - 1, 26)
        s = chr(65 + r) + s
    return s


def esc(s):
    return (str(s).replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;'))


STYLES = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<fonts count="3"><font><sz val="10"/><name val="Microsoft YaHei"/></font><font><b/><sz val="10"/><name val="Microsoft YaHei"/></font><font><b/><sz val="13"/><name val="Microsoft YaHei"/></font></fonts>
<fills count="6"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>
<fill><patternFill patternType="solid"><fgColor rgb="FFD9E1F2"/></patternFill></fill>
<fill><patternFill patternType="solid"><fgColor rgb="FFE2EFDA"/></patternFill></fill>
<fill><patternFill patternType="solid"><fgColor rgb="FFFFF2CC"/></patternFill></fill>
<fill><patternFill patternType="solid"><fgColor rgb="FFFCE4D6"/></patternFill></fill></fills>
<borders count="2"><border/><border><left style="thin"><color rgb="FFBFBFBF"/></left><right style="thin"><color rgb="FFBFBFBF"/></right><top style="thin"><color rgb="FFBFBFBF"/></top><bottom style="thin"><color rgb="FFBFBFBF"/></bottom></border></borders>
<cellStyleXfs count="1"><xf/></cellStyleXfs>
<cellXfs count="7">
<xf fontId="0" fillId="0" borderId="0"/>
<xf fontId="1" fillId="2" borderId="1" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment wrapText="1" vertical="center"/></xf>
<xf fontId="0" fillId="0" borderId="1" applyBorder="1" applyAlignment="1"><alignment wrapText="1" vertical="top"/></xf>
<xf fontId="0" fillId="3" borderId="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment wrapText="1" vertical="top"/></xf>
<xf fontId="0" fillId="4" borderId="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment wrapText="1" vertical="top"/></xf>
<xf fontId="0" fillId="5" borderId="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment wrapText="1" vertical="top"/></xf>
<xf fontId="2" fillId="0" borderId="0" applyFont="1"/>
</cellXfs></styleSheet>'''


def chg_style(v):
    v = str(v)
    if v.startswith('不变'):
        return 3
    if v.startswith('删除'):
        return 5
    return 4


def sheet_xml(sh):
    rows = []
    hdr = sh['header']
    allrows = ([hdr] if hdr else []) + sh['rows']
    for ri, row in enumerate(allrows):
        cells = []
        for ci, val in enumerate(row):
            ref = f'{col_letter(ci)}{ri + 1}'
            if hdr and ri == 0:
                st = 1
            elif not hdr:
                st = 6 if ri == 0 else (1 if (ci == 0 and row[1] == '' and row[0]) else 2)
            else:
                st = chg_style(row[sh['chgcol']]) if sh.get('chgcol') is not None else 2
            if isinstance(val, int):
                cells.append(f'<c r="{ref}" s="{st}"><v>{val}</v></c>')
            else:
                cells.append(f'<c r="{ref}" s="{st}" t="inlineStr"><is><t xml:space="preserve">{esc(val)}</t></is></c>')
        rows.append(f'<row r="{ri + 1}">{"".join(cells)}</row>')
    cols = ''.join(f'<col min="{i + 1}" max="{i + 1}" width="{w}" customWidth="1"/>' for i, w in enumerate(sh['widths']))
    pane = '<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>' if hdr else ''
    af = f'<autoFilter ref="A1:{col_letter(len(hdr) - 1)}{len(allrows)}"/>' if hdr and sh['rows'] else ''
    return ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            f'{pane}<cols>{cols}</cols><sheetData>{"".join(rows)}</sheetData>{af}</worksheet>')


def write_xlsx(path, sheets):
    names = list(sheets)
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
                   '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>'
                   '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
                   '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
                   + ''.join(f'<Override PartName="/xl/worksheets/sheet{i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' for i in range(len(names)))
                   + '</Types>')
        z.writestr('_rels/.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                   '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>')
        z.writestr('xl/workbook.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>'
                   + ''.join(f'<sheet name="{esc(n)}" sheetId="{i + 1}" r:id="rId{i + 1}"/>' for i, n in enumerate(names)) + '</sheets>'
                   + '<definedNames>' + ''.join(f'<definedName name="_xlnm._FilterDatabase" localSheetId="{i}" hidden="1">\'{esc(n)}\'!$A$1:${col_letter(len(sheets[n]["header"]) - 1)}${len(sheets[n]["rows"]) + 1}</definedName>'
                                                for i, n in enumerate(names) if sheets[n]['header'] and sheets[n]['rows']) + '</definedNames></workbook>')
        z.writestr('xl/_rels/workbook.xml.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                   + ''.join(f'<Relationship Id="rId{i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet{i + 1}.xml"/>' for i in range(len(names)))
                   + f'<Relationship Id="rId{len(names) + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>')
        z.writestr('xl/styles.xml', STYLES)
        for i, n in enumerate(names):
            z.writestr(f'xl/worksheets/sheet{i + 1}.xml', sheet_xml(sheets[n]))


def main():
    outdir = sys.argv[1]
    tool = json.load(open(os.path.join(outdir, 'tool_result.json'), encoding='utf-8')) if os.path.exists(os.path.join(outdir, 'tool_result.json')) else None
    S['余量与待定']['rows'] = pending_rows(tool)
    open(os.path.join(outdir, 'gw5a_led_adapter.cst'), 'w', encoding='utf-8').write(cst_text())
    write_xlsx(os.path.join(outdir, XLSX_NAME), S)
    json.dump(dict(sheets={k: dict(header=v['header'], rows=v['rows']) for k, v in S.items()},
                   counts=dict(Counter(v['cls'] for v in A.values())), chg=dict(CHG)),
              open(os.path.join(outdir, 'pinplan.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
    # 回读自检
    back = read_xlsx(os.path.join(outdir, XLSX_NAME))
    for n, sh in S.items():
        exp = ([sh['header']] if sh['header'] else []) + sh['rows']
        got = back[n]
        assert len(got) == len(exp), (n, len(got), len(exp))
        for e, g in zip(exp, got):
            assert [str(x) for x in e] == (g + [''] * (len(e) - len(g)))[:len(e)], (n, e, g)
    print('OK', dict(Counter(v['cls'] for v in A.values())), dict(CHG), 'sheets', {n: len(s['rows']) for n, s in S.items()})


def pending_rows(tool):
    rows = []
    if tool:
        for t in tool:
            rows.append(['Gowin 布局布线', t['text'], t['status']])
    else:
        rows.append(['Gowin 布局布线', '未跑', '待定'])
    rows += [
        ['余量', '154/154 IO 全用; 差分対 68/69 (剩 1 対 B3_B71 按 v3 拆作边带)', '已定 (知情)'],
        ['D11 bank2/6 速率', '下行 21 対在 bank2 (Right) / bank6 (Left), 332 Mbps 未验证; 首板先测 (可用 gw5a_loop 同类环回)', '待定'],
        ['ACK_I 浮空/上拉', '12 颗不级联时 ACK_I 不接、ACK_O 各自引出能否回包 —— 手册推导成立, 待集创北方 FAE 确认', '待定'],
        ['ACK 编号 ↔ 链号', '灯板 nACK_O 的 n 与 CLKI/CLKOk 组号的对应要灯板确认 (固件 u_ack 按链号读)', '待定'],
        ['VDDD', '转换器 VCCB 与 ACK_I 上拉电压 = 灯板 VDDD (V01 用 3V8, 早先建议 2.8V), 以灯板为准', '待定'],
        ['T1 型号', '要求两侧 1.5V ~ VDDD 都在范围内 (LVC8T245 下限 1.65V 不行); LXC8T245 类, 下单前核手册电压范围与脚位', '待定'],
        ['T1 VCCA 来源', '取核心板 VCCIO01 (P1.9/10) 作参考电源, 电流 <1 mA; 不接受则转接板加 1.5V LDO', '建议'],
        ['配置复用脚', 'B3_B65_N (DOUT)、B5_B8 (SSPI SO 等)、B5_B12 (RDWR_B/SSPI_WPN) 作 GPIO, 上行对里另有 6 対 (v3 已列) —— 综合时放开 Dual-Purpose', '建议'],
        ['核心板 flash', 'V2 插上前 flash 必须擦除或烧与本表一致的安全镜像 (v3 D28 同理, 否则出厂/自测镜像会对驱)', '待定'],
        ['mux 退路', 'ACK_O 改 2×8:1 mux (ACK_D×2 + ACK_S×3) 可空出 7 脚; 与现有 RTL ack_d/ack_s 端口一致', '备选'],
    ]
    return rows


if __name__ == '__main__':
    main()
