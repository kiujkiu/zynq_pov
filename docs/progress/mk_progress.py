# -*- coding: utf-8 -*-
"""显性目的进度看板 (OKR) → 显性目的进度_<日期>.xlsx + .html + .pdf

数据全在同目录的 CSV (UTF-8 带 BOM, Excel 可直接打开):
  goals.csv        O: 显性目的
  krs.csv          KR: 可量化指标与 V0/V1/V2 目标 (人工状态列可覆盖自动判定)
  metrics.csv      每次实测值 (来源必填)
  deliverables.csv 交付计划与完成
  mta.csv          里程碑趋势 (每次评审追加一组行)
  daily_log.csv    每日进展流水 (日期/类型/编号/内容/来源, 人工追加)
  daily_rates.csv  每日三个达成率 (脚本每次生成时写入/更新当天一行)

用法:  cmd.exe /c "python mk_progress.py [--date 2026-10-13] [--no-pdf]"   (Windows Python 带 openpyxl)
      或 WSL 里 python3 mk_progress.py —— 没有 openpyxl 时自动转交 cmd.exe 里的 Windows Python。
PDF 用 Windows Edge 无头模式打印 HTML (--print-to-pdf)。
"""
import argparse
import csv
import datetime as dt
import html
import math
import os
import shutil
import subprocess
import sys
from collections import OrderedDict, defaultdict

try:
    from openpyxl import Workbook
except ImportError:  # WSL 没装 openpyxl: 交给 Windows Python
    if os.name != 'nt' and shutil.which('cmd.exe'):
        here = os.path.dirname(os.path.abspath(__file__))
        win = subprocess.check_output(['wslpath', '-w', here], text=True).strip()
        args = ' '.join(sys.argv[1:])
        sys.exit(subprocess.call(['cmd.exe', '/c', f'cd /d {win} && python mk_progress.py {args}'], cwd=here))
    raise
from openpyxl.chart import LineChart, Reference, ScatterChart, Series
from openpyxl.chart.axis import ChartLines
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = '微软雅黑'
EDGE = (r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe' if os.name == 'nt'
        else '/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe')

# 状态 → (emoji, 填充色, 说明)
ST = {
    'ok':   ('✅', 'C6EFCE', '达成当前期目标'),
    'doing': ('🔄', 'FFEB9C', '进行中 / 未达标'),
    'idle': ('⏸', 'D9D9D9', '无数据 / 未开始'),
    'bad':  ('❌', 'FFC7CE', '退步 / 阻塞'),
}
EMOJI2ST = {v[0]: k for k, v in ST.items()}
REAL_PREFIX = ('V0', 'V1', 'V2', '历史')   # 其余 (仿真/台架) 画成另一条线
STAGE_KEY = 'V0'                           # 当前期


# ---------------------------------------------------------------- 读数据
def read_csv(name):
    with open(os.path.join(HERE, name), encoding='utf-8-sig', newline='') as f:
        return [{k.strip(): (v or '').strip() for k, v in r.items()} for r in csv.DictReader(f)]


def pdate(s):
    return dt.date.fromisoformat(s) if s else None


def num(s):
    if s in ('', None):
        return None
    return float(s)


def is_real(stage):
    return stage.startswith(REAL_PREFIX)


def load():
    goals = read_csv('goals.csv')
    krs = read_csv('krs.csv')
    mets = read_csv('metrics.csv')
    dels = read_csv('deliverables.csv')
    mta = read_csv('mta.csv')
    kr_ids = {k['kr_id'] for k in krs}
    for i, m in enumerate(mets):
        if not m['来源']:
            sys.exit(f'metrics.csv 第 {i + 2} 行没有来源')
        if m['kr_id'] not in kr_ids:
            sys.exit(f'metrics.csv 第 {i + 2} 行 kr_id {m["kr_id"]} 不在 krs.csv')
        m['_d'] = pdate(m['日期'])
        m['_v'] = num(m['实测值'])
        m['_i'] = i
    for d in dels:
        d['_p'] = pdate(d['计划日期'])
        d['_f'] = pdate(d['完成日期'])
    for r in mta:
        r['_r'] = pdate(r['评审日期'])
        r['_e'] = pdate(r['预计完成日期'])
    return goals, krs, mets, dels, mta


def fmt(v):
    if v is None:
        return ''
    return f'{v:g}' if abs(v) < 1e6 else f'{v:.0f}'


def better(kr, a, b):
    """a 是否不差于 b"""
    return a >= b if kr['方向'] == '越大越好' else a <= b


def kr_status(kr, ms):
    """返回 (状态键, 最新实测行, 最新任意行)"""
    if kr.get('人工状态'):
        s = EMOJI2ST.get(kr['人工状态'], kr['人工状态'])
    else:
        s = None
    real = [m for m in ms if is_real(m['硬件/阶段'])]
    last_real = real[-1] if real else None
    last_any = ms[-1] if ms else None
    if s:
        return s, last_real, last_any
    tgt = num(kr[f'{STAGE_KEY} 目标']) or num(kr['V1 目标'])
    if not last_real:
        return 'idle', None, last_any
    if tgt is None:
        return 'doing', last_real, last_any
    return ('ok' if better(kr, last_real['_v'], tgt) else 'doing'), last_real, last_any


def v2_progress(kr, show):
    """最新值相对 V2 (终极) 目标的达成度 0..1"""
    t = num(kr['V2 目标'])
    if show is None or t is None:
        return None
    v = show['_v']
    if kr['方向'] == '越大越好':
        return min(v / t, 1.0) if t else 1.0
    return 1.0 if v <= t else (t / v if v else 0.0)


def per_date_last(rows):
    """同一天多条只取最后一条 (以表中顺序为准)"""
    od = OrderedDict()
    for m in sorted(rows, key=lambda r: (r['_d'], r['_i'])):
        od[m['_d']] = m['_v']
    return od


# ---------------------------------------------------------------- Excel 样式
def F(bold=False, size=10, color='000000'):
    return Font(name=FONT, bold=bold, size=size, color=color)


THIN = Side(style='thin', color='BFBFBF')
BORDER = Border(left=THIN, right=THIN, top=THIN, bottom=THIN)
HEAD_FILL = PatternFill('solid', fgColor='1F4E78')
WRAP = Alignment(wrap_text=True, vertical='top')
CENTER = Alignment(horizontal='center', vertical='center', wrap_text=True)


def header(ws, row, cols, widths=None):
    for j, c in enumerate(cols, 1):
        cell = ws.cell(row=row, column=j, value=c)
        cell.font = F(True, 10, 'FFFFFF')
        cell.fill = HEAD_FILL
        cell.alignment = CENTER
        cell.border = BORDER
    if widths:
        for j, w in enumerate(widths, 1):
            ws.column_dimensions[get_column_letter(j)].width = w


def put(ws, row, col, val, fill=None, bold=False, align=WRAP, numfmt=None):
    c = ws.cell(row=row, column=col, value=val)
    c.font = F(bold)
    c.alignment = align
    c.border = BORDER
    if fill:
        c.fill = PatternFill('solid', fgColor=fill)
    if numfmt:
        c.number_format = numfmt
    return c


def style_chart(ch, title, ytitle, w=17, h=7.5):
    ch.title = title
    ch.y_axis.title = ytitle
    ch.width, ch.height = w, h
    ch.legend.position = 'b'
    ch.display_blanks = 'span'
    ch.x_axis.delete = False
    ch.y_axis.delete = False
    ch.y_axis.majorGridlines = ChartLines()


SERIES_STYLE = {
    '实测': ('2E75B6', 'solid', 'circle'),
    '仿真/台架': ('ED7D31', 'solid', 'triangle'),
    'V0 目标': ('70AD47', 'dash', None),
    'V1 目标': ('7030A0', 'dash', None),
    'V2 目标': ('C00000', 'dash', None),
}


def style_series(s, color, dash, marker):
    s.graphicalProperties.line.solidFill = color
    s.graphicalProperties.line.width = 22000
    s.graphicalProperties.line.dashStyle = dash
    s.smooth = False
    if marker:
        s.marker.symbol = marker
        s.marker.size = 7
        s.marker.graphicalProperties.solidFill = color
        s.marker.graphicalProperties.line.solidFill = color
    else:
        s.marker.symbol = 'none'


# ---------------------------------------------------------------- 各页
def sheet_status(wb, goals, krs, by_kr, today):
    ws = wb.active
    ws.title = '现状'
    ws['A1'] = f'POV3D 显性目的进度看板 — {today}  (当前期 {STAGE_KEY}；状态按「最新硬件实测 vs 当前期目标」自动判定，krs.csv 人工状态列可覆盖)'
    ws['A1'].font = F(True, 13)
    ws.merge_cells('A1:Q1')
    cols = ['目的', '显性目的', '实现途径', '目的状态', 'KR', '指标', '单位', '方向',
            '最新实测', '实测日期', '阶段', 'V0 目标', 'V1 目标', 'V2 目标', 'KR 状态', '最新来源', '距 V2 达成']
    header(ws, 3, cols, [5, 22, 10, 12, 7, 26, 9, 9, 10, 11, 14, 8, 8, 8, 8, 40, 10])
    r = 4
    order = ['bad', 'doing', 'idle', 'ok']
    for g in goals:
        gk = [k for k in krs if k['goal_id'] == g['id']]
        sts = [kr_status(k, by_kr[k['kr_id']]) for k in gk]
        gs = min((s[0] for s in sts), key=order.index) if sts else 'idle'
        r0 = r
        for k, (s, lr, la) in zip(gk, sts):
            put(ws, r, 5, k['kr_id'])
            put(ws, r, 6, k['指标名'])
            put(ws, r, 7, k['单位'])
            put(ws, r, 8, k['方向'])
            show = lr or la
            put(ws, r, 9, show['_v'] if show else None, align=CENTER)
            put(ws, r, 10, show['_d'] if show else None, align=CENTER, numfmt='yyyy-mm-dd')
            put(ws, r, 11, show['硬件/阶段'] if show else '')
            for j, key in enumerate(['V0 目标', 'V1 目标', 'V2 目标']):
                put(ws, r, 12 + j, num(k[key]), align=CENTER)
            put(ws, r, 15, ST[s][0], fill=ST[s][1], align=CENTER)
            put(ws, r, 16, show['来源'] if show else '')
            pg = v2_progress(k, show)
            put(ws, r, 17, pg, align=CENTER, numfmt='0%')
            r += 1
        r1 = max(r - 1, r0)
        for col, val in [(1, int(g['id'])), (2, g['显性目的']), (3, g['实现途径'])]:
            put(ws, r0, col, val, bold=(col == 2))
        put(ws, r0, 4, ST[gs][0] + ' ' + ST[gs][2], fill=ST[gs][1], align=CENTER)
        for col in (1, 2, 3, 4):
            if r1 > r0:
                ws.merge_cells(start_row=r0, start_column=col, end_row=r1, end_column=col)
            ws.cell(row=r0, column=col).alignment = CENTER if col != 2 else WRAP
    r += 1
    ws.cell(row=r, column=1, value='图例').font = F(True)
    for i, (k, (e, c, t)) in enumerate(ST.items()):
        put(ws, r + 1 + i, 1, e, fill=c, align=CENTER)
        ws.cell(row=r + 1 + i, column=2, value=t).font = F()
    ws.freeze_panes = 'E4'
    return ws


