const esc = s => String(s).replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const parseSp = list => list.map(v => ({x:v[0], imp:v.endsWith('*')}));
const sev = st => ORDER.indexOf(st);
const bySev = (a, b) => sev(a.st) - sev(b.st);
const stText = n => n.short === S[n.st] ? S[n.st] : `${S[n.st]} · ${n.short}`;
const TYPE = {gate:'门槛', extra:'卖点外'};
const gapOf = n => GAP[n.id] || GAP_DEFAULT[n.st] || '';

const N = {};
SP.forEach(x => N[x.id] = {kind:'sp', id:x.id, name:`${x.id} / ${x.k}`, x});
STAGES.forEach(G => G.t.forEach(s => N[s[0]] = {kind:'step', id:s[0], grp:G.n, name:s[1], sub:s[2], st:s[3], short:s[4], sp:s[5], type:s[5].length ? 'sp' : s[6], subs:[], sups:[]}));
const byKind = k => Object.values(N).filter(n => n.kind === k);
const need = id => N[id] || console.error('缺', id);
CORES.forEach(G => { const st = need(G.step); if (!st) return;
  G.t.forEach(c => { N[c[0]] = {kind:'sub', id:c[0], step:G.step, grp:`${st.grp} · ${st.name}`, name:c[1], sub:c[2], st:c[3], short:c[4], ev:c[5], sp:st.sp}; st.subs.push(c[0]); }); });
SUPS.forEach(G => G.t.forEach(u => N[u[0]] = {kind:'sup', id:u[0], grp:`${G.code} ${G.g}`, name:u[1], sub:u[2], st:u[3], short:u[4], ev:u[5], at:u[6], steps:u[7], buy:u[9], ai:AI[u[0]]}));
byKind('sup').forEach(u => u.steps.forEach(s => need(s) && N[s].sups.push(u.id)));

const taskLinks = () => '';
const sp2Line = id => (SPRINT1[id] ? `<span class="tfocus">V1 冲刺 · ${esc(SPRINT1[id])}</span>` : '')
  + (SPRINT2[id] || SPRINT2_HW[id] ? `<span class="tsp2">V2 冲刺 · ${esc(SPRINT2[id] || SPRINT2_HW[id])}</span>` : '');
const subMarkLines = id => { const m = SUBMARK[id]; if (!m) return '';
  return (m.why ? `<span class="tfocus">${esc(m.why)}</span>` : '') + (m.s1 ? `<span class="tfocus">V1 冲刺 · ${esc(m.s1)}</span>` : '')
    + (m.s2 ? `<span class="tsp2">V2 冲刺 · ${esc(m.s2)}</span>` : ''); };
const caseTodo = id => (CASE_TODO[id] || []).map(t => `<span class="tcase">等 ${esc(t)}</span>`).join('');
const prodOf = id => PROD[id] || (N[id] && N[id].kind === 'sub' ? prodOf(N[id].step) : [NOTE, CASE]);
const prodTags = id => prodOf(id).map(p => `<span class="tag ${p === NOTE ? 'p-note' : 'p-case'}">${p}</span>`).join('');
const lineCls = c => c === HW ? 'c-hw' : c === STR ? 'c-st' : 'c-app';
const carrierTags = id => (CARRIER[id] || []).map(c => `<span class="tag ${lineCls(c)}">${c}</span>`).join('');
const lineOf = n => n.kind === 'step' ? CARRIER[n.id] : n.kind === 'sub' ? CARRIER[n.step] : SUP_LINE[n.grp.split(' ')[0]] || [];
const STEP_ORDER = STAGES.flatMap(G => G.t.map(t => t[0]));
const subsOf = s => N[s].subs.map(i => N[i]);
const chainSubs = x => byKind('sub').flatMap(c => { const p = parseSp(c.sp).find(p => p.x === x); return p ? [{n:c, imp:p.imp}] : []; })
  .sort((a, b) => bySev(a.n, b.n));
const supsOfSubs = subs => [...new Set(subs.flatMap(c => N[c.step].sups))].map(u => N[u]).sort(bySev);

