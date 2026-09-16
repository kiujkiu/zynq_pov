# -*- coding: utf-8 -*-
"""把 GW5A转LED转接板_逐球引脚分配_mkxlsx.py 产出的 pinplan.json 渲染成单文件 HTML (Artifact / 离线查看)。
用法: python3 GW5A转LED转接板_逐球引脚分配_html.py 输出目录   (读 输出目录/pinplan.json, 写 输出目录/GW5A转LED转接板_逐球引脚分配.html)
"""
import json, os, sys

outdir = sys.argv[1]
data = json.load(open(os.path.join(outdir, 'pinplan.json'), encoding='utf-8'))
payload = json.dumps(data, ensure_ascii=False).replace('</', '<\\/')

HTML = r'''<title>GW5A 转接板引脚分配</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+Condensed:wght@500;600&family=JetBrains+Mono:wght@400;600&display=swap">
<style>
:root{
  --ground:#F1F4F2; --surface:#FFFFFF; --ink:#15201B; --muted:#5A6863; --line:#D3DBD7; --soft:#E6ECE9;
  --accent:#1D6B48; --accent-ink:#FFFFFF;
  --c-down:#2F67B1; --c-up:#16845A; --c-sb:#B8761A; --c-ack:#7650B3; --c-ctl:#B6435A;
  --c-jtag:#1F7F8C; --c-pwr:#9A5B2E; --c-gnd:#9AA6A1; --c-mipi:#C9D1CD;
  --ok-bg:#E1F0E6; --ok-ink:#1C5E38; --warn-bg:#FBEFD6; --warn-ink:#7A4E08; --bad-bg:#F8E0E0; --bad-ink:#8E2A2A;
  --sans:"PingFang SC","Microsoft YaHei","Noto Sans SC","Source Han Sans SC",system-ui,sans-serif;
  --cond:"IBM Plex Sans Condensed","PingFang SC","Microsoft YaHei",system-ui,sans-serif;
  --mono:"JetBrains Mono",ui-monospace,"SFMono-Regular",Consolas,"Microsoft YaHei",monospace;
}
@media (prefers-color-scheme: dark){
  :root:not([data-theme="light"]){
    --ground:#0F1513; --surface:#161E1B; --ink:#E3EAE6; --muted:#98A6A0; --line:#2B3833; --soft:#1D2723;
    --accent:#5CC093; --accent-ink:#0B1410;
    --c-down:#6B9FE3; --c-up:#4CC08C; --c-sb:#E0A54A; --c-ack:#A98AE6; --c-ctl:#E27A90;
    --c-jtag:#56B9C6; --c-pwr:#C98B5E; --c-gnd:#5E6B66; --c-mipi:#34413C;
    --ok-bg:#183826; --ok-ink:#8FDDB0; --warn-bg:#3A2C10; --warn-ink:#F0C877; --bad-bg:#3D1C1C; --bad-ink:#F2A3A3;
  }
}
:root[data-theme="dark"]{
  --ground:#0F1513; --surface:#161E1B; --ink:#E3EAE6; --muted:#98A6A0; --line:#2B3833; --soft:#1D2723;
  --accent:#5CC093; --accent-ink:#0B1410;
  --c-down:#6B9FE3; --c-up:#4CC08C; --c-sb:#E0A54A; --c-ack:#A98AE6; --c-ctl:#E27A90;
  --c-jtag:#56B9C6; --c-pwr:#C98B5E; --c-gnd:#5E6B66; --c-mipi:#34413C;
  --ok-bg:#183826; --ok-ink:#8FDDB0; --warn-bg:#3A2C10; --warn-ink:#F0C877; --bad-bg:#3D1C1C; --bad-ink:#F2A3A3;
}
*{box-sizing:border-box}
body{background:var(--ground);color:var(--ink);font-family:var(--sans);font-size:14px;line-height:1.6}
.wrap{max-width:1180px;margin:0 auto;padding-inline:20px;padding-block:28px 64px;display:flex;flex-direction:column;gap:36px}
h1,h2,h3{font-family:var(--cond);text-wrap:balance;margin:0;line-height:1.25}
h1{font-size:30px;font-weight:600;letter-spacing:.01em}
h2{font-size:20px;font-weight:600}
h3{font-size:15px;font-weight:600}
.mono{font-family:var(--mono);font-size:12.5px}
.eyebrow{font-family:var(--cond);font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted)}
p{margin:0;max-width:72ch}
/* 标题栏: 仿原理图图框 */
.titleblock{display:grid;grid-template-columns:1fr auto;border:1px solid var(--line);background:var(--surface)}
.titleblock .main{padding:18px 20px;display:flex;flex-direction:column;gap:8px;border-right:1px solid var(--line)}
.titleblock .meta{display:grid;grid-template-columns:auto auto;font-size:12.5px;align-content:start}
.titleblock .meta div{padding:6px 14px;border-bottom:1px solid var(--line)}
.titleblock .meta div:nth-child(odd){color:var(--muted);border-right:1px solid var(--line)}
.titleblock .meta div:nth-last-child(-n+2){border-bottom:0}
@media (max-width:720px){.titleblock{grid-template-columns:1fr}.titleblock .main{border-right:0;border-bottom:1px solid var(--line)}}
.stats{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:1px;background:var(--line);border:1px solid var(--line)}
.stat{background:var(--surface);padding:14px 16px;display:flex;flex-direction:column;gap:2px}
.stat b{font-family:var(--cond);font-size:26px;font-weight:600;font-variant-numeric:tabular-nums;line-height:1.1}
.stat span{color:var(--muted);font-size:12.5px}
@media (max-width:720px){.stats{grid-template-columns:repeat(2,minmax(0,1fr))}}
.must{display:flex;flex-direction:column;gap:12px}
.must ol{margin:0;padding-left:22px;display:flex;flex-direction:column;gap:8px;max-width:90ch}
.must li::marker{font-family:var(--cond);font-weight:600;color:var(--accent)}
/* 连接器图 */
.conn{display:flex;flex-direction:column;gap:14px}
.legend{display:flex;flex-wrap:wrap;gap:6px 14px;font-size:12.5px}
.legend span{display:inline-flex;align-items:center;gap:6px}
.sw{width:12px;height:12px;border-radius:2px;display:inline-block}
.strip{overflow-x:auto;border:1px solid var(--line);background:var(--surface);padding:12px 14px}
.strip h3{margin-bottom:8px}
.pins{display:grid;grid-template-columns:repeat(50,minmax(16px,1fr));gap:3px;min-width:880px}
.pin{appearance:none;border:0;padding:0;height:22px;border-radius:2px;cursor:pointer;position:relative;background:var(--c-mipi)}
.pin.chg::after{content:"";position:absolute;left:50%;top:50%;width:5px;height:5px;margin:-2.5px;border-radius:50%;background:var(--surface)}
.pin:focus-visible,.pin.sel{outline:2px solid var(--ink);outline-offset:1px}
.rowlab{display:flex;justify-content:space-between;color:var(--muted);font-size:11px;font-family:var(--mono);min-width:880px;margin:2px 0}
.detail{border:1px solid var(--line);background:var(--surface);padding:12px 16px;display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:6px 20px;min-height:74px}
.detail div{display:flex;flex-direction:column}
.detail dt{color:var(--muted);font-size:11.5px}
.detail dd{margin:0;word-break:break-word}
.detail .wide{grid-column:1/-1}
/* 说明 */
.notes{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:28px 36px}
.notes section{display:flex;flex-direction:column;gap:8px}
.notes dl{margin:0;display:grid;grid-template-columns:auto 1fr;gap:6px 12px}
.notes dt{color:var(--muted);white-space:nowrap}
.notes dd{margin:0}
/* 表 */
.tabs{display:flex;flex-wrap:wrap;gap:0;border-bottom:1px solid var(--line)}
.tab{appearance:none;background:none;border:0;border-bottom:2px solid transparent;margin-bottom:-1px;padding:8px 14px;font:inherit;color:var(--muted);cursor:pointer}
.tab[aria-selected="true"]{color:var(--ink);border-bottom-color:var(--accent);font-weight:600}
.tab:focus-visible{outline:2px solid var(--accent);outline-offset:-2px}
.tools{display:flex;flex-wrap:wrap;gap:10px;align-items:center;padding-block:12px}
.tools input{font:inherit;padding:7px 10px;border:1px solid var(--line);background:var(--surface);color:var(--ink);border-radius:4px;width:min(360px,100%)}
.tools input:focus-visible{outline:2px solid var(--accent);outline-offset:1px}
.tools .count{color:var(--muted);font-size:12.5px;font-variant-numeric:tabular-nums}
.tablebox{overflow:auto;max-height:70vh;border:1px solid var(--line);background:var(--surface)}
table{border-collapse:collapse;font-size:12.5px;width:max-content;min-width:100%}
th,td{border-bottom:1px solid var(--soft);padding:5px 10px;text-align:left;vertical-align:top}
th{position:sticky;top:0;background:var(--soft);font-weight:600;white-space:nowrap;z-index:1}
td{max-width:520px}
td.m{font-family:var(--mono);font-size:12px;white-space:nowrap}
tr:hover td{background:color-mix(in srgb,var(--accent) 6%,transparent)}
.chip{display:inline-block;padding:0 7px;border-radius:9px;font-size:12px;white-space:nowrap}
.chip.ok{background:var(--ok-bg);color:var(--ok-ink)} .chip.warn{background:var(--warn-bg);color:var(--warn-ink)} .chip.bad{background:var(--bad-bg);color:var(--bad-ink)}
.dot{display:inline-block;width:9px;height:9px;border-radius:2px;margin-right:6px;vertical-align:baseline}
footer{color:var(--muted);font-size:12.5px;border-top:1px solid var(--line);padding-top:14px}
@media (prefers-reduced-motion:reduce){*{transition:none!important}}
</style>

<div class="wrap">
  <header class="titleblock">
    <div class="main">
      <div class="eyebrow">POV3D · LED 验证板 · 桥片转接板</div>
      <h1>GW5A 转 LED 灯板转接板 · 逐球引脚分配</h1>
      <p>给硬件改 V01 原理图用。口径：ACK_O 12 根直连、ACK_I 上拉不进 FPGA；上行按模组间接口契约 20 对 + 边带 4 + JTAG 4，球位沿用 9-15 对接表 v3；下行 12 组 × 4 对，12 对时钟 FPGA 直出。</p>
    </div>
    <div class="meta">
      <div>日期</div><div class="mono">2026-09-16</div>
      <div>核心板</div><div class="mono">ACG525-CORE-V2</div>
      <div>器件</div><div class="mono">GW5A-LV25UG324</div>
      <div>对应原理图</div><div class="mono">FPGA LVDS CONNETC V01</div>
      <div>连接器</div><div class="mono">CN3=P1 · CN4=P2</div>
    </div>
  </header>

  <div class="stats" id="stats"></div>

  <section class="must">
    <h2>V01 必须改的</h2>
    <ol id="must"></ol>
  </section>

  <section class="conn">
    <div style="display:flex;flex-direction:column;gap:6px">
      <h2>核心板连接器脚位图</h2>
      <p style="color:var(--muted)">每格一个脚，按用途着色；格中白点 = 与 V01 相比有改动。点一个脚看它的完整分配。</p>
    </div>
    <div class="legend" id="legend"></div>
    <div id="strips"></div>
    <dl class="detail" id="detail"></dl>
  </section>

  <section style="display:flex;flex-direction:column;gap:0">
    <h2 style="margin-bottom:10px">分表</h2>
    <div class="tabs" role="tablist" id="tabs"></div>
    <div class="tools">
      <label for="q" class="eyebrow">筛选</label>
      <input id="q" type="search" placeholder="网名 / 球位 / 信号，如 B5_B8、R49、ACK_O">
      <span class="count" id="count"></span>
    </div>
    <div class="tablebox"><table id="tbl"></table></div>
  </section>

  <section class="notes" id="notes"></section>

  <footer>数据与 xlsx 同源：<span class="mono">GW5A转LED转接板_逐球引脚分配_mkxlsx.py</span> 生成，全部分配有断言自检；约束 <span class="mono">gw5a_led_adapter.cst</span> 已在 Gowin V1.9.12.03 上对 device_version A/B 布局布线出 bit，0 错误 0 警告，154 个端口与本表零差异。</footer>
</div>

<script id="data" type="application/json">__PAYLOAD__</script>
<script>
(function(){
  const D = JSON.parse(document.getElementById('data').textContent);
  const S = D.sheets;
  const esc = s => String(s).replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
  const CLS = [
    ['下行 LVDS','--c-down'],['上行 LVDS','--c-up'],['边带','--c-sb'],['ACK 回读','--c-ack'],['屏控制','--c-ctl'],
    ['JTAG (bank10 专用)','--c-jtag'],['电源','--c-pwr'],['地','--c-gnd'],['MIPI D-PHY 专用','--c-mipi']];
  const colorOf = u => { const f = CLS.find(c => c[0] === u); return f ? `var(${f[1]})` : 'var(--c-mipi)'; };

  // 统计
  const core = S['核心板连接器逐脚'];
  const io = core.rows.filter(r => /^B\d/.test(r[2]));
  const pairsUsed = new Set(io.filter(r => /LVDS/.test(r[12])).map(r => r[2].slice(0,-2))).size;
  const chg = D.chg;
  document.getElementById('stats').innerHTML = [
    [`${io.length}/154`, 'IO 占用（零余量）'],
    [`${pairsUsed}/69`, '差分对（2.5/3.3V 可用）'],
    [`${chg['不变']||0}`, `脚与 V01 相同；另 ${chg['信号不变, 转换器改']||0} 脚只改转换器`],
    [`${chg['改接']||0}`, '脚要改接'],
  ].map(([b,s]) => `<div class="stat"><b>${esc(b)}</b><span>${esc(s)}</span></div>`).join('');

  // 说明 → 必改清单 + 其余分节
  const rd = S['说明'].rows;
  const secs = []; let cur = null;
  rd.slice(1).forEach(([k,v]) => {
    if (!k && !v) return;
    if (/^[一二三四五六七八九十]、/.test(k)) { cur = {title:k, items:[]}; secs.push(cur); if (v) cur.items.push(['', v]); return; }
    if (!cur) { cur = {title:'数据来源', items:[]}; secs.push(cur); }
    cur.items.push([k,v]);
  });
  const must = secs.find(s => s.title.startsWith('三'));
  document.getElementById('must').innerHTML = must.items.map(([,v]) => `<li>${esc(v)}</li>`).join('');
  document.getElementById('notes').innerHTML = secs.filter(s => s !== must).map(s =>
    `<section><h3>${esc(s.title.replace(/^[一二三四五六七八九十]、/,''))}</h3><dl>${s.items.map(([k,v]) => `<dt>${esc(k)}</dt><dd>${esc(v)}</dd>`).join('')}</dl></section>`).join('');

  // 图例
  const cnt = {}; core.rows.forEach(r => cnt[r[12]] = (cnt[r[12]]||0)+1);
  document.getElementById('legend').innerHTML = CLS.filter(c => cnt[c[0]]).map(([n,v]) =>
    `<span><i class="sw" style="background:var(${v})"></i>${esc(n.replace(' (bank10 专用)','').replace(' D-PHY 专用',''))} <span class="mono" style="color:var(--muted)">${cnt[n]}</span></span>`).join('');

  // 连接器条
  const byPin = {}; core.rows.forEach(r => byPin[r[1]] = r);
  const strips = document.getElementById('strips');
  strips.style.cssText = 'display:flex;flex-direction:column;gap:12px';
  [['P1','CN3'],['P2','CN4']].forEach(([p,cn]) => {
    const cell = n => { const r = byPin[`${p}.${n}`]; const changed = /^(改接|信号不变|删除)/.test(r[18]) && /^B\d|^FPGA/.test(r[2]);
      return `<button class="pin${changed?' chg':''}" style="background:${colorOf(r[12])}" data-pin="${p}.${n}" aria-label="${esc(`${cn}.${n} ${r[2]} ${r[13]}`)}" title="${esc(`${cn}.${n} / ${p}.${n}  ${r[2]}  ${r[4]}  ${r[13]}`)}"></button>`; };
    let odd = '', even = '';
    for (let i = 0; i < 50; i++) { odd += cell(2*i+1); even += cell(2*i+2); }
    strips.insertAdjacentHTML('beforeend', `<div class="strip"><h3>${cn} = 核心板 ${p}</h3>
      <div class="rowlab"><span>奇数脚 1</span><span>99</span></div><div class="pins">${odd}</div>
      <div class="pins" style="margin-top:3px">${even}</div><div class="rowlab"><span>偶数脚 2</span><span>100</span></div></div>`);
  });
  const det = document.getElementById('detail');
  const F = [[0,'转接板脚'],[1,'核心板脚'],[2,'核心网名'],[4,'球位'],[5,'bank'],[7,'VCCIO 组'],[12,'用途'],[13,'信号'],[14,'方向'],[15,'IO 标准'],[16,'对端 / 走向'],[17,'V01 原接'],[18,'改动'],[19,'备注']];
  function show(pin){
    const r = byPin[pin]; if (!r) return;
    strips.querySelectorAll('.pin.sel').forEach(b => b.classList.remove('sel'));
    const b = strips.querySelector(`[data-pin="${pin}"]`); if (b) b.classList.add('sel');
    det.innerHTML = F.filter(([i]) => r[i] && r[i] !== '—').map(([i,l]) =>
      `<div class="${i===19?'wide':''}"><dt>${esc(l)}</dt><dd class="${[0,1,2,4].includes(i)?'mono':''}">${esc(r[i])}</dd></div>`).join('');
  }
  strips.addEventListener('click', e => { const b = e.target.closest('.pin'); if (b) show(b.dataset.pin); });
  strips.addEventListener('focusin', e => { const b = e.target.closest('.pin'); if (b) show(b.dataset.pin); });
  show('P2.68');

  // 分表
  const TABS = ['核心板连接器逐脚','下行_按芯片','上行FPC_契约72位','单端与电平转换','V01改线清单','余量与待定'];
  const MONO = /脚|网名|球位|位号|FPGA 信号|^信号$|灯板网名|管脚|対偶|IO 标准/;
  const tabsEl = document.getElementById('tabs'), tbl = document.getElementById('tbl'), q = document.getElementById('q'), countEl = document.getElementById('count');
  let active = TABS[0];
  try { const s = localStorage.getItem('gw5a-adapter-tab'); if (TABS.includes(s)) active = s; } catch(e) {}
  tabsEl.innerHTML = TABS.map((t,i) => `<button class="tab" role="tab" id="tab-${i}" aria-selected="${t===active}" data-t="${esc(t)}">${esc(t.replace(/_/g,' '))} <span class="mono" style="color:var(--muted)">${S[t].rows.length}</span></button>`).join('');
  function chipFor(h, v){
    if (!/改动|动作|状态/.test(h)) return null;
    const s = String(v);
    const k = /^(不变|已验|已定)/.test(s) ? 'ok' : /^(删除|待定)/.test(s) ? 'bad' : 'warn';
    return `<span class="chip ${k}">${esc(s)}</span>`;
  }
  function render(){
    const sh = S[active], h = sh.header, needle = q.value.trim().toLowerCase();
    const useCol = h.indexOf('用途');
    const rows = needle ? sh.rows.filter(r => r.some(c => String(c).toLowerCase().includes(needle))) : sh.rows;
    tbl.innerHTML = `<thead><tr>${h.map(x => `<th>${esc(x)}</th>`).join('')}</tr></thead><tbody>${rows.map(r =>
      `<tr>${r.map((c,i) => { const chip = chipFor(h[i], c); if (chip) return `<td>${chip}</td>`;
        if (i === useCol) return `<td><i class="dot" style="background:${colorOf(c)}"></i>${esc(c)}</td>`;
        return `<td class="${MONO.test(h[i]) && String(c).length < 40 ? 'm' : ''}">${esc(c)}</td>`; }).join('')}</tr>`).join('')}</tbody>`;
    countEl.textContent = needle ? `${rows.length} / ${sh.rows.length} 行` : `${sh.rows.length} 行`;
    tabsEl.querySelectorAll('.tab').forEach(b => b.setAttribute('aria-selected', b.dataset.t === active));
  }
  tabsEl.addEventListener('click', e => { const b = e.target.closest('.tab'); if (!b) return; active = b.dataset.t;
    try { localStorage.setItem('gw5a-adapter-tab', active); } catch(e) {} render(); });
  q.addEventListener('input', render);
  render();
})();
</script>
'''

out = HTML.replace('__PAYLOAD__', payload)
# 离线版 (交付目录, 双击打开): 补文档骨架与 charset; Artifact 发布版 (argv[2]) 不带骨架
offline = ('<!doctype html>\n<html lang="zh-CN"><head><meta charset="utf-8">'
           '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover"></head><body style="margin:0">\n' + out + '\n</body></html>\n')
path = os.path.join(outdir, 'GW5A转LED转接板_逐球引脚分配.html')
open(path, 'w', encoding='utf-8').write(offline)
print(path, len(offline))
if len(sys.argv) > 2:
    open(sys.argv[2], 'w', encoding='utf-8').write(out)
    print(sys.argv[2], len(out))