def sheet_trends(wb, krs, by_kr):
    ws = wb.create_sheet('指标趋势')
    ws['A1'] = '每个 KR 一张趋势图 (横轴日期；同一天多次实测取最后一条；虚线 = V0/V1/V2 目标；橙线 = 仿真/台架)'
    ws['A1'].font = F(True, 12)
    for j, w in enumerate([12, 10, 10, 10, 10, 10, 10], 1):
        ws.column_dimensions[get_column_letter(j)].width = w
    r = 3
    for k in krs:
        ms = by_kr[k['kr_id']]
        if not ms:
            continue
        real = per_date_last([m for m in ms if is_real(m['硬件/阶段'])])
        sim = per_date_last([m for m in ms if not is_real(m['硬件/阶段'])])
        dates = sorted(set(real) | set(sim))
        tg = [(n, num(k[n])) for n in ('V0 目标', 'V1 目标', 'V2 目标') if num(k[n]) is not None]
        d0, d1 = dates[0], dates[-1]
        if d0 == d1:
            d0, d1 = d0 - dt.timedelta(days=1), d1 + dt.timedelta(days=1)
        ws.cell(row=r, column=1, value=f'{k["kr_id"]} {k["指标名"]} ({k["单位"]}, {k["方向"]})').font = F(True, 11)
        hdr = ['日期', '实测', '仿真/台架']
        header_row = r + 1
        for j, h in enumerate(hdr, 1):
            c = ws.cell(row=header_row, column=j, value=h)
            c.font = F(True, 9, 'FFFFFF'); c.fill = HEAD_FILL; c.border = BORDER
        # 目标线: 单独两行 (起止日期)
        for j, (n, _) in enumerate(tg):
            for jj, h in enumerate((n + ' 日期', n)):
                c = ws.cell(row=header_row, column=4 + 2 * j + jj, value=h)
                c.font = F(True, 9, 'FFFFFF'); c.fill = HEAD_FILL; c.border = BORDER
        for i, d in enumerate(dates):
            rr = header_row + 1 + i
            put(ws, rr, 1, d, numfmt='mm-dd', align=CENTER)
            put(ws, rr, 2, real.get(d), align=CENTER)
            put(ws, rr, 3, sim.get(d), align=CENTER)
        for j, (n, v) in enumerate(tg):
            for i, d in enumerate((d0, d1)):
                put(ws, header_row + 1 + i, 4 + 2 * j, d, numfmt='mm-dd', align=CENTER)
                put(ws, header_row + 1 + i, 5 + 2 * j, v, align=CENTER)
        n = len(dates)
        ch = ScatterChart()
        style_chart(ch, f'{k["kr_id"]} {k["指标名"]}', k['单位'])
        ch.scatterStyle = 'lineMarker'
        ch.x_axis.number_format = 'mm-dd'
        ch.x_axis.title = '日期'
        xref = Reference(ws, min_col=1, min_row=header_row + 1, max_row=header_row + n)
        for col, name in ((2, '实测'), (3, '仿真/台架')):
            src = real if col == 2 else sim
            if not src:
                continue
            s = Series(Reference(ws, min_col=col, min_row=header_row, max_row=header_row + n), xref, title_from_data=True)
            style_series(s, *SERIES_STYLE[name])
            ch.series.append(s)
        for j, (nm, v) in enumerate(tg):
            xr = Reference(ws, min_col=4 + 2 * j, min_row=header_row + 1, max_row=header_row + 2)
            s = Series(Reference(ws, min_col=5 + 2 * j, min_row=header_row, max_row=header_row + 2), xr, title_from_data=True)
            style_series(s, *SERIES_STYLE[nm])
            ch.series.append(s)
        ch.x_axis.scaling.min = d0.toordinal() - dt.date(1899, 12, 30).toordinal()
        ch.x_axis.scaling.max = d1.toordinal() - dt.date(1899, 12, 30).toordinal()
        ws.add_chart(ch, f'K{r}')
        r += max(17, n + 4)
    return ws


def burnup_table(dels, today):
    ds = [d['_p'] for d in dels if d['_p']] + [d['_f'] for d in dels if d['_f']]
    start, end = min(ds), max(max(ds), today)
    rows = []
    d = start
    while d <= end:
        total = len(dels)
        plan = sum(1 for x in dels if x['_p'] and x['_p'] <= d)
        done = sum(1 for x in dels if x['_f'] and x['_f'] <= d) if d <= today else None
        rows.append((d, total, plan, done))
        d += dt.timedelta(days=1)
    return rows


def sheet_burnup(wb, dels, today):
    ws = wb.create_sheet('燃起图')
    ws['A1'] = '燃起图：总范围 / 按计划日期累计 / 实际完成累计 (今天之后不画完成线)'
    ws['A1'].font = F(True, 12)
    header(ws, 3, ['日期', '总范围', '计划累计', '完成累计'], [11, 9, 9, 9])
    rows = burnup_table(dels, today)
    for i, (d, t, p, f) in enumerate(rows):
        put(ws, 4 + i, 1, d, numfmt='mm-dd', align=CENTER)
        put(ws, 4 + i, 2, t, align=CENTER)
        put(ws, 4 + i, 3, p, align=CENTER)
        put(ws, 4 + i, 4, f, align=CENTER)
    n = len(rows)
    ch = LineChart()
    style_chart(ch, '交付燃起图', '交付项数', 20, 9)
    ch.add_data(Reference(ws, min_col=2, max_col=4, min_row=3, max_row=3 + n), titles_from_data=True)
    ch.set_categories(Reference(ws, min_col=1, min_row=4, max_row=3 + n))
    ch.x_axis.number_format = 'mm-dd'
    for s, (c, dsh, mk) in zip(ch.series, [('A5A5A5', 'dash', None), ('70AD47', 'solid', None), ('2E75B6', 'solid', 'circle')]):
        style_series(s, c, dsh, mk)
    ws.add_chart(ch, 'F3')
    # 交付清单
    r0 = max(4 + n + 2, 24)
    ws.cell(row=r0 - 1, column=1, value='交付清单').font = F(True, 12)
    cols = ['id', '名称', '服务的 goal_id', '期', '计划日期', '完成日期', '状态', '分支/提交']
    for j, c in enumerate(cols, 1):
        cell = ws.cell(row=r0, column=j, value=c)
        cell.font = F(True, 10, 'FFFFFF'); cell.fill = HEAD_FILL; cell.border = BORDER; cell.alignment = CENTER
    for j, w in enumerate([11, 9, 9, 9, 11, 11, 7, 46], 1):
        pass
    ws.column_dimensions['B'].width = 9
    for i, d in enumerate(dels):
        rr = r0 + 1 + i
        st = EMOJI2ST.get(d['状态'], 'idle')
        vals = [d['id'], d['名称'], d['服务的 goal_id'], d['期'], d['_p'], d['_f'], d['状态'], d['分支/提交']]
        for j, v in enumerate(vals, 1):
            put(ws, rr, j, v, fill=ST[st][1] if j == 7 else None,
                numfmt='yyyy-mm-dd' if j in (5, 6) else None, align=CENTER if j in (1, 3, 4, 5, 6, 7) else WRAP)
    ws.column_dimensions['B'].width = 30
    ws.column_dimensions['H'].width = 46
    return ws