function badges(n){
  if (n.kind !== 'step') return '';
  const ps = parseSp(n.sp);
  if (!ps.length) return `<span class="bdg"><span class="gate">${TYPE[n.type]}</span></span>`;
  return `<span class="bdg">${ps.map(p => `<i data-x="${p.x}" class="${p.imp ? 'imp' : ''}" title="${p.imp ? '隐含承诺' : '服务卖点'} ${p.x}">${p.x}</i>`).join('')}</span>`;
}
const visGrid = v => `<span class="vis">${[v.head, ...v.rows].map((r, i) => `<span class="vr${i ? '' : ' vh'}">${r.map((c, j) => `<span${j === 3 ? ' class="pass"' : ''}>${esc(c)}</span>`).join('')}</span>`).join('')}<span class="vn">${esc(v.note)}</span></span>`;
const aiChip = n => `<span class="tai a-${n.ai}">${AI_LV[n.ai]}</span>`;
const aiBar = items => `<span class="aibar">${Object.keys(AI_LV).map(k => { const c = items.filter(n => n.ai === k).length; return c ? `<i class="a-${k}" style="flex:${c}" title="${AI_LV[k]} ${c}"></i>` : ''; }).join('')}</span>`;
const aiCount = items => Object.keys(AI_LV).map(k => `${AI_LV[k]} ${items.filter(n => n.ai === k).length}`).join(' · ');
function tile(n){
  const tag = n.kind === 'sup' ? `<span class="tag">${esc(n.at)}</span>${n.buy ? `<span class="tag dg-commodity">${n.buy}</span>` : ''}`
    : n.kind === 'step' ? prodTags(n.id) + carrierTags(n.id) : PROD[n.id] ? prodTags(n.id) : '';
  const sub = tag + esc(n.sub || '');
  const ds = n.kind === 'step' ? (n.id in FOCUS ? 'focus' : n.id in SPRINT2 ? 'sp2' : 'step')
    : SUBMARK[n.id] ? (SUBMARK[n.id].s1 ? 'focus' : 'sp2') : CALM.has(n.id) ? 'calm' : n.st;
  return `<button class="tile" type="button" data-l="${(lineOf(n) || []).join(' ')}" data-id="${n.id}" data-s="${ds}"${n.sub ? ` title="${esc(n.sub)}"` : ''} data-p="${n.kind === 'sup' ? 'v1 v2' : prodOf(n.id).join(' ').toLowerCase()}" aria-pressed="false">
    <span class="tt"><span class="tn">${esc(n.name)}</span>${badges(n)}</span>${sub ? `<span class="ts">${sub}</span>` : ''}
    <span class="tst"><i class="dot ${n.st}"></i>${esc(n.short)}</span>${n.kind === 'sup' ? aiChip(n) : ''}${FOCUS[n.id] ? `<span class="tfocus">${esc(FOCUS[n.id])}</span>` : ''}${n.kind === 'step' ? sp2Line(n.id) : subMarkLines(n.id)}${caseTodo(n.id)}${n.kind === 'sub' ? `<span class="tgap">${n.st === 'ok' ? '已达标' : 'GAP：' + esc(gapOf(n))}</span>` : ''}</button>`;
}
const shown = n => n.st;
const BAR_ORDER = ORDER.flatMap(k => k === 'ok' ? ['calm', 'ok'] : [k]);
const barLabel = k => k === 'calm' ? '已确认没问题' : S[k];
function bar(items){
  const c = {}; items.forEach(n => { const k = shown(n); c[k] = (c[k] || 0) + 1; });
  return `<span class="bar">${BAR_ORDER.filter(k => c[k]).map(k => `<span class="seg ${k}" style="flex:${c[k]}" title="${barLabel(k)} ${c[k]}"></span>`).join('')}</span>`;
}
const taskItems = (key, ts) => ts.map((t, i) => `<li><span>${esc(t)}</span><span class="ipds">${taskLinks(key, i)}</span></li>`).join('');
const taskList = (P, key) => { const ts = P ? P.tasks : [];
  return `<div class="pane-task"><span class="pt-h">开发任务 · ${ts.length} 项</span><ol>${taskItems(key, ts) || '<li class="hint">暂无</li>'}</ol></div>`; };
const metricList = P => `<ul class="pane-metric">${(P ? P.metrics : []).map(([k, c, g]) => `<li><b>${esc(k)}</b><span class="mv"><span>现状 ${esc(c)}</span><span>→</span><span class="mg${g === '目标待定' ? ' tbd' : ''}">${esc(g)}</span></span></li>`).join('') || '<li class="hint">暂无</li>'}</ul>`;
const stepMod = id => { const n = N[id], subs = subsOf(id).sort(bySev), P = PLAN[id], gaps = subs.filter(c => c.st !== 'ok').length;
  return `<div class="cg" data-p="${prodOf(id).join(' ').toLowerCase()}"><div class="cg-h" data-id="${id}" role="button" tabindex="0">
      <span class="cg-t"><span class="code">${esc(n.grp)}</span>${esc(n.name)}${prodTags(id)}${carrierTags(id)}</span>
      <small>${esc(stText(n))}</small>
      <span class="cg-n">${bar(subs)}<span>${subs.length} 项 · 有 GAP ${gaps} 项</span></span></div>
    <div class="tiles pane-cap">${subs.map(tile).join('')}</div>${taskList(P, id)}${metricList(P)}</div>`; };
const supCard = G => { const items = G.t.map(t => N[t[0]]), P = PLAN[G.code];
  return `<div class="cg${items.length > 6 ? ' wide' : ''}"><div class="cg-h"><span class="cg-t"><span class="code">${G.code}</span>${G.g}</span><small>${esc(G.role)} · ${G.hire} · ${esc(G.s)}</small><span class="cg-n">${bar(items)}<span>${items.length} 项</span></span></div>
    <div class="tiles pane-cap">${items.map(tile).join('')}</div>${taskList(P, G.code)}${metricList(P)}</div>`; };
