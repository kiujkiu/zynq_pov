# -*- coding: utf-8 -*-
"""显性目的进度看板 (OKR) → 显性目的进度_<日期>.xlsx + .html + .pdf

数据全在同目录的 CSV (UTF-8 带 BOM, Excel 可直接打开):
  goals.csv        O: 显性目的
  krs.csv          KR: 可量化指标与 V0/V1/V2 目标 (人工状态列可覆盖自动判定)
  metrics.csv      每次实测值 (来源必填)
  deliverables.csv 交付计划与完成
  mta.csv          里程碑趋势 (每次评审追加一组行)

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


def build_html(goals, krs, by_kr, dels, mta, today, out):
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
    o.append(f'<h2>现状 (10 个显性目的：{summ})</h2>')
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
        shutil.move(tmp, pdf_path)
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
    wb = Workbook()
    sheet_status(wb, goals, krs, by_kr, today)
    sheet_trends(wb, krs, by_kr)
    sheet_burnup(wb, dels, today)
    sheet_mta(wb, mta)
    sheet_history(wb, krs, mets)
    base = os.path.join(HERE, f'显性目的进度_{today}')
    wb.save(base + '.xlsx')
    build_html(goals, krs, by_kr, dels, mta, today, base + '.html')
    print('写出', base + '.xlsx', base + '.html')
    if not a.no_pdf and to_pdf(base + '.html', base + '.pdf'):
        print('写出', base + '.pdf')


if __name__ == '__main__':
    main()