def sheet_mta(wb, mta):
    ws = wb.create_sheet('里程碑趋势')
    ws['A1'] = '里程碑趋势图 MTA：横轴评审日期，纵轴预计完成日期；线往上翘 = 延期，水平 = 按期；灰色对角线 = 评审日期本身 (碰到即完成)'
    ws['A1'].font = F(True, 12)
    reviews = sorted({r['_r'] for r in mta})
    stones = list(OrderedDict.fromkeys(r['里程碑'] for r in mta))
    tab = {(r['_r'], r['里程碑']): r['_e'] for r in mta}
    header(ws, 3, ['评审日期'] + stones + ['对角线'], [11] + [14] * len(stones) + [11])
    # 至少两行, 只有一次评审时补一行"下次评审"空行以画对角线
    allr = list(reviews)
    last_e = max(r['_e'] for r in mta)
    for i, rv in enumerate(allr):
        put(ws, 4 + i, 1, rv, numfmt='yyyy-mm-dd', align=CENTER)
        for j, s in enumerate(stones):
            put(ws, 4 + i, 2 + j, tab.get((rv, s)), numfmt='yyyy-mm-dd', align=CENTER)
    nrv = len(allr)
    # 对角线两点放到下方单独区域
    dr = 4 + nrv + 2
    ws.cell(row=dr - 1, column=1, value='对角线 (y = x)').font = F(True)
    put(ws, dr, 1, allr[0], numfmt='yyyy-mm-dd'); put(ws, dr, 2, allr[0], numfmt='yyyy-mm-dd')
    put(ws, dr + 1, 1, last_e, numfmt='yyyy-mm-dd'); put(ws, dr + 1, 2, last_e, numfmt='yyyy-mm-dd')
    ch = ScatterChart()
    style_chart(ch, '里程碑趋势 (MTA)', '预计完成日期', 20, 11)
    ch.scatterStyle = 'lineMarker'
    ch.x_axis.title = '评审日期'
    ch.x_axis.number_format = 'mm-dd'
    ch.y_axis.number_format = 'mm-dd'
    palette = ['2E75B6', 'ED7D31', '70AD47', '7030A0', 'C00000', 'BF8F00', '00B0F0', '595959']
    xref = Reference(ws, min_col=1, min_row=4, max_row=3 + nrv)
    for j, s in enumerate(stones):
        se = Series(Reference(ws, min_col=2 + j, min_row=3, max_row=3 + nrv), xref, title_from_data=True)
        style_series(se, palette[j % len(palette)], 'solid', 'circle')
        ch.series.append(se)
    se = Series(Reference(ws, min_col=2, min_row=dr, max_row=dr + 1), Reference(ws, min_col=1, min_row=dr, max_row=dr + 1), title='对角线')
    style_series(se, 'A5A5A5', 'dash', None)
    ch.series.append(se)
    base = dt.date(1899, 12, 30).toordinal()
    ch.x_axis.scaling.min = allr[0].toordinal() - base - 1
    ch.x_axis.scaling.max = last_e.toordinal() - base
    ch.y_axis.scaling.min = allr[0].toordinal() - base - 1
    ch.y_axis.scaling.max = last_e.toordinal() - base + 3
    ws.add_chart(ch, f'B{dr + 3}')
    return ws


def sheet_history(wb, krs, mets):
    ws = wb.create_sheet('历史记录')
    krmap = {k['kr_id']: k for k in krs}
    cols = ['日期', 'goal_id', 'kr_id', '指标', '单位', '实测值', '硬件/阶段', '来源', '备注']
    header(ws, 1, cols, [11, 7, 8, 26, 9, 9, 14, 48, 56])
    for i, m in enumerate(sorted(mets, key=lambda m: (m['_d'], m['kr_id'], m['_i']))):
        k = krmap[m['kr_id']]
        vals = [m['_d'], int(k['goal_id']), m['kr_id'], k['指标名'], k['单位'], m['_v'], m['硬件/阶段'], m['来源'], m.get('备注', '')]
        for j, v in enumerate(vals, 1):
            put(ws, 2 + i, j, v, numfmt='yyyy-mm-dd' if j == 1 else None)
    ws.auto_filter.ref = f'A1:{get_column_letter(len(cols))}{1 + len(mets)}'
    ws.freeze_panes = 'A2'
    return ws



# ---------------------------------------------------------------- 阶段达成率 / 每日进展
STAGES = ['V0', 'V1', 'V2']
NEEDS = {'V0': ('V0',), 'V1': ('V0', 'V1准备'), 'V2': ('V0', 'V1准备', 'V2')}   # 交付"需要"是嵌套的
RATE_FIELDS = ['日期', 'V0 达成率', 'V1 达成率', 'V2 达成率']
ALGO = [
    '统一口径：达成率_P = (P 目标已达标的 KR 数 + P 需要的交付里已完成数) ÷ (有 P 目标的 KR 数 + P 需要的交付总数)，P = V0 / V1 / V2。',
    '只按「必须」项计：KR 全算必须；交付看 deliverables.csv 的「级别」列 (必须/加分)，加分项不进分子分母。',
    '交付的"需要"是嵌套的：V0 需要 = 阶段 V0；V1 需要 = V0 + V1准备；V2 需要 = V1 需要 + V2 (阶段列见 deliverables.csv，没填阶段的交付不计)。',
    'KR 是否达到 P 目标 = 截至该日的最新硬件实测值 vs P 目标 (仿真/台架点不算达标)。',
]


def kr_meets(kr, ms, stage, asof):
    """截至 asof 的最新硬件实测是否达到 stage 目标: 'ok' / 'sim' (仅仿真/台架达到) / 'no' / None (无该期目标)"""
    t = num(kr[f'{stage} 目标'])
    if t is None:
        return None
    ms = [m for m in ms if m['_d'] <= asof]
    real = [m for m in ms if is_real(m['硬件/阶段'])]
    if real and better(kr, real[-1]['_v'], t):
        return 'ok'
    sim = [m for m in ms if not is_real(m['硬件/阶段'])]
    if sim and better(kr, sim[-1]['_v'], t):
        return 'sim'
    return 'no'


def compute_rates(krs, mets, dels, asof):
    """按 asof (含) 之前的数据算 V0/V1/V2 三期达成率, 返回 {期: dict(rate, n, m, kr=(a,b), dl=(c,d))}"""
    by = defaultdict(list)
    for m in sorted(mets, key=lambda m: (m['_d'], m['_i'])):
        by[m['kr_id']].append(m)
    out = {}
    for P in STAGES:
        sts = [kr_meets(k, by[k['kr_id']], P, asof) for k in krs]
        kk = [s for s in sts if s is not None]
        a = sum(1 for s in kk if s == 'ok')
        need = [d for d in dels if d.get('阶段') in NEEDS[P] and d.get('级别', '必须') != '加分']
        c = sum(1 for d in need if d['状态'] == '✅' and d['_f'] and d['_f'] <= asof)
        m_ = len(kk) + len(need)
        out[P] = {'rate': (a + c) / m_ if m_ else None, 'n': a + c, 'm': m_, 'kr': (a, len(kk)), 'dl': (c, len(need))}
    return out


def update_daily_rates(krs, mets, dels, today):
    """写/更新 daily_rates.csv 当天一行 (10-12 缺则按当时数据补一行), 返回全部行"""
    path = os.path.join(HERE, 'daily_rates.csv')
    rows = OrderedDict()
    if os.path.exists(path):
        for r in read_csv('daily_rates.csv'):
            if 'V1 达成率' in r:      # 旧版列 (V1 准备度/V2 距离) 口径不同, 丢弃
                rows[r['日期']] = r
    for d in (dt.date(2026, 10, 12), today):
        if d > today or (d != today and d.isoformat() in rows):
            continue
        c = compute_rates(krs, mets, dels, d)
        rows[d.isoformat()] = {'日期': d.isoformat(), **{f'{P} 达成率': ('' if c[P]['rate'] is None else f'{c[P]["rate"]:.4f}') for P in STAGES}}
    out = sorted(rows.values(), key=lambda r: r['日期'])
    with open(path, 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=RATE_FIELDS, lineterminator='\n')
        w.writeheader()
        w.writerows(out)
    return [{'d': pdate(r['日期']), 'v0': num(r['V0 达成率']), 'v1': num(r['V1 达成率']), 'v2': num(r['V2 达成率'])} for r in out]


def kr_changes(krs, by_kr, today):
    """每个 KR 取每天最后一个硬件实测值: 今天 vs 今天之前最近一天。返回 [(kr, 前(日期,值)|None, 今值, 判定)]"""
    out = []
    for k in krs:
        real = per_date_last([m for m in by_kr[k['kr_id']] if is_real(m['硬件/阶段']) and m['_d'] <= today])
        if today not in real:
            continue
        prev = [(d, v) for d, v in real.items() if d < today]
        cur = real[today]
        if not prev:
            out.append((k, None, cur, 'new'))
            continue
        pd_, pv = prev[-1]
        if cur == pv:
            v = 'same'
        else:
            v = 'up' if better(k, cur, pv) else 'down'
        out.append((k, (pd_, pv), cur, v))
    return out



def gate_states(gates, krs, by_kr, dels, asof):
    """出口清单每条在 asof 的状态: 关联项全完成/达标 ✅, 部分 🔄, 都没有 ⬜; 无关联用 gates.csv 人工状态。返回 [(行, 状态, 已完成数, 关联数)]"""
    krm = {k['kr_id']: k for k in krs}
    dm = {d['id']: d for d in dels}
    out = []
    for g in gates:
        links = [x.strip() for x in g['关联(交付/KR 编号)'].split(';') if x.strip()]
        stage = 'V0' if g['清单'].startswith('V0') else 'V1'
        if not links:
            out.append((g, g['状态'] or '⬜', 0, 0))
            continue
        n = 0
        for x in links:
            if x in krm:
                n += kr_meets(krm[x], by_kr[x], stage, asof) == 'ok'
            elif x in dm:
                d = dm[x]
                n += bool(d['状态'] == '✅' and d['_f'] and d['_f'] <= asof)
        out.append((g, '✅' if n == len(links) else ('🔄' if n else '⬜'), n, len(links)))
    return out


RISK_FILL = {'开': 'FFC7CE', '监控': 'FFEB9C', '关': 'C6EFCE'}
GATE_FILL = {'✅': 'C6EFCE', '🔄': 'FFEB9C', '⬜': 'F2F2F2'}


def read_opt(name):
    return read_csv(name) if os.path.exists(os.path.join(HERE, name)) else []


def read_log(today):
    if not os.path.exists(os.path.join(HERE, 'daily_log.csv')):
        return []
    rows = [r for r in read_csv('daily_log.csv') if r['日期'] and pdate(r['日期']) <= today]
    for i, r in enumerate(rows):
        r['_d'] = pdate(r['日期'])
        r['_i'] = i
    return sorted(rows, key=lambda r: (-r['_d'].toordinal(), r['_i']))