function setMode(m){
  document.body.dataset.mode = m;
  document.querySelectorAll('.modebar [data-mode]').forEach(b => b.setAttribute('aria-pressed', b.dataset.mode === m ? 'true' : 'false'));
  try { localStorage.setItem('aibrain-mode', m); } catch (e) {}
}
document.querySelector('.modebar').addEventListener('click', e => { const b = e.target.closest('[data-mode]'); if (b) setMode(b.dataset.mode); });
function setProd(p){
  document.body.dataset.prod = p;
  document.querySelectorAll('.modebar [data-prod]').forEach(b => b.setAttribute('aria-pressed', b.dataset.prod === p ? 'true' : 'false'));
}
document.querySelector('.modebar').addEventListener('click', e => { const b = e.target.closest('[data-prod]'); if (b) setProd(b.dataset.prod); });
function setLine(l){
  document.body.dataset.line = l;
  document.querySelectorAll('.modebar [data-line]').forEach(b => b.setAttribute('aria-pressed', b.dataset.line === l ? 'true' : 'false'));
  document.querySelectorAll('.tile[data-l]').forEach(t => t.classList.toggle('offline', l !== 'all' && !t.dataset.l.split(' ').includes(l)));
}
document.querySelector('.modebar').addEventListener('click', e => { const b = e.target.closest('[data-line]'); if (b) setLine(b.dataset.line); });
let initMode = 'flow';
try { initMode = localStorage.getItem('aibrain-mode') || 'flow'; } catch (e) {}
setMode(['flow','work','metric'].includes(initMode) ? initMode : 'flow');

const $ = id => document.getElementById(id);
const stepTone = id => id in FOCUS ? 'r' : id in SPRINT2 ? 'y' : 'g';
const TONE_RANK = {r:0, y:1, g:2};
const l1Tasks = steps => `<span class="pane-l1">${[...steps].sort((a, b) => TONE_RANK[stepTone(a.n.id)] - TONE_RANK[stepTone(b.n.id)]).map(c => {
  const id = c.n.id, tone = stepTone(id), marks = subsOf(id).filter(u => SUBMARK[u.id]);
  return `<span class="l1s ${tone}"><b>${esc(c.n.name)}${c.imp ? '（隐含）' : ''}</b>${tone === 'g' ? '<span class="l1t">没有排期改动</span>' : marks.map(u => { const m = SUBMARK[u.id];
    return `<span class="l1t"><i>${esc(u.name)}</i>${m.s1 ? `<span class="s1">V1 冲刺 · ${esc(m.s1)}</span>` : ''}${m.s2 ? `<span class="s2">V2 冲刺 · ${esc(m.s2)}</span>` : ''}</span>`; }).join('')}</span>`;
}).join('')}</span>`;
const chainSteps = x => byKind('step').flatMap(s => { const p = parseSp(s.sp).find(p => p.x === x); return p ? [{n:s, imp:p.imp}] : []; });
$('sps').innerHTML = SP.map(x => {
  const steps = chainSteps(x.id), sups = [...new Set(steps.flatMap(c => c.n.sups))].map(u => N[u]);
  const hot = steps.filter(c => c.n.id in FOCUS);
  return `<button class="sp" type="button" data-id="${x.id}" data-x="${x.id}" aria-pressed="false">
    <span class="k"><span>${x.id} / ${x.k}</span><span>${x.en}</span></span>
    <span class="h">${esc(x.h)}</span>
    <span class="cl">${x.claims.map(c => `<span>${esc(c)}</span>`).join('')}</span>${x.vis ? visGrid(x.vis) : ''}
    <span class="wk">${bar([...steps.map(c => c.n), ...sups])}<span>链上 ${steps.length} 个步骤、${sups.length} 项支撑 · 要动：${hot.length ? hot.map(c => `<b>${esc(c.n.name)}</b>${c.imp ? '（隐含）' : ''}`).join('、') : '没有红色卡片'}</span></span>${l1Tasks(steps)}</button>`;
}).join('');
$('stages').innerHTML = STAGES.map(G => `<div class="stage"><div class="st-h">${G.n}</div>${G.t.map(s => tile(N[s[0]])).join('')}</div>`).join('');
$('stepmods').innerHTML = STEP_ORDER.filter(s => N[s].subs.length).map(stepMod).join('');
const groupItems = G => G.t.map(t => N[t[0]]);
$('sups').innerHTML = LINES.map(L => { const gs = SUPS.filter(G => G.line === L.k), items = gs.flatMap(groupItems);
  return `<div class="supline"><b>${L.k}</b><small>${esc(L.d)}</small><span>${gs.length} 组 ${items.length} 项 · ${aiCount(items)}</span>${aiBar(items)}</div><div class="supband">${gs.map(supCard).join('')}</div>`; }).join('');
