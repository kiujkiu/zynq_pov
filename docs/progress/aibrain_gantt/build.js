// node build.js -> ../aibrain进度_<日期>.html  (计划取自 ../../aibrain业务架构_src/data.js, 状态取自 status.js)
const fs = require('fs'), path = require('path'), vm = require('vm');
const src = fs.readFileSync(path.join(__dirname, '../../aibrain业务架构_src/data.js'), 'utf8');
const P = vm.runInNewContext(src + ';({RESULTS,GLANES,GMS,GWEEKS,GSTART,GDAYS,GOALS})', {});
const {ASOF, ST, RS} = require('./status.js');
const {RESULTS, GLANES, GMS, GWEEKS, GSTART, GDAYS} = P;

const d0 = new Date(GSTART + 'T00:00:00');
const day = md => Math.round((new Date('2026-' + md + 'T00:00:00') - d0) / 864e5);
const today = day(ASOF.slice(5, 10));
const esc = s => String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;');
const SN = {done:'完成', doing:'进行中', ahead:'提前在做', todo:'未开始', other:'其他窗口 / 同事'};
const otherLane = c => c === '结构' || c === '硬件';

// ---- 总体 ----
const pct = ids => { const a = ids.map(i => RS[i]).filter(r => r && !r.other); return Math.round(a.reduce((s,r)=>s+r.p,0)/a.length); };
const v1 = pct(['R1','R2','R3','R4']);
const swAll = pct(['R1','R2','R3','R4','R10']);
const v2sw = pct(['R7','R9','R10','R12']);

// ---- 甘特 ----
const COLW = 26, LW = 150;
let g = `<div class="gantt" style="width:${LW + COLW*GDAYS}px">`;
g += `<div class="row head"><div class="lane"></div>`;
GWEEKS.forEach(([w, a, b]) => { const s = day(a), e = day(b); g += `<div class="wk" style="left:${LW+s*COLW}px;width:${(e-s+1)*COLW}px">${w} <span>${a}–${b}</span></div>`; });
g += `</div><div class="row ms"><div class="lane">节点</div>`;
GMS.forEach(([d, n], k) => { g += `<div class="msk" style="left:${LW+day(d)*COLW}px;top:${k%2?17:2}px" title="${esc(n)}">◆ ${d} ${esc(n.split(' · ')[0])}</div>`; });
g += `</div>`;
GLANES.forEach(([c, n, who, sup, segs]) => {
  g += `<div class="row"><div class="lane"><b>${esc(n)}</b><small>${esc(who)}</small></div>`;
  segs.forEach(([a, b, txt, rs]) => {
    const st = ST[n + '|' + a] || (otherLane(c) ? {s:'other'} : {s:'todo', p:0});
    const s = day(a), e = day(b);
    const fill = st.s === 'other' ? 0 : st.p;
    g += `<div class="seg ${st.s}" style="left:${LW+s*COLW+1}px;width:${(e-s+1)*COLW-3}px" title="${esc(txt)}${st.n ? '\n— ' + esc(st.n) : ''}">`
       + `<i style="width:${fill}%"></i><span>${esc(txt.split('：')[0])}${st.s !== 'other' && st.p ? ' · ' + st.p + '%' : ''}</span></div>`;
  });
  g += `</div>`;
});
g += `<div class="today" style="left:${LW + today*COLW + COLW/2}px"><span>今天 ${ASOF.slice(5,10)}</span></div></div>`;

// ---- 本周 (W1) 和提前做的 ----
const w1 = [], ahead = [];
GLANES.forEach(([c, n, who, sup, segs]) => segs.forEach(([a, b, txt]) => {
  const st = ST[n + '|' + a]; if (!st) return;
  const row = `<tr><td>${esc(n)}</td><td>${esc(txt)}</td><td><b class="tag ${st.s}">${SN[st.s]}</b></td><td class="num">${st.p}%</td><td>${esc(st.n||'')}</td></tr>`;
  if (day(a) <= 6) w1.push(row); else if (st.s !== 'todo') ahead.push(row);
}));
// 本周软件派活要点 (周初没排进甘特 W1 的也在做)
const extra = [
  ['板上系统与长跑', '软件合主线 + 全回归 (R4)', 'done', 100, '两轮合并: 11-09 merge-1109 / merge-1109b, 54 套回归 49 过, 3 套老问题无关, 2 套纯仿真未跑完'],
  ['板上系统与长跑', '断网不整机复位 (R4)', 'done', 100, '02 实测 9/9 不复位'],
  ['板上系统与长跑', '8 h 无人值守长跑 (R4)', 'done', 100, '两次 14/14 全过 (11-12 旧版, 11-13 新主线 1.9.5)'],
].map(([n, t, s, p, x]) => `<tr><td>${n}</td><td>${t}</td><td><b class="tag ${s}">${SN[s]}</b></td><td class="num">${p}%</td><td>${x}</td></tr>`);