CH_FILL = {'up': 'C6EFCE', 'down': 'FFC7CE', 'new': 'BDD7EE', 'same': 'F2F2F2'}
CH_TXT = {'up': '变好', 'down': '变差', 'new': '新出现', 'same': '持平'}
LOG_FILL = {'复验退回': 'FFC7CE', '问题': 'FFEB9C', '交付完成': 'C6EFCE', '复验通过': 'C6EFCE', '里程碑': 'BDD7EE', '决定': 'E4DFEC'}


def pct(x):
    return '—' if x is None else f'{x:.1%}'


def sheet_daily(wb, ctx, today):
    ws = wb.create_sheet('每日进展', 0)
    cur = ctx['cur']
    ws['A1'] = f'POV3D 每日进展 — {today}'
    ws['A1'].font = F(True, 14)
    for j, w in enumerate([11, 12, 30, 70, 44, 3, 11, 11, 11, 11], 1):
        ws.column_dimensions[get_column_letter(j)].width = w
    header(ws, 3, ['阶段达成率', '数值', '分子/分母', '算法'])
    items = []
    for i, P in enumerate(STAGES):
        c = cur[P]
        items.append((f'{P} 达成率', c['rate'], f'{c["n"]}/{c["m"]}',
                      f'KR {c["kr"][0]}/{c["kr"][1]} + 交付 {c["dl"][0]}/{c["dl"][1]}' + (' — ' + ALGO[0] if i == 0 else (' — ' + ALGO[1] if i == 1 else ' — ' + ALGO[2]))))
    for i, (n, v, fr, al) in enumerate(items):
        r = 4 + i
        put(ws, r, 1, n, bold=True)
        put(ws, r, 2, v, bold=True, align=CENTER, numfmt='0.0%')
        ws.cell(row=r, column=2).font = F(True, 14)
        put(ws, r, 3, fr, align=CENTER)
        put(ws, r, 4, al)
        ws.row_dimensions[r].height = 48
    # 趋势数据 (G..J) + 两条趋势线
    rates = ctx['rates']
    for j, h in enumerate(['日期', 'V0 达成率', 'V1 达成率', 'V2 达成率']):
        c = ws.cell(row=3, column=7 + j, value=h)
        c.font = F(True, 9, 'FFFFFF'); c.fill = HEAD_FILL; c.alignment = CENTER; c.border = BORDER
    for i, r in enumerate(rates):
        put(ws, 4 + i, 7, r['d'], align=CENTER, numfmt='mm-dd')
        for j, key in enumerate(('v0', 'v1', 'v2')):
            put(ws, 4 + i, 8 + j, r[key], align=CENTER, numfmt='0.0%')
    n = len(rates)
    ch = LineChart()
    style_chart(ch, '阶段达成率趋势 (V0 / V1 / V2)', '比例', 16, 7.5)
    ch.add_data(Reference(ws, min_col=8, max_col=10, min_row=3, max_row=3 + n), titles_from_data=True)
    ch.set_categories(Reference(ws, min_col=7, min_row=4, max_row=3 + n))
    ch.x_axis.number_format = 'mm-dd'
    ch.y_axis.number_format = '0%'
    ch.y_axis.scaling.min = 0
    ch.y_axis.scaling.max = 1
    for s_, (c, dsh, mk) in zip(ch.series, [('2E75B6', 'solid', 'circle'), ('ED7D31', 'solid', 'triangle'), ('70AD47', 'solid', 'circle')]):
        style_series(s_, c, dsh, mk)
    ws.add_chart(ch, 'L3')
    # 今天比昨天
    r = 8
    ws.cell(row=r, column=1, value=f'今天比昨天 (KR 取每天最后一个硬件实测值；绿 = 变好，红 = 变差，蓝 = 新出现)').font = F(True, 12)
    r += 1
    header(ws, r, ['KR', '变化', '指标', '昨日 → 今日', 'V0 / V1 / V2 目标；今日来源'])
    chg = ctx['changes']
    if not chg:
        r += 1
        put(ws, r, 1, '今天没有新的硬件实测值')
    for k, prev, cv, v in chg:
        r += 1
        fill = CH_FILL[v]
        put(ws, r, 1, k['kr_id'], fill=fill)
        put(ws, r, 2, CH_TXT[v], fill=fill, align=CENTER)
        put(ws, r, 3, f'{k["指标名"]} ({k["单位"]}, {k["方向"]})', fill=fill)
        txt = (f'{fmt(prev[1])} ({prev[0]:%m-%d}) → {fmt(cv)}' if prev else f'(无) → {fmt(cv)}')
        put(ws, r, 4, txt, fill=fill)
        src = next((m['来源'] for m in reversed(ctx['by_kr'][k['kr_id']]) if m['_d'] == today and is_real(m['硬件/阶段'])), '')
        put(ws, r, 5, f'{k["V0 目标"] or "—"} / {k["V1 目标"] or "—"} / {k["V2 目标"] or "—"}；{src}', fill=fill)
    # 阶段出口清单
    for lst in OrderedDict.fromkeys(g[0]['清单'] for g in ctx['gates']):
        rows_ = [x for x in ctx['gates'] if x[0]['清单'] == lst]
        r += 2
        ws.cell(row=r, column=1, value=f'阶段出口清单 — {lst}  (已打勾 {sum(1 for x in rows_ if x[1] == "✅")}/{len(rows_)}；状态由关联项在当日是否完成/达标推出)').font = F(True, 12)
        r += 1
        header(ws, r, ['序号', '状态', '条目', '关联项进度', '来源'])
        for g, st, n, m in rows_:
            r += 1
            put(ws, r, 1, g['序号'], align=CENTER)
            put(ws, r, 2, st, fill=GATE_FILL[st], align=CENTER)
            put(ws, r, 3, g['条目'])
            put(ws, r, 4, (f'{g["关联(交付/KR 编号)"]} ({n}/{m})' if m else '人工状态'))
            put(ws, r, 5, g['来源'])
    # 风险表
    r += 2
    ws.cell(row=r, column=1, value='风险表 (risks.csv；红 = 开，黄 = 监控，绿 = 关)').font = F(True, 12)
    r += 1
    header(ws, r, ['编号', '状态', '风险', '影响 / 应对', '负责 · 登记日期 · 来源'])
    for x in ctx['risks']:
        r += 1
        f_ = RISK_FILL.get(x['状态(开/监控/关)'], 'FFFFFF')
        put(ws, r, 1, x['编号'], fill=f_, align=CENTER)
        put(ws, r, 2, x['状态(开/监控/关)'], fill=f_, align=CENTER)
        put(ws, r, 3, x['风险'], fill=f_)
        put(ws, r, 4, f'影响：{x["影响"]}\n应对：{x["应对/退路"]}', fill=f_)
        put(ws, r, 5, f'{x["负责"]} · {x["登记日期"]} · {x["来源"]}', fill=f_)
    # 每日流水
    r += 2
    ws.cell(row=r, column=1, value='每日流水 (daily_log.csv，按天倒序)').font = F(True, 12)
    r += 1
    header(ws, r, ['日期', '类型', '编号', '内容', '来源'])
    for e in ctx['log']:
        r += 1
        put(ws, r, 1, e['_d'], align=CENTER, numfmt='yyyy-mm-dd')
        put(ws, r, 2, e['类型'], fill=LOG_FILL.get(e['类型']), align=CENTER)
        put(ws, r, 3, e['编号'])
        put(ws, r, 4, e['内容'])
        put(ws, r, 5, e['来源'])
    ws.freeze_panes = 'A4'
    return ws