const allSup = byKind('sup');
$('aisum').innerHTML = `<div class="aisum-k">${Object.keys(AI_LV).map(k => `<div class="cd"><h3><span class="tai a-${k}">${AI_LV[k]}</span> ${allSup.filter(n => n.ai === k).length} 项</h3><p>${esc(AI_DEF[k])}</p></div>`).join('')}</div>
  <p class="tblnote">${Object.keys(HIRE_DEF).map(k => `<span class="hire h-${k}">${k}</span> ${esc(HIRE_DEF[k])}`).join('　')}</p><div class="tw"><table class="aitbl"><thead><tr><th>线</th><th>能力组</th><th>对应岗位</th><th>建议</th><th>AI 分工</th><th>AI 在做</th><th>人要做</th></tr></thead><tbody>${SUPS.map(G => { const it = groupItems(G);
    return `<tr><td>${G.line}</td><td><b>${G.code} ${esc(G.g)}</b></td><td>${esc(G.role)}</td><td><span class="hire h-${G.hire}">${G.hire}</span></td><td class="aic">${aiBar(it)}<span>${Object.keys(AI_LV).map(k => it.filter(n => n.ai === k).length).join(' / ')}</span></td><td>${esc(G.aido)}</td><td>${esc(G.hudo)}</td></tr>`; }).join('')}</tbody></table></div>`;
const allSubs = byKind('sub'), gapSubs = allSubs.filter(c => c.st !== 'ok');
$('mbn').textContent = `子任务 ${allSubs.length} 项，有 GAP ${gapSubs.length} 项 · 开发任务 ${Object.values(PLAN).reduce((a, P) => a + P.tasks.length, 0)} 条`;
$('meta').innerHTML = `<span>卖点 ${SP.length} 个</span><span>流程环节 ${byKind('step').length} 个 · 子任务 ${allSubs.length} 项</span><span>L3 支撑能力 ${SUPS.length} 组 ${byKind('sup').length} 项</span><span>现状截至 2026-11-06</span>`;
$('legend').innerHTML = ORDER.map(k => `<span><i class="dot ${k}"></i>${S[k]}</span>`).join('')
  + `<span class="bdg">${SP.map(x => `<i data-x="${x.id}">${x.id}</i>`).join('')}</span><span>服务的卖点</span>`
  + `<span class="bdg"><i data-x="A" class="imp">A</i></span><span>隐含：卖点没写，但做不好卖点就不成立</span>`
  + `<span><i class="lg-focus"></i>红色卡片：V1 冲刺要动的</span><span><i class="lg-sp2"></i>黄色卡片：V2 冲刺要动的</span>`
  + `<span><span class="tag c-app">软件</span><span class="tag c-hw">硬件</span><span class="tag c-st">结构</span>步骤由哪条线负责</span>`
  + `<span>${Object.keys(AI_LV).map(k => `<span class="tai a-${k}">${AI_LV[k]}</span>`).join(' ')} 支撑能力的 AI 分工</span>`;
function related(id){
  const r = new Set([id]);
  const n = N[id];
  const spOf = o => parseSp(o.sp).forEach(p => r.add(p.x));
  if (n.kind === 'sp'){
    byKind('step').filter(s => parseSp(s.sp).some(p => p.x === id)).forEach(s => { r.add(s.id); s.subs.forEach(c => r.add(c)); s.sups.forEach(u => r.add(u)); });
  } else if (n.kind === 'step'){
    spOf(n); n.subs.forEach(c => r.add(c)); n.sups.forEach(u => r.add(u));
  } else if (n.kind === 'sub'){
    spOf(n); r.add(n.step); N[n.step].sups.forEach(u => r.add(u));
  } else {
    n.steps.forEach(s => { r.add(s); spOf(N[s]); });
  }
  return r;
}

const board = $('board'), detail = $('detail');
let cur = null;
const li = (n, extra) => `<li><button class="lnk" type="button" data-go="${n.id}"><i class="dot ${n.st}"></i><span class="nm">${esc(n.name)}</span>${extra || ''}<span class="sh">${esc(n.short)}</span></button></li>`;
const list = (items, empty) => items.length ? `<ul class="dlist">${items.map(i => i.n ? li(i.n, i.imp ? '<em>隐含</em>' : '') : li(i)).join('')}</ul>` : `<p class="hint">${empty}</p>`;
const spBtn = (x, imp) => `<button type="button" data-go="${x}" data-x="${x}">${N[x].name}${imp ? '（隐含）' : ''}</button>`;
const sec = (label, body) => `<div class="dsec"><span class="dl">${label}</span>${body}</div>`;
const spSec = n => { const ps = parseSp(n.sp);
  if (ps.length) return `<div class="go">${ps.map(p => spBtn(p.x, p.imp)).join('')}</div>`;
  return n.type === 'gate' ? '<p>门槛：不直接产生价值，但走不过去就到不了后面的环节。</p>' : '<p>卖点外：产生价值，但四个卖点里没写。</p>'; };