// ---- 结果表 ----
let rt = '';
RESULTS.forEach(r => {
  const x = RS[r.id] || {};
  const bar = x.other ? `<span class="na">本窗口不掌握</span>` : `<div class="bar"><i style="width:${x.p}%"></i></div><b>${x.p}%</b>`;
  rt += `<tr class="${r.v}"><td><b>${r.id}</b></td><td>${r.v}</td><td>${esc(r.n)}</td><td class="barc">${bar}</td><td>${esc(x.n||'')}</td></tr>`;
});

const html = `<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><title>aibrain 进度 ${ASOF.slice(0,10)}</title>
<style>
:root{--ink:#1d2433;--mute:#6b7385;--line:#e3e6ec;--bg:#fff;--done:#2f9e6b;--doing:#2f6fd6;--ahead:#7a4fd0;--todo:#c9ced8;--other:#e9ebef;--warn:#d9822b}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:13px/1.5 "Microsoft YaHei","PingFang SC",sans-serif;padding:20px 24px}
h1{font-size:20px;margin:0 0 2px}h2{font-size:15px;margin:22px 0 8px;border-left:4px solid var(--doing);padding-left:8px}
.sub{color:var(--mute);margin-bottom:14px}
.kpis{display:flex;gap:12px;flex-wrap:wrap}.kpi{border:1px solid var(--line);border-radius:8px;padding:10px 14px;min-width:170px}
.kpi b{font-size:26px;display:block}.kpi small{color:var(--mute)}
.gwrap{overflow-x:auto;border:1px solid var(--line);border-radius:8px}
.gantt{position:relative;font-size:11px}
.row{position:relative;height:40px;border-bottom:1px solid var(--line)}.row.head{height:24px;background:#f6f7f9}.row.ms{height:34px}
.lane{position:absolute;left:0;top:0;width:150px;height:100%;padding:3px 8px;border-right:1px solid var(--line);background:#fafbfc;line-height:1.25}
.lane small{display:block;color:var(--mute);font-size:10px}
.wk{position:absolute;top:0;height:24px;line-height:24px;padding-left:6px;border-left:1px solid var(--line);font-weight:bold}.wk span{color:var(--mute);font-weight:normal}
.msk{position:absolute;white-space:nowrap;color:#b23b3b;font-size:10.5px}
.seg{position:absolute;top:5px;height:30px;border-radius:5px;overflow:hidden;border:1px solid transparent;background:#f1f2f5}
.seg i{position:absolute;left:0;top:0;bottom:0;opacity:.9}.seg span{position:relative;display:block;padding:2px 5px;font-size:10.5px;line-height:1.25;overflow:hidden;max-height:28px}
.seg.done i{background:var(--done)}.seg.done span{color:#fff}
.seg.doing{border-color:var(--doing)}.seg.doing i{background:#bcd3f7}
.seg.ahead{border-color:var(--ahead)}.seg.ahead i{background:#ddd0f6}
.seg.todo{border:1px dashed #aab0bd;background:#fff}.seg.other{background:repeating-linear-gradient(45deg,#f3f4f6 0 6px,#e9ebef 6px 12px);color:var(--mute)}
.today{position:absolute;top:24px;bottom:0;border-left:2px solid #e0453a}.today span{position:absolute;top:-1px;left:3px;background:#e0453a;color:#fff;font-size:10px;padding:0 4px;border-radius:3px;white-space:nowrap}
.legend{display:flex;gap:14px;flex-wrap:wrap;margin:8px 0;color:var(--mute);font-size:12px}.legend em{display:inline-block;width:18px;height:11px;border-radius:3px;vertical-align:-1px;margin-right:4px}
table{border-collapse:collapse;width:100%}td,th{border-bottom:1px solid var(--line);padding:5px 7px;text-align:left;vertical-align:top}th{background:#f6f7f9;font-size:12px}
.num{text-align:right;white-space:nowrap}
.tag{font-size:11px;padding:1px 6px;border-radius:9px;white-space:nowrap;font-weight:normal}
.tag.done{background:#ddf3e8;color:#1f7a50}.tag.doing{background:#dde8fb;color:#2459b3}.tag.ahead{background:#ece3fb;color:#5a37a8}.tag.todo{background:#eee;color:#666}
.barc{white-space:nowrap;width:190px}.bar{display:inline-block;width:120px;height:9px;background:#eceef2;border-radius:5px;margin-right:6px;vertical-align:middle;overflow:hidden}.bar i{display:block;height:100%;background:var(--doing)}
tr.V2 .bar i{background:var(--ahead)}.na{color:var(--mute);font-size:12px}
.note{color:var(--mute);font-size:12px;margin-top:6px}
@media print{body{padding:8px}.gwrap{overflow:visible;border:none}@page{size:A3 landscape;margin:8mm}}
</style></head><body>
<h1>aibrain 进度 · 甘特 + 结果</h1>
<div class="sub">截至 ${ASOF} · 计划取自《aibrain 业务架构》01 节甘特 (11-09 版) · 百分比是估计 (做完的 + 实测过的), 未实测的不算满</div>
<div class="kpis">
 <div class="kpi"><small>V1 (11-27 · TR2) 软件</small><b>${v1}%</b><small>R1–R4 平均 · 还剩 17 天</small></div>
 <div class="kpi"><small>软件总体 (V1 + 互联网 R10)</small><b>${swAll}%</b><small>代码基本写完, 剩实测</small></div>
 <div class="kpi"><small>V2 (12-16 · TR3) 软件相关</small><b>${v2sw}%</b><small>R7 R9 R10 R12, 多数等 V2 回板</small></div>
 <div class="kpi"><small>硬件 / 结构</small><b style="color:var(--mute)">—</b><small>其他窗口 / 同事负责, 这里不估</small></div>
</div>

<h2>甘特 (11-09 ~ 12-16)</h2>
<div class="legend"><span><em style="background:var(--done)"></em>完成</span><span><em style="background:#bcd3f7;border:1px solid var(--doing)"></em>进行中 (填充=完成度)</span><span><em style="background:#ddd0f6;border:1px solid var(--ahead)"></em>提前在做</span><span><em style="border:1px dashed #aab0bd"></em>未开始</span><span><em style="background:repeating-linear-gradient(45deg,#f3f4f6 0 4px,#e2e4e8 4px 8px)"></em>其他窗口 / 同事 (本窗口不掌握)</span><span style="color:#b23b3b">◆ 节点</span></div>
<div class="gwrap">${g}</div>
<div class="note">鼠标停在色块上看完整交付标准和说明。</div>

<h2>本周 (W1 · 11-09 ~ 11-15) 软件</h2>
<table><tr><th>泳道</th><th>本周交付</th><th>状态</th><th class="num">完成</th><th>说明</th></tr>${w1.join('')}${extra.join('')}</table>

<h2>提前在做 (原排在后几周)</h2>
<table><tr><th>泳道</th><th>交付</th><th>状态</th><th class="num">完成</th><th>说明</th></tr>${ahead.join('')}</table>

<h2>12 项结果完成度</h2>
<table><tr><th>结果</th><th>版本</th><th>名称</th><th>完成度</th><th>说明</th></tr>${rt}</table>
<div class="note">风险: V2 11-20 下单 → 12-04 回板零余量, 2260 首次上屏后只剩 12 天; V1 还没上真手机和真 Mac。</div>
</body></html>`;
const out = path.join(__dirname, `../aibrain进度_${ASOF.slice(0,10)}.html`);
fs.writeFileSync(out, html);
console.log(out, 'V1', v1, 'sw', swAll, 'v2sw', v2sw);