def html_daily(ctx, today):
    cur = ctx['cur']
    o = []
    o.append('<h2>阶段达成率</h2><div style="display:flex;gap:10px">')
    cards = [(f'{P} 达成率', cur[P]['rate'], f'{cur[P]["n"]} / {cur[P]["m"]}', f'KR {cur[P]["kr"][0]}/{cur[P]["kr"][1]} + 交付 {cur[P]["dl"][0]}/{cur[P]["dl"][1]}') for P in STAGES]
    for n, v, fr, sub in cards:
        o.append(f'<div style="flex:1;border:1px solid #ccc;border-top:4px solid #1F4E78;padding:6px 10px"><div style="color:#666">{n}</div>'
                 f'<div style="font-size:28px;font-weight:700">{pct(v)}</div><div>分子/分母：<b>{fr}</b></div><div style="color:#666">{esc(sub)}</div></div>')
    o.append('</div><ul style="margin:6px 0;padding-left:18px;color:#444">' + ''.join(f'<li>{esc(a)}</li>' for a in ALGO) + '</ul>')
    rates = ctx['rates']
    ser = [('V0 达成率', [(r['d'], r['v0']) for r in rates], '2E75B6', False, True),
           ('V1 达成率', [(r['d'], r['v1']) for r in rates], 'ED7D31', False, True),
           ('V2 达成率', [(r['d'], r['v2']) for r in rates], '70AD47', False, True)]
    o.append('<div style="width:55%">' + svg_chart(ser, w=520, h=220, yfmt=lambda v: f'{v:.0%}', title='阶段达成率趋势 (按日期)', yzero=True) + '</div>')
    o.append('<h2>今天比昨天 (每个 KR 取每天最后一个硬件实测值；绿 = 变好，红 = 变差，蓝 = 新出现)</h2>')
    colors = {'up': '#C6EFCE', 'down': '#FFC7CE', 'new': '#BDD7EE', 'same': '#F2F2F2'}
    if not ctx['changes']:
        o.append('<div>今天没有新的硬件实测值</div>')
    else:
        o.append('<table><tr><th>KR</th><th>变化</th><th>指标</th><th>昨日 → 今日</th><th>V0 / V1 / V2 目标</th></tr>')
        for k, prev, cv, v in ctx['changes']:
            txt = (f'{fmt(prev[1])} ({prev[0]:%m-%d}) → <b>{fmt(cv)}</b>' if prev else f'(无) → <b>{fmt(cv)}</b>')
            o.append(f'<tr style="background:{colors[v]}"><td>{k["kr_id"]}</td><td class="c">{CH_TXT[v]}</td><td>{esc(k["指标名"])} ({esc(k["单位"])}, {esc(k["方向"])})</td>'
                     f'<td>{txt}</td><td class="c">{esc(k["V0 目标"] or "—")} / {esc(k["V1 目标"] or "—")} / {esc(k["V2 目标"] or "—")}</td></tr>')
        o.append('</table>')
    for lst in OrderedDict.fromkeys(g[0]['清单'] for g in ctx['gates']):
        rows_ = [x for x in ctx['gates'] if x[0]['清单'] == lst]
        o.append(f'<h2>阶段出口清单 — {esc(lst)} (已打勾 {sum(1 for x in rows_ if x[1] == "✅")}/{len(rows_)})</h2><table><tr><th>序号</th><th>状态</th><th>条目</th><th>关联项进度</th></tr>')
        gc = {'✅': '#C6EFCE', '🔄': '#FFEB9C', '⬜': '#F2F2F2'}
        for g, st, n, m in rows_:
            o.append(f'<tr><td class="c">{esc(g["序号"])}</td><td class="c" style="background:{gc[st]}">{st}</td><td>{esc(g["条目"])}</td><td>{esc(g["关联(交付/KR 编号)"])} ({n}/{m})' if m else
                     f'<tr><td class="c">{esc(g["序号"])}</td><td class="c" style="background:{gc[st]}">{st}</td><td>{esc(g["条目"])}</td><td>人工状态')
            o.append('</td></tr>')
        o.append('</table>')
    o.append('<h2>风险表 (红 = 开，黄 = 监控，绿 = 关)</h2><table><tr><th>编号</th><th>状态</th><th>风险</th><th>影响</th><th>应对 / 退路</th><th>负责</th></tr>')
    rc = {'开': '#FFC7CE', '监控': '#FFEB9C', '关': '#C6EFCE'}
    for x in ctx['risks']:
        st = x['状态(开/监控/关)']
        o.append(f'<tr style="background:{rc.get(st, "#fff")}"><td class="c">{esc(x["编号"])}</td><td class="c">{esc(st)}</td><td>{esc(x["风险"])}</td><td>{esc(x["影响"])}</td><td>{esc(x["应对/退路"])}</td><td>{esc(x["负责"])}</td></tr>')
    o.append('</table>')
    o.append('<h2>每日流水 (daily_log.csv，按天倒序)</h2>')
    lc = {'复验退回': '#FFC7CE', '问题': '#FFEB9C', '交付完成': '#C6EFCE', '复验通过': '#C6EFCE', '里程碑': '#BDD7EE', '决定': '#E4DFEC'}
    last = None
    o.append('<table><tr><th>日期</th><th>类型</th><th>编号</th><th>内容</th><th>来源</th></tr>')
    for e in ctx['log']:
        d = e['日期'] if e['日期'] != last else ''
        last = e['日期']
        o.append(f'<tr><td class="c" style="white-space:nowrap">{d}</td><td class="c" style="white-space:nowrap;background:{lc.get(e["类型"], "#fff")}">{esc(e["类型"])}</td><td class="c">{esc(e["编号"])}</td>'
                 f'<td>{esc(e["内容"])}</td><td style="color:#555">{esc(e["来源"])}</td></tr>')
    o.append('</table>')
    return '\n'.join(o)


def safe_path(path):
    """文件被占用(Windows WinError 32)时改用带 _HHMM 的文件名"""
    if os.path.exists(path):
        try:
            with open(path, 'ab'):
                pass
            return path
        except OSError:
            root, ext = os.path.splitext(path)
            alt = f'{root}_{dt.datetime.now():%H%M}{ext}'
            print(f'提示: {os.path.basename(path)} 被占用, 改写 {os.path.basename(alt)}')
            return alt
    return path


# ---------------------------------------------------------------- HTML (SVG 图)
def esc(s):
    return html.escape(str(s))


def svg_chart(series, w=352, h=190, yfmt=fmt, xdate=True, ydate=False, title='', yzero=False):
    """series: [(name, [(x, y)], color, dash, marker)]; x/y 为 date 或数"""
    pts = [(x, y) for _, p, *_ in series for x, y in p if y is not None]
    if not pts:
        return ''
    X = lambda v: v.toordinal() if isinstance(v, dt.date) else v
    xs = [X(x) for x, _ in pts]
    ys = [X(y) for _, y in pts]
    x0, x1 = min(xs), max(xs)
    y0, y1 = min(ys), max(ys)
    if x0 == x1:
        x0, x1 = x0 - 1, x1 + 1
    if y0 == y1:
        y0, y1 = y0 - 1, y1 + 1
    y1 += (y1 - y0) * 0.06
    if ydate:
        step = 7
    else:
        raw = (y1 - y0) / 4
        mag = 10 ** math.floor(math.log10(raw))
        step = next(m * mag for m in (1, 2, 2.5, 5, 10) if m * mag >= raw)
    y0 = math.floor(y0 / step) * step
    y1 = math.ceil(y1 / step) * step
    if not ydate and min(ys) >= 0 and (y0 < 0 or yzero):
        y0 = 0
    while (y1 - y0) / step < 3:
        y1 += step
    L, R, T, B = 46, 10, 22, 34
    pw, ph = w - L - R, h - T - B
    sx = lambda v: L + (X(v) - x0) / (x1 - x0) * pw
    sy = lambda v: T + ph - (X(v) - y0) / (y1 - y0) * ph
    o = [f'<svg viewBox="0 0 {w} {h}" class="chart">']
    o.append(f'<text x="{L}" y="14" class="ct">{esc(title)}</text>')
    yv = y0
    while yv <= y1 + 1e-9:
        yy = sy(yv)
        lab = dt.date.fromordinal(round(yv)).strftime('%m-%d') if ydate else yfmt(round(yv, 6))
        o.append(f'<line x1="{L}" x2="{w - R}" y1="{yy:.1f}" y2="{yy:.1f}" class="grid"/>')
        o.append(f'<text x="{L - 4}" y="{yy + 3:.1f}" class="yl">{esc(lab)}</text>')
        yv += step
    span = x1 - x0
    if xdate and span <= 8:
        xt = list(range(int(x0), int(x1) + 1))
    else:
        xt = [x0 + span * i / 4 for i in range(5)]
    for xv in xt:
        xx = sx(xv)
        lab = dt.date.fromordinal(round(xv)).strftime('%m-%d') if xdate else fmt(xv)
        o.append(f'<line x1="{xx:.1f}" x2="{xx:.1f}" y1="{T + ph}" y2="{T + ph + 3}" class="axis"/>')
        o.append(f'<text x="{xx:.1f}" y="{h - B + 14}" class="xl">{lab}</text>')
    o.append(f'<line x1="{L}" x2="{w - R}" y1="{T + ph}" y2="{T + ph}" class="axis"/>')
    lx = L
    for name, p, color, dash, marker in series:
        p = [(x, y) for x, y in p if y is not None]
        if not p:
            continue
        d = ' '.join(f'{sx(x):.1f},{sy(y):.1f}' for x, y in p)
        da = ' stroke-dasharray="5 3"' if dash else ''
        o.append(f'<polyline points="{d}" fill="none" stroke="#{color}" stroke-width="1.8"{da}/>')
        if marker:
            for x, y in p:
                o.append(f'<circle cx="{sx(x):.1f}" cy="{sy(y):.1f}" r="3" fill="#{color}"><title>{esc(name)} {x} {fmt(y) if not ydate else y}</title></circle>')
        o.append(f'<rect x="{lx}" y="{h - 12}" width="10" height="3" fill="#{color}"/><text x="{lx + 13}" y="{h - 8}" class="lg">{esc(name)}</text>')
        lx += 13 + 7.2 * len(name) + 10
    o.append('</svg>')
    return ''.join(o)


def bar(p):
    if p is None:
        return ''
    c = '#70AD47' if p >= 0.999 else ('#FFC000' if p >= 0.5 else '#ED7D31')
    return (f'<div style="display:flex;align-items:center;gap:4px"><div style="width:60px;height:8px;background:#eee">'
            f'<div style="width:{p * 60:.0f}px;height:8px;background:{c}"></div></div>{p:.0%}</div>')