const iterSec = (why, s1, s2) => why || s1 || s2 ? sec('近期排期', (why ? `<p class="tfocus">${esc(why)}</p>` : '')
  + (s1 ? `<p class="tfocus">V1 冲刺 · ${esc(s1)}</p>` : '') + (s2 ? `<p class="tsp2">V2 冲刺 · ${esc(s2)}</p>` : '')) : '';
const planSecs = (P, key, scope) => P ? sec(`验收标准 · ${P.metrics.length} 项${scope ? `（${scope}）` : ''}`, metricList(P))
  + sec(`开发任务 · ${P.tasks.length} 项${scope ? `（${scope}）` : ''}`, `<ol class="dtask">${taskItems(key, P.tasks)}</ol>`) : '';
function renderDetail(id){
  if (!id){
    detail.innerHTML = `<div class="crumb"><span>怎么读</span></div>
      <p class="hint">点任意卖点、步骤、子任务或支撑能力，这里会显示它的现状和依据；点步骤先看 近期排期和验收标准，再看开发任务、全部子任务和 GAP。先从一个卖点看起：</p>
      <div class="go">${SP.map(x => spBtn(x.id)).join('')}</div>`;
    return;
  }
  const n = N[id];
  const head = (crumb, title, sub, st) => `<div class="crumb"><span>${esc(crumb)}</span><button class="x" type="button" data-clear>清除</button></div>
    <div class="dhead"><h3>${esc(title)}</h3>${sub ? `<span class="sub">${esc(sub)}</span>` : ''}${st ? `<span class="pill"><i class="dot ${n.st}"></i>${esc(stText(n))}</span>` : ''}</div>`;
  let h = '';
  if (n.kind === 'sp'){
    const x = n.x, subs = chainSubs(id), weak = supsOfSubs(subs.map(c => c.n)).filter(u => sev(u.st) <= sev('near'));
    const steps = byKind('step').filter(s => parseSp(s.sp).some(p => p.x === id)).map(s => ({n:s, imp:parseSp(s.sp).find(p => p.x === id).imp}));
    h = head('① 产品价值与卖点', `${x.id} / ${x.k} · ${x.h}`, x.en)
      + (x.vis ? sec('多远看不到颗粒', visGrid(x.vis)) : '')
      + sec('兑现到哪了', `<p>${esc(x.verdict)}</p>`)
      + sec('靠这些步骤兑现', list(steps, '—'))
      + sec('链上最弱的子任务', list(subs.filter(c => sev(c.n.st) <= sev('near')).map(c => ({n:c.n, imp:c.imp})), '没有不达标、未建或看不见的子任务。'))
      + sec('支撑短板', list(weak, '撑着它的支撑能力没有明显短板。'))
      + sec('卖点原文', `<ul>${x.claims.map(c => `<li>${esc(c)}</li>`).join('')}</ul><p class="hint">${esc(x.note)}</p>`);
  } else if (n.kind === 'step'){
    const subs = subsOf(id).sort(bySev), P = PLAN[id];
    h = head(`② 业务流程 · ${n.grp}`, n.name, n.sub, true)
      + iterSec(FOCUS[id], SPRINT1[id], SPRINT2[id] || SPRINT2_HW[id])
      + planSecs(P, id)
      + sec('服务的卖点', spSec(n))
      + sec(`子任务 · ${subs.length} 项，最弱在前`, subs.length ? `<ul class="dsubs">${subs.map(c => `<li><span class="sl-h"><i class="dot ${c.st}"></i><b>${esc(c.name)}</b><span class="sh">${esc(stText(c))}</span></span><span class="gap">${c.st === 'ok' ? '已达标' : 'GAP：' + esc(gapOf(c))}</span><span class="ev">${esc(c.ev)}</span></li>`).join('')}</ul>` : `<p class="hint">${esc(NOSUB[id] || '暂无子任务')}</p>`)
      + sec('L3 支撑能力', list(n.sups.map(u => N[u]).sort(bySev), '—'));
  } else if (n.kind === 'sub'){
    const m = SUBMARK[id] || {};
    h = head(`② 业务流程 · ${n.grp}`, n.name, n.sub, true)
      + iterSec(m.why, m.s1, m.s2)
      + sec('GAP · 要做什么', `<p>${n.st === 'ok' ? '已达标' : esc(gapOf(n))}</p>`)
      + sec('现状依据', `<p>${esc(n.ev)}</p>`)
      + sec('所属步骤', list([N[n.step]], '—'))
      + sec('服务的卖点', spSec(N[n.step]));
  } else {
    const sps = [...new Set(n.steps.flatMap(s => parseSp(N[s].sp).map(p => p.x)))].sort();
    const G = SUPS.find(g => g.t.some(t => t[0] === id));
    h = head(`③ 支撑能力 · ${n.grp}`, n.name, n.sub, true)
      + planSecs(PLAN[G.code], G.code, `${G.code} ${G.g} 整组`)
      + sec('招聘要求', `<p>${esc(REQ[id])}</p><p>对应岗位：${esc(G.role)} · 建议${esc(G.hire)}</p>`)
      + sec('AI 分工', `<p>${aiChip(n)}</p><p>AI 在做：${esc(G.aido)}</p><p>人在做：${esc(G.hudo)}</p>`)
      + sec('现状依据', `<p>${esc(n.ev)}</p>`)
      + sec('支撑范围', `<p>${esc(n.at)}</p>`)
      + (n.buy ? sec('能否外采', `<p>${esc(n.buy)}</p>`) : '')
      + sec('支撑这些步骤', list(n.steps.map(s => N[s]), '不专门撑某一步，影响全部。'))
      + sec('最终撑起的卖点', sps.length ? `<div class="go">${sps.map(x => spBtn(x)).join('')}</div>` : '<p>影响全部。</p>');
  }
  detail.innerHTML = h;
}
function focus(id){
  if (!id || cur === id){ cur = null; board.classList.remove('focusing');
    board.querySelectorAll('[data-id]').forEach(el => { el.classList.remove('on', 'sel'); el.setAttribute('aria-pressed', 'false'); });
    renderDetail(null); document.querySelector('.arch').classList.remove('open'); return; }
  cur = id;
  document.querySelector('.arch').classList.add('open');
  const r = related(id);
  board.classList.add('focusing');
  board.querySelectorAll('[data-id]').forEach(el => {
    const me = el.dataset.id === id;
    el.classList.toggle('on', r.has(el.dataset.id)); el.classList.toggle('sel', me);
    el.setAttribute('aria-pressed', me ? 'true' : 'false');
  });
  renderDetail(id);
}
board.addEventListener('click', e => { const b = e.target.closest('[data-id]'); if (b) focus(b.dataset.id); });
detail.addEventListener('click', e => {
  if (e.target.closest('[data-clear]')) return focus(null);
  const g = e.target.closest('[data-go]'); if (g){ cur = null; focus(g.dataset.go); }
});
document.addEventListener('keydown', e => { if (e.key === 'Escape' && cur) focus(null); if ((e.key === 'Enter' || e.key === ' ') && e.target.matches && e.target.matches('.cg-h[data-id]')) { e.preventDefault(); focus(e.target.dataset.id); } });
renderDetail(null);
const GROUPS = [
  {k:'fix', n:'补差距', d:'不达标、未建、看不见、有差距或只做了一部分：差距已经清楚，可以直接排期。', sts:['miss','plan','blind','near','part']},
  {k:'test', n:'等上板', d:'软件或仿真已就绪，要真硬件出结论。', sts:['hw']},
  {k:'audit', n:'先盘点', d:'有实现或有要求，没核过：先摸清现状，才知道差多少。', sts:['unk']}
];
const ordered = arr => arr.slice().sort((a, b) => STEP_ORDER.indexOf(a.step) - STEP_ORDER.indexOf(b.step) || bySev(a, b));
const goalsHtml = GOALS.map(g => `<div class="cgoal${g.cls ? ' ' + g.cls : ''}"><div class="cgd"><span>${esc(g.v)} 验收交付</span><b>${esc(g.date)}</b></div><ul>${g.goals.map(x => `<li>${esc(x)}</li>`).join('')}<li><b>${esc(g.add)}</b></li></ul></div>`).join('');
$('accept').innerHTML = `<table class="acc"><thead><tr><th>验收项</th><th>V1 · 11-27</th><th>V2 · 12-16</th><th>现状（截至 11-06）</th></tr></thead><tbody>${ACCEPT.map(G => `<tr class="accg"><td colspan="4">${esc(G.g)}</td></tr>` + G.rows.map(([a, b, c, d, s]) => `<tr><td>${esc(a)}${s ? '<span class="acct">建议</span>' : ''}</td><td>${b}</td><td>${c}</td><td class="accn">${esc(d)}</td></tr>`).join('')).join('')}</tbody></table>`;
$('handoff').innerHTML = `<div class="hoscope">${HANDOFF.scope.map(([a, b]) => `<div class="cd"><h3>${esc(a)}</h3><p>${esc(b)}</p></div>`).join('')}</div>`
  + `<h4 class="hoh">V1、V2 要求</h4><div class="tw"><table class="acc"><thead><tr><th>模块</th><th>V1 · 11-27</th><th>V2 · 12-16</th><th>现状（截至 11-06）</th></tr></thead><tbody>${HANDOFF.req.map(([a, b, c, d]) => `<tr><td>${esc(a)}</td><td>${esc(b)}</td><td>${esc(c)}</td><td class="accn">${esc(d)}</td></tr>`).join('')}</tbody></table></div>`
  + `<h4 class="hoh">交付物</h4><div class="tw"><table class="acc hoout"><thead><tr><th>编号</th><th>交付物</th><th>怎样算交付</th></tr></thead><tbody>${HANDOFF.out.map(([v, r]) => `<tr class="accg"><td colspan="3">${esc(v)}</td></tr>` + r.map(([a, b, c]) => `<tr><td>${esc(a)}</td><td><b>${esc(b)}</b></td><td>${esc(c)}</td></tr>`).join('')).join('')}</tbody></table></div>`
  + `<h4 class="hoh">要定的</h4><div class="tw"><table class="acc"><tbody>${HANDOFF.open.map(([a, b]) => `<tr><td>${esc(a)}</td><td>${esc(b)}</td></tr>`).join('')}</tbody></table></div>`;