def build_html(goals, krs, by_kr, dels, mta, today, out, ctx):
    css = """
:root{--fg:#1a1a1a;--mut:#666;--bd:#ccc}
body{font-family:'Microsoft YaHei','微软雅黑','PingFang SC',sans-serif;color:var(--fg);background:#fff;margin:0;padding:16px;font-size:11px}
h1{font-size:18px;margin:0 0 4px}h2{font-size:14px;margin:18px 0 6px;border-left:4px solid #1F4E78;padding-left:6px}
.sub{color:var(--mut);margin-bottom:8px}
table{border-collapse:collapse;width:100%}th,td{border:1px solid var(--bd);padding:3px 5px;vertical-align:top}
th{background:#1F4E78;color:#fff;font-weight:600}td.c{text-align:center}
.ok{background:#C6EFCE}.doing{background:#FFEB9C}.idle{background:#D9D9D9}.bad{background:#FFC7CE}
.grid-c{display:grid;grid-template-columns:repeat(3,1fr);gap:6px}.grid-2{grid-template-columns:repeat(2,1fr)}.chart{border:1px solid #e5e5e5;background:#fff;width:100%;height:auto;break-inside:avoid}
.chart text{font-family:inherit}.ct{font-size:11px;font-weight:600}.yl{font-size:9px;text-anchor:end;fill:#555}
.xl{font-size:9px;text-anchor:middle;fill:#555}.lg{font-size:9px;fill:#333}
.grid{stroke:#eee}.axis{stroke:#999}
.pb{page-break-before:always}
@page{size:A4 landscape;margin:10mm}
"""
    order = ['bad', 'doing', 'idle', 'ok']
    o = [f'<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><title>显性目的进度</title><style>{css}</style></head><body>']
    o.append(f'<h1>POV3D 显性目的进度看板 — {today}</h1>')
    o.append(f'<div class="sub">OKR：O = 观众看得到的效果，KR = 可量化指标。状态按「最新硬件实测 vs 当前期 {STAGE_KEY} 目标」自动判定。数据：zynq_pov/docs/progress/*.csv，脚本 mk_progress.py。</div>')
    o.append(html_daily(ctx, today))
    # 状态汇总
    cnt = defaultdict(int)
    rows = []
    for g in goals:
        gk = [k for k in krs if k['goal_id'] == g['id']]
        sts = [kr_status(k, by_kr[k['kr_id']]) for k in gk]
        gs = min((s[0] for s in sts), key=order.index) if sts else 'idle'
        cnt[gs] += 1
        for i, (k, (s, lr, la)) in enumerate(zip(gk, sts)):
            show = lr or la
            cur = f'{fmt(show["_v"])}' if show else '—'
            when = f'{show["_d"]:%m-%d} {esc(show["硬件/阶段"])}' if show else ''
            pre = ''
            if i == 0:
                pre = (f'<td rowspan="{len(gk)}" class="c">{g["id"]}</td><td rowspan="{len(gk)}"><b>{esc(g["显性目的"])}</b><br><span style="color:#666">{esc(g["实现途径"])}</span></td>'
                       f'<td rowspan="{len(gk)}" class="c {gs}">{ST[gs][0]}</td>')
            rows.append(f'<tr>{pre}<td>{k["kr_id"]} {esc(k["指标名"])}</td><td class="c">{esc(k["单位"])}</td><td class="c">{cur}</td><td>{when}</td>'
                        f'<td class="c">{esc(k["V0 目标"])}</td><td class="c">{esc(k["V1 目标"])}</td><td class="c">{esc(k["V2 目标"])}</td><td class="c {s}">{ST[s][0]}</td>'
                        f'<td>{bar(v2_progress(k, show))}</td></tr>')
    summ = ' · '.join(f'{ST[k][0]} {ST[k][2]} {cnt[k]}' for k in ('ok', 'doing', 'idle', 'bad'))
    o.append(f'<h2 class="pb">现状 (10 个显性目的：{summ})</h2>')
    o.append('<table><tr><th>#</th><th>显性目的</th><th>状态</th><th>KR</th><th>单位</th><th>最新</th><th>日期/阶段</th><th>V0</th><th>V1</th><th>V2</th><th>KR</th><th>距 V2 达成</th></tr>')
    o += rows
    o.append('</table>')
    # KR 趋势
    o.append('<h2 class="pb">指标趋势 (蓝 = 硬件实测，橙 = 仿真/台架，虚线 = 目标)</h2><div class="grid-c">')
    for k in krs:
        ms = by_kr[k['kr_id']]
        if not ms:
            continue
        real = per_date_last([m for m in ms if is_real(m['硬件/阶段'])])
        sim = per_date_last([m for m in ms if not is_real(m['硬件/阶段'])])
        dates = sorted(set(real) | set(sim))
        d0, d1 = dates[0], dates[-1]
        if d0 == d1:
            d0, d1 = d0 - dt.timedelta(days=1), d1 + dt.timedelta(days=1)
        ser = [('实测', list(real.items()), '2E75B6', False, True),
               ('仿真/台架', list(sim.items()), 'ED7D31', False, True)]
        tg = OrderedDict()
        for n, c in (('V2 目标', 'C00000'), ('V1 目标', '7030A0'), ('V0 目标', '70AD47')):
            v = num(k[n])
            if v is not None:
                tg.setdefault(v, [c, []])[1].insert(0, n.split()[0])
        for v, (c, names) in tg.items():
            ser.append(('/'.join(names) + ' 目标', [(d0, v), (d1, v)], c, True, False))
        o.append(svg_chart(ser, title=f'{k["kr_id"]} {k["指标名"]} ({k["单位"]})'))
    o.append('</div>')
    # 燃起图 + MTA
    bt = burnup_table(dels, today)
    o.append('<h2 class="pb">燃起图 (交付总数 vs 完成数) 与里程碑趋势</h2><div class="grid-c grid-2">')
    o.append(svg_chart([('总范围', [(d, t) for d, t, _, _ in bt], 'A5A5A5', True, False),
                        ('计划累计', [(d, p) for d, _, p, _ in bt], '70AD47', False, False),
                        ('完成累计', [(d, f) for d, _, _, f in bt], '2E75B6', False, True)],
                       w=520, h=250, title='交付燃起图', yzero=True))
    reviews = sorted({r['_r'] for r in mta})
    stones = list(OrderedDict.fromkeys(r['里程碑'] for r in mta))
    pal = ['2E75B6', 'ED7D31', '70AD47', '7030A0', 'C00000', 'BF8F00', '00B0F0', '595959']
    last_e = max(r['_e'] for r in mta)
    ser = [(s, [(r['_r'], r['_e']) for r in mta if r['里程碑'] == s], pal[i % len(pal)], False, True) for i, s in enumerate(stones)]
    ser.append(('对角线', [(reviews[0], reviews[0]), (last_e, last_e)], 'A5A5A5', True, False))
    mta_svg = svg_chart(ser, w=520, h=250, ydate=True, title='里程碑趋势 MTA (横轴评审日期，纵轴预计完成)')
    o.append(mta_svg.replace('class="lg"', 'class="lg" style="display:none"').replace('<rect x=', '<rect style="display:none" x='))
    o.append('</div>')
    o.append('<table style="width:auto;margin-top:6px"><tr><th>里程碑</th>' + ''.join(f'<th>评审 {r:%m-%d}</th>' for r in reviews) + '</tr>')
    for i, s in enumerate(stones):
        o.append(f'<tr><td><span style="color:#{pal[i % len(pal)]}">●</span> {esc(s)}</td>' +
                 ''.join(f'<td class="c">{next((x["_e"].strftime("%m-%d") for x in mta if x["_r"] == r and x["里程碑"] == s), "")}</td>' for r in reviews) + '</tr>')
    o.append('</table>')
    o.append('<h2>交付清单</h2><table><tr><th>id</th><th>名称</th><th>goal</th><th>期</th><th>计划</th><th>完成</th><th>状态</th><th>分支/提交</th></tr>')
    for d in dels:
        st = EMOJI2ST.get(d['状态'], 'idle')
        o.append(f'<tr><td class="c">{d["id"]}</td><td>{esc(d["名称"])}</td><td class="c">{esc(d["服务的 goal_id"])}</td><td class="c">{esc(d["期"])}</td>'
                 f'<td class="c">{d["计划日期"][5:]}</td><td class="c">{d["完成日期"][5:]}</td><td class="c {st}">{d["状态"]}</td><td>{esc(d["分支/提交"])}</td></tr>')
    o.append('</table></body></html>')
    with open(out, 'w', encoding='utf-8') as f:
        f.write('\n'.join(o))


# ---------------------------------------------------------------- 交互式页面
INTERACTIVE_TPL = r"""<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>显性目的进度 (交互)</title><style>
:root{--fg:#1a1a1a;--mut:#777;--bd:#d8d8d8;--ok:#1a9d3c;--bad:#d32f2f}
*{box-sizing:border-box}
body{font-family:'Microsoft YaHei','微软雅黑','PingFang SC',sans-serif;color:var(--fg);background:#f5f6f8;margin:0;padding:14px 18px 96px;font-size:13px}
h1{font-size:19px;margin:0 0 2px}.sub{color:var(--mut);margin-bottom:10px;font-size:12px}
.top{display:flex;gap:10px;align-items:stretch;flex-wrap:wrap}
.card{background:#fff;border:1px solid var(--bd);border-top:4px solid #1F4E78;border-radius:4px;padding:8px 14px;min-width:190px;flex:1}
.card .nm{color:var(--mut)}.card .big{font-size:34px;font-weight:700;line-height:1.15}.card .fr{font-weight:600}.card .dt{color:var(--mut);font-size:12px}
.card.p0{border-top-color:#2E75B6}.card.p1{border-top-color:#ED7D31}.card.p2{border-top-color:#70AD47}
.trend{flex:2;min-width:300px;background:#fff;border:1px solid var(--bd);border-radius:4px;padding:4px 8px}
.trend svg{width:100%;height:auto;display:block}
.algo{color:#555;font-size:11.5px;margin:6px 0 10px;line-height:1.6}
.goal{background:#fff;border:1px solid var(--bd);border-radius:4px;margin-bottom:10px;overflow:hidden}
.gh{background:#1F4E78;color:#fff;padding:5px 10px;display:flex;justify-content:space-between;flex-wrap:wrap;gap:8px}
.gh b{font-size:14px}.gh span{font-size:11.5px;opacity:.92}
table{border-collapse:collapse;width:100%}
th{background:#eef2f7;color:#333;font-weight:600;padding:4px 6px;border-bottom:1px solid var(--bd);text-align:center;font-size:12px}
td{padding:4px 6px;border-bottom:1px solid #eee;vertical-align:top}td.c{text-align:center;white-space:nowrap}
td.n{width:42%}.tag{display:inline-block;font-size:10.5px;border:1px solid #bbb;border-radius:3px;padding:0 4px;color:#666;margin-right:5px}
.pm{display:inline-block;width:16px;font-weight:900;font-size:16px;line-height:1}.plus{color:var(--ok)}.minus{color:var(--bad)}
tr.up{background:#f0fbf2}tr.down{background:#fff1f1}tr.light td.v,tr.light td.n .nm{color:#999}
.sim{color:#999;font-size:11px}tr.bonus td{opacity:.5}tr.bonus .tag{border-style:dashed}
.blk{background:#fff;border:1px solid var(--bd);border-radius:4px;margin-bottom:10px;overflow:hidden}.blk .gh{background:#4a5b6e}
.g-ok{background:#C6EFCE}.g-mid{background:#FFEB9C}.g-no{background:#f2f2f2}.r-开{background:#FFC7CE}.r-监控{background:#FFEB9C}.r-关{background:#C6EFCE}
.two{display:flex;gap:10px;flex-wrap:wrap}.two>div{flex:1;min-width:380px}.fut{color:#aaa}
.bar{position:fixed;left:0;right:0;bottom:0;background:#fff;border-top:2px solid #1F4E78;padding:8px 18px 10px;display:flex;align-items:center;gap:12px;z-index:9}
.bar input[type=range]{flex:1;height:26px}.bar button{font-size:16px;padding:3px 12px;cursor:pointer;border:1px solid #888;background:#f3f3f3;border-radius:4px}
.bar .lab{font-size:18px;font-weight:700;min-width:130px;text-align:center}.bar .lim{color:var(--mut);font-size:11px}
</style></head><body>
<h1>POV3D 显性目的进度 — 交互看板</h1>
<div class="sub">生成日期 __TODAY__ · 拖动底部时间滑块 (或按 ← →) 查看任一天的状态；数据内嵌，不联网。数据源 zynq_pov/docs/progress/*.csv，脚本 mk_progress.py。</div>
<div class="top" id="top"></div>
<div class="algo">达成率_P = (P 目标已达标的 KR 数 + P 需要的交付里已完成数) ÷ (有 P 目标的 KR 数 + P 需要的交付总数)；只计「必须」项 (灰显的是加分项，不进分子分母)；交付需要是嵌套的：V0 = 阶段 V0，V1 = V0 + V1准备，V2 = V1 + V2。KR 达标 = 截至所选日期的最新<b>硬件实测</b>值达到 P 目标；
仿真/台架点不算达标，显示为 🔵。图例：✅ 达成　⬜ 未达成　🔵 仅仿真/台架已达成　— 无该期目标/不需要。名称前 <span class="pm plus">+</span> = 所选当天新完成/新达标，<span class="pm minus">−</span> = 当天变差。</div>
<div id="gates"></div>
<div id="goals"></div>
<div id="risks"></div>
<div class="bar"><button id="prev" title="前一天 (←)">◀</button><input type="range" id="sl" min="0" value="0" step="1"><button id="next" title="后一天 (→)">▶</button>
<div class="lab" id="lab"></div><div class="lim" id="lim"></div></div>
<script>
const DATA=__DATA__;
const STG=['V0','V1','V2'],NEEDS={V0:['V0'],V1:['V0','V1准备'],V2:['V0','V1准备','V2']};
const COL={V0:'#2E75B6',V1:'#ED7D31',V2:'#70AD47'};
const $=id=>document.getElementById(id);
const esc=s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const fmtv=v=>v==null?'—':(Math.abs(v)>=1e6?v.toFixed(0):String(+v.toPrecision(6)));
const addDay=(iso,n)=>{const d=new Date(iso+'T00:00:00Z');d.setUTCDate(d.getUTCDate()+n);return d.toISOString().slice(0,10)};
const better=(k,a,b)=>k.dir==='越大越好'?a>=b:a<=b;
const mByKr={};DATA.mets.forEach(m=>(mByKr[m.kr]=mByKr[m.kr]||[]).push(m));
Object.values(mByKr).forEach(a=>a.sort((x,y)=>x.d<y.d?-1:x.d>y.d?1:x.i-y.i));
function latest(kr,d,real){let r=null;for(const m of mByKr[kr.id]||[]){if(m.d>d)break;if(real===undefined||m.real===real)r=m}return r}
function krState(kr,P,d){const t=kr.t[P];if(t==null)return null;
 const r=latest(kr,d,true);if(r&&better(kr,r.v,t))return 'ok';
 const s=latest(kr,d,false);if(s&&better(kr,s.v,t))return 'sim';return 'no'}
function isDone(x,d){return x.status==='✅'&&x.done&&x.done<=d}
function rates(d){const o={};for(const P of STG){let a=0,b=0;for(const k of DATA.krs){const s=krState(k,P,d);if(s===null)continue;b++;if(s==='ok')a++}
 const nd=DATA.dels.filter(x=>NEEDS[P].includes(x.stage)&&x.level!=='加分');const c=nd.filter(x=>isDone(x,d)).length;
 o[P]={n:a+c,m:b+nd.length,ka:a,kb:b,dc:c,dd:nd.length,r:(b+nd.length)?(a+c)/(b+nd.length):0}}return o}
// 日期轴
const dates=[];for(let d=DATA.start;d<=DATA.today;d=addDay(d,1))dates.push(d);
const allRates=dates.map(rates);
let cur=dates.length-1;
function trendSvg(i){const W=560,H=150,L=34,R=8,T=8,B=20,pw=W-L-R,ph=H-T-B,n=dates.length;
 const X=j=>L+(n>1?j/(n-1):0)*pw,Y=v=>T+ph-v*ph;let o=`<svg viewBox="0 0 ${W} ${H}">`;
 for(let g=0;g<=4;g++){const v=g/4;o+=`<line x1="${L}" x2="${W-R}" y1="${Y(v)}" y2="${Y(v)}" stroke="#eee"/><text x="${L-4}" y="${Y(v)+3}" font-size="9" fill="#777" text-anchor="end">${v*100}%</text>`}
 const step=Math.max(1,Math.round(n/6));for(let j=0;j<n;j+=step)o+=`<text x="${X(j)}" y="${H-5}" font-size="9" fill="#777" text-anchor="middle">${dates[j].slice(5)}</text>`;
 for(const P of STG){o+=`<polyline fill="none" stroke="${COL[P]}" stroke-width="1.8" points="${allRates.map((r,j)=>X(j).toFixed(1)+','+Y(r[P].r).toFixed(1)).join(' ')}"/>`}
 o+=`<line x1="${X(i)}" x2="${X(i)}" y1="${T}" y2="${T+ph}" stroke="#444" stroke-dasharray="3 3"/>`;
 for(const P of STG)o+=`<circle cx="${X(i)}" cy="${Y(allRates[i][P].r)}" r="4.5" fill="${COL[P]}" stroke="#fff" stroke-width="1.5"/>`;
 let lx=L+4;for(const P of STG){o+=`<rect x="${lx}" y="${T+2}" width="10" height="3" fill="${COL[P]}"/><text x="${lx+13}" y="${T+7}" font-size="10" fill="#333">${P}</text>`;lx+=44}
 return o+'</svg>'}
function cards(i){const r=allRates[i];let h='';STG.forEach((P,j)=>{const c=r[P];
 h+=`<div class="card p${j}"><div class="nm">${P} 达成率</div><div class="big">${(c.r*100).toFixed(1)}%</div><div class="fr">${c.n} / ${c.m}</div><div class="dt">KR ${c.ka}/${c.kb} + 交付 ${c.dc}/${c.dd}</div></div>`});
 return h+`<div class="trend">${trendSvg(i)}</div>`}
function icon(s){return s==='ok'?'✅':s==='sim'?'🔵':s==='no'?'⬜':'—'}
function krRow(k,d,prev){
 const rr=latest(k,d,true),ra=latest(k,d),show=rr||ra,sim=!rr&&ra;
 let gain=false,loss=false;const st={},ps={};
 for(const P of STG){st[P]=krState(k,P,d);ps[P]=krState(k,P,prev);if(ps[P]!=='ok'&&st[P]==='ok')gain=true;if(ps[P]==='ok'&&st[P]!=='ok')loss=true}
 // 当天最后一个实测 vs 此前最后一个实测
 const today_=(mByKr[k.id]||[]).filter(m=>m.real&&m.d===d).pop(),before=latest(k,prev,true);
 const worse=today_&&before&&!better(k,today_.v,before.v);
 const mark=gain&&!loss?'<span class="pm plus">+</span>':(loss||worse)?'<span class="pm minus">−</span>':'<span class="pm"></span>';
 const cls=(gain&&!loss)?'up':(loss||worse)?'down':'';
 const allSim=STG.every(P=>st[P]!=='ok')&&STG.some(P=>st[P]==='sim');
 return `<tr class="${cls}${sim?' light':''}"><td class="n">${mark}<span class="tag">KR</span><span class="nm">${esc(k.id)} ${esc(k.name)}</span> <span class="sim">(${esc(k.unit)}, ${esc(k.dir)})</span></td>
 <td class="c v">${show?fmtv(show.v)+(sim?' <span class="sim">仿真/台架</span>':''):'—'}</td>${STG.map(P=>`<td class="c">${icon(st[P])}</td>`).join('')}
 <td class="c v">${show?show.d.slice(5):'—'}</td></tr>`}
function delRow(x,d){const done=isDone(x,d),just=x.status==='✅'&&x.done===d;
 const cell=P=>NEEDS[P].includes(x.stage)?(done?'✅':'⬜'):'—';
 const dt=done?x.done.slice(5):(x.plan?`<span class="fut">计划 ${x.plan.slice(5)}</span>`:'<span class="fut">未排期</span>');
 return `<tr class="${just?'up':''}${x.level==='加分'?' bonus':''}"><td class="n"><span class="pm ${just?'plus':''}">${just?'+':''}</span><span class="tag">${x.level==='加分'?'加分':'交付'}</span><span class="nm">${esc(x.id)} ${esc(x.name)}</span> <span class="sim">[${esc(x.stage)}]</span></td>
 <td class="c v">${done?'已完成':esc(x.status)+' 未完成'}</td>${STG.map(P=>`<td class="c">${cell(P)}</td>`).join('')}<td class="c">${dt}</td></tr>`}
function gateState(g,d){if(!g.links.length)return{s:g.status||'⬜',n:0,m:0};const st=g.list.startsWith('V0')?'V0':'V1';let n=0;
 for(const x of g.links){const k=DATA.krs.find(k=>k.id===x);if(k){if(krState(k,st,d)==='ok')n++}else{const y=DATA.dels.find(y=>y.id===x);if(y&&isDone(y,d))n++}}
 return{s:n===g.links.length?'✅':n?'🔄':'⬜',n,m:g.links.length}}
function gatesHtml(d){const lists=[...new Set(DATA.gates.map(g=>g.list))];let h='<div class="two">';
 for(const l of lists){const rs=DATA.gates.filter(g=>g.list===l).map(g=>({g,...gateState(g,d)}));const ok=rs.filter(r=>r.s==='✅').length;
  h+=`<div class="blk"><div class="gh"><b>阶段出口清单 — ${esc(l)}</b><span>已打勾 ${ok}/${rs.length}</span></div><table><tr><th>状态</th><th>条目</th><th>关联</th></tr>`+
  rs.map(r=>`<tr class="${r.s==='✅'?'g-ok':r.s==='🔄'?'g-mid':'g-no'}"><td class="c">${r.s}</td><td>${esc(r.g.item)}</td><td class="c sim">${r.m?esc(r.g.links.join(' ; '))+' ('+r.n+'/'+r.m+')':'人工'}</td></tr>`).join('')+'</table></div>'}
 return h+'</div>'}
function risksHtml(d){const rs=DATA.risks.filter(r=>r.date<=d);
 return `<div class="blk"><div class="gh"><b>风险表</b><span>开 ${rs.filter(r=>r.status==='开').length} · 监控 ${rs.filter(r=>r.status==='监控').length} · 关 ${rs.filter(r=>r.status==='关').length}（按登记日期随滑块显示）</span></div><table><tr><th>编号</th><th>状态</th><th>风险</th><th>影响</th><th>应对 / 退路</th><th>负责</th></tr>`+
 rs.map(r=>`<tr class="r-${r.status}"><td class="c">${esc(r.id)}</td><td class="c">${esc(r.status)}</td><td>${esc(r.risk)}</td><td>${esc(r.impact)}</td><td>${esc(r.plan)}</td><td class="c">${esc(r.owner)}</td></tr>`).join('')+'</table></div>'}
function goalsHtml(d){const prev=addDay(d,-1);let h='';
 for(const g of DATA.goals){const ks=DATA.krs.filter(k=>k.goal===g.id),ds=DATA.dels.filter(x=>x.goals[0]===g.id);
  const sub=STG.map(P=>{let a=0,b=0;ks.forEach(k=>{const s=krState(k,P,d);if(s!==null){b++;if(s==='ok')a++}});return `${P} ${a}/${b}`}).join(' · ');
  const dm=ds.filter(x=>x.level!=='加分'),v1=dm.filter(x=>x.stage==='V1准备'),v1d=v1.filter(x=>isDone(x,d)).length,all=dm.filter(x=>isDone(x,d)).length;
  h+=`<div class="goal"><div class="gh"><b>${g.id}. ${esc(g.name)}</b><span>KR 达标 ${sub} ｜ 必须交付 完成 ${all}/${dm.length}${v1.length?`（V1 准备 ${v1d}/${v1.length}）`:''}</span></div>
  <table><tr><th>名称</th><th>当前值</th><th>V0</th><th>V1</th><th>V2</th><th>完成/实测日期</th></tr>${ks.map(k=>krRow(k,d,prev)).join('')}${ds.map(x=>delRow(x,d)).join('')}</table></div>`}
 return h}
function render(){const d=dates[cur];$('top').innerHTML=cards(cur);$('goals').innerHTML=goalsHtml(d);$('gates').innerHTML=gatesHtml(d);$('risks').innerHTML=risksHtml(d);
 const wd='日一二三四五六'[new Date(d+'T00:00:00Z').getUTCDay()];$('lab').textContent=d+' 周'+wd;$('sl').value=cur}
const sl=$('sl');sl.max=dates.length-1;$('lim').textContent=dates[0].slice(5)+' ~ '+dates[dates.length-1].slice(5);
sl.addEventListener('input',()=>{cur=+sl.value;render()});
const go=n=>{cur=Math.min(dates.length-1,Math.max(0,cur+n));render()};
$('prev').onclick=()=>go(-1);$('next').onclick=()=>go(1);
document.addEventListener('keydown',e=>{if(e.key==='ArrowLeft'){go(-1);e.preventDefault()}else if(e.key==='ArrowRight'){go(1);e.preventDefault()}});
render();
</script></body></html>
"""