document.querySelectorAll('.cgoals').forEach(e => { e.innerHTML = goalsHtml; });
$('cadence').innerHTML = CADENCE.map(t => `<div class="ctrack${t.cls ? ' ' + t.cls : ''}"><h3><span class="tag ${lineCls(t.c)}">${t.c}</span>${esc(t.v)}</h3><span class="who">${esc(t.who)}</span><ol class="cline">${t.ms.map(([w, d]) => `<li><span class="when">${esc(w)}</span><span class="what">${esc(d)}</span></li>`).join('')}</ol></div>`).join('');
$('todo-sum').innerHTML = GROUPS.map(g => { const n = gapSubs.filter(c => g.sts.includes(c.st)).length; return `<a class="tsum" href="#todo-${g.k}"><b>${n}</b><span>${g.n}</span></a>`; }).join('');
$('todo').innerHTML = GROUPS.map(g => { const items = ordered(gapSubs.filter(c => g.sts.includes(c.st)));
  return `<h3 class="tbl" id="todo-${g.k}">${g.n} · ${items.length} 项</h3><p class="hint">${g.d}</p>
  <div class="tw"><table class="todo"><thead><tr><th style="width:120px">步骤</th><th style="width:150px">子任务</th><th style="width:150px">现状</th><th>GAP · 要做什么</th><th style="width:70px">卖点</th></tr></thead><tbody>
  ${items.map(c => { const ps = parseSp(c.sp); return `<tr><td class="nm"><b>${esc(N[c.step].name)}</b><span>${esc(N[c.step].grp)}${(CARRIER[c.step] || []).map(c => ' · ' + c).join('')}</span></td><td class="nm"><b>${esc(c.name)}</b><span>${esc(c.sub)}</span></td><td class="st"><span class="pill"><i class="dot ${c.st}"></i>${S[c.st]}</span>${c.short !== S[c.st] ? `<div class="ts">${esc(c.short)}</div>` : ''}</td><td>${esc(gapOf(c))}</td><td>${ps.length ? ps.map(p => p.x + (p.imp ? '（隐含）' : '')).join('、') : TYPE[N[c.step].type]}</td></tr>`; }).join('')}
  </tbody></table></div>`; }).join('');