def build_interactive(goals, krs, mets, dels, today, out):
    gates, risks = read_opt('gates.csv'), read_opt('risks.csv')
    import json
    ds = [m['_d'] for m in mets] + [d['_p'] for d in dels if d['_p']] + [d['_f'] for d in dels if d['_f']]
    start = min(ds)
    data = {
        'today': today.isoformat(), 'start': start.isoformat(),
        'goals': [{'id': g['id'], 'name': g['显性目的']} for g in goals],
        'krs': [{'id': k['kr_id'], 'goal': k['goal_id'], 'name': k['指标名'], 'unit': k['单位'], 'dir': k['方向'],
                 't': {P: num(k[f'{P} 目标']) for P in STAGES}} for k in krs],
        'mets': [{'d': m['日期'], 'kr': m['kr_id'], 'v': m['_v'], 'real': is_real(m['硬件/阶段']), 'i': m['_i']} for m in mets],
        'dels': [{'id': d['id'], 'name': d['名称'], 'goals': d['服务的 goal_id'].split(';'), 'stage': d.get('阶段', ''),
                  'plan': d['计划日期'], 'done': d['完成日期'], 'status': d['状态'], 'level': d.get('级别', '必须')} for d in dels],
        'gates': [{'list': g['清单'], 'seq': g['序号'], 'item': g['条目'], 'links': [x.strip() for x in g['关联(交付/KR 编号)'].split(';') if x.strip()], 'status': g['状态']} for g in gates],
        'risks': [{'id': r['编号'], 'risk': r['风险'], 'impact': r['影响'], 'plan': r['应对/退路'], 'owner': r['负责'], 'status': r['状态(开/监控/关)'], 'date': r['登记日期']} for r in risks],
    }
    js = json.dumps(data, ensure_ascii=False).replace('</', '<\\/')
    with open(out, 'w', encoding='utf-8') as f:
        f.write(INTERACTIVE_TPL.replace('__DATA__', js).replace('__TODAY__', today.isoformat()))



def to_pdf(html_path, pdf_path):
    if not os.path.exists(EDGE):
        print('找不到 Edge, 跳过 PDF')
        return False
    if os.name == 'nt':
        w = lambda p: p
    else:
        w = lambda p: subprocess.check_output(['wslpath', '-w', p], text=True).strip()
    # Edge 写中文路径偶有问题: 先打到临时英文名再改名
    tmp = os.path.join(HERE, '_snapshot_tmp.pdf')
    if os.path.exists(tmp):
        os.remove(tmp)
    url = 'file:///' + w(html_path).replace('\\', '/')
    cmd = [EDGE, '--headless', '--disable-gpu', '--no-pdf-header-footer',
           f'--print-to-pdf={w(tmp)}', url]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)
    if os.path.exists(tmp) and os.path.getsize(tmp) > 0:
        pdf_path = safe_path(pdf_path)
        try:
            shutil.move(tmp, pdf_path)
        except OSError:
            root, ext = os.path.splitext(pdf_path)
            pdf_path = f'{root}_{dt.datetime.now():%H%M}{ext}'
            print(f'提示: PDF 被占用, 改写 {os.path.basename(pdf_path)}')
            shutil.move(tmp, pdf_path)
        print('写出', pdf_path)
        return True
    print('PDF 生成失败')
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--date', default=dt.date.today().isoformat())
    ap.add_argument('--no-pdf', action='store_true')
    a = ap.parse_args()
    today = dt.date.fromisoformat(a.date)
    goals, krs, mets, dels, mta = load()
    by_kr = defaultdict(list)
    for m in sorted(mets, key=lambda m: (m['_d'], m['_i'])):
        by_kr[m['kr_id']].append(m)
    rates = update_daily_rates(krs, mets, dels, today)
    ctx = {'cur': compute_rates(krs, mets, dels, today), 'rates': rates, 'by_kr': by_kr,
           'changes': kr_changes(krs, by_kr, today), 'log': read_log(today),
           'gates': gate_states(read_opt('gates.csv'), krs, by_kr, dels, today), 'risks': read_opt('risks.csv')}
    wb = Workbook()
    sheet_status(wb, goals, krs, by_kr, today)
    sheet_trends(wb, krs, by_kr)
    sheet_burnup(wb, dels, today)
    sheet_mta(wb, mta)
    sheet_history(wb, krs, mets)
    sheet_daily(wb, ctx, today)
    base = os.path.join(HERE, f'显性目的进度_{today}')
    xlsx = safe_path(base + '.xlsx')
    try:
        wb.save(xlsx)
    except PermissionError:
        xlsx = f'{base}_{dt.datetime.now():%H%M}.xlsx'
        print(f'提示: xlsx 被占用, 改写 {os.path.basename(xlsx)}')
        wb.save(xlsx)
    htm = safe_path(base + '.html')
    build_html(goals, krs, by_kr, dels, mta, today, htm, ctx)
    print('写出', xlsx, htm)
    ih = safe_path(os.path.join(HERE, '显性目的进度_交互.html'))
    build_interactive(goals, krs, mets, dels, today, ih)
    print('写出', ih)
    if not a.no_pdf:
        to_pdf(htm, base + '.pdf')


if __name__ == '__main__':
    main()