$('chains').innerHTML = SP.map(x => {
  const subs = chainSubs(x.id), g = {};
  subs.forEach(c => (g[c.n.st] = g[c.n.st] || []).push(c));
  const weak = supsOfSubs(subs.map(c => c.n)).filter(u => sev(u.st) <= sev('near'));
  return `<div class="ch" data-x="${x.id}"><span class="k">${x.id} / ${x.k} · ${x.en}</span><h3>${esc(x.h)}</h3><p>${esc(x.verdict)}</p>
    <div class="srows">${ORDER.filter(k => g[k] && sev(k) <= sev('near')).map(k => `<div class="srow"><span class="sl"><i class="dot ${k}"></i>${S[k]}</span><span>${g[k].map(c => `${esc(c.n.name)}${c.imp ? '<sup>隐含</sup>' : ''}`).join('、')}</span></div>`).join('') || '<div class="srow"><span class="sl">—</span><span>没有明确差距</span></div>'}
      <div class="srow su"><span class="sl">支撑短板</span><span>${weak.length ? weak.map(u => `${esc(u.name)}（${S[u.st]}）`).join('、') : '无'}</span></div></div></div>`;
}).join('');
const stCell = n => `<td class="st"><span class="pill"><i class="dot ${n.st}"></i>${S[n.st]}</span>${n.short !== S[n.st] ? `<div class="ts">${esc(n.short)}</div>` : ''}</td>`;
const nmCell = n => `<td class="nm"><b>${esc(n.name)}</b>${n.sub ? `<span>${esc(n.sub)}</span>` : ''}</td>`;
$('tbody-c').innerHTML = STEP_ORDER.filter(s => N[s].subs.length).map(s => `<tr class="gr"><td colspan="4">${esc(N[s].grp)} · ${esc(N[s].name)}（${esc(stText(N[s]))}）</td></tr>` + subsOf(s).map(c => `<tr>${nmCell(c)}${stCell(c)}<td>${c.st === 'ok' ? '已达标' : esc(gapOf(c))}</td><td>${esc(c.ev)}</td></tr>`).join('')).join('');
$('tbody-s').innerHTML = SUPS.map(G => `<tr class="gr"><td colspan="6">${G.line} · ${G.code} ${G.g} · ${G.role}（${G.hire}）</td></tr>` + G.t.map(t => { const u = N[t[0]];
  return `<tr>${nmCell(u)}<td>${esc(REQ[u.id])}</td>${stCell(u)}<td>${AI_LV[u.ai]}</td><td>${esc(u.ev)}</td><td>${u.steps.length ? u.steps.map(s => esc(N[s].name)).join('、') : '不专门撑某一步，影响全部'}</td></tr>`;
}).join('')).join('');
const FOLD_KEY = 'arch-fold-' + document.title;
let folded = [];
try { folded = JSON.parse(localStorage.getItem(FOLD_KEY) || '[]'); } catch (e) {}
document.querySelectorAll('#board > .lyr').forEach((l, i) => {
  const b = document.createElement('button');
  b.type = 'button'; b.className = 'lyr-fold';
  const sync = () => { const c = l.classList.contains('collapsed'); b.textContent = c ? '展开 ▾' : '收起 ▴'; b.setAttribute('aria-expanded', c ? 'false' : 'true'); };
  if (folded.includes(i)) l.classList.add('collapsed');
  sync();
  b.addEventListener('click', e => { e.stopPropagation(); l.classList.toggle('collapsed'); sync();
    folded = [...document.querySelectorAll('#board > .lyr')].flatMap((x, j) => x.classList.contains('collapsed') ? [j] : []);
    try { localStorage.setItem(FOLD_KEY, JSON.stringify(folded)); } catch (err) {} });
  l.appendChild(b);
});
// ===== 甘特图 =====
(() => {
  const RN = Object.fromEntries(RESULTS.map(r => [r.id, r]));
  const SUPN = Object.fromEntries(SUPS.map(G => [G.code, G.g]));
  const t0 = Date.parse(GSTART + 'T00:00:00');
  const day = md => { const v = Math.round((Date.parse('2026-' + md + 'T00:00:00') - t0) / 864e5); if (!(v >= 0 && v < GDAYS)) console.error('日期越界', md); return v; };
  const col = d => d + 2;
  const rTag = id => RN[id] ? `<span class="tag ${RN[id].v === 'V1' ? 'p-note' : 'p-case'}">${id}</span>` : console.error('缺结果', id);
  const used = new Set();
  let h = `<div class="gantt" style="grid-template-columns:132px repeat(${GDAYS},minmax(0,1fr))">`;
  h += `<div class="gh gcorner" style="grid-row:1;grid-column:1">泳道</div>`;
  h += GWEEKS.map(([w, a, b]) => `<div class="gh gwk" style="grid-row:1;grid-column:${col(day(a))}/${col(day(b)) + 1}"><b>${w}</b><span>${a} ~ ${b}</span></div>`).join('');
  h += GMS.map(([m, n, note], i) => `<div class="gms${i % 2 ? ' lo' : ''}${i === GMS.length - 1 ? ' end' : ''}" style="grid-row:2;grid-column:${col(day(m))}"><span><b>${m}</b> ${esc(n)}${note ? `<i>${esc(note)}</i>` : ''}</span></div>`).join('');
  let row = 3, lastLine = '';
  GLANES.forEach(([c, n, who, sup, segs]) => {
    if (c !== lastLine) { h += `<div class="glinehd" style="grid-row:${row};grid-column:1/-1"><span class="tag ${lineCls(c)}">${c}</span></div>`; row++; lastLine = c; }
    h += `<div class="glane" style="grid-row:${row};grid-column:1"><b>${esc(n)}</b><span>${esc(who)}</span><span class="gsup">${sup.split(' ').map(s => `${s} ${esc(SUPN[s] || console.error('缺支撑', s))}`).join('<br>')}</span></div>`;
    h += GWEEKS.map(([, a, b]) => `<div class="gcell" style="grid-row:${row};grid-column:${col(day(a))}/${col(day(b)) + 1}"></div>`).join('');
    segs.forEach(([a, b, txt, res]) => { res.forEach(x => used.add(x));
      const v2 = res.every(x => RN[x] && RN[x].v === 'V2');
      h += `<div class="gbar ${v2 ? 'v2' : 'v1'}" style="grid-row:${row};grid-column:${col(day(a))}/${col(day(b)) + 1}"><div class="gres">${res.map(rTag).join('')}</div>${esc(txt)}</div>`; });
    row++;
  });
  h += GMS.map(([m]) => `<div class="gline" style="grid-row:2/${row};grid-column:${col(day(m))}"></div>`).join('');
  h += `</div>`;
  RESULTS.forEach(r => used.has(r.id) || console.error('结果没有任务', r.id));
  $('wk').innerHTML = h;
  $('wk-res').innerHTML = `<table class="acc wkres"><thead><tr><th>结果</th><th>V1 · 11-27</th><th>V2 · 12-16</th></tr></thead><tbody>${RESULTS.filter(r => r.v === 'V1').map((r, i) => { const q = RESULTS.filter(x => x.v === 'V2')[i]; const cell = x => x ? `${rTag(x.id)}<b>${esc(x.n)}</b><div class="accn">${esc(x.ok)}</div>` : ''; return `<tr><td>${i + 1}</td><td>${cell(r)}</td><td>${cell(q)}</td></tr>`; }).join('')}</tbody></table>`;
})();
