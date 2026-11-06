const $=s=>document.querySelector(s),all=s=>[...document.querySelectorAll(s)],esc=s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
let F={f:'all',ver:'all',stage:'',chain:''},cur=null;
function apply(){const st=F.stage?F.stage.split(','):null;
 all('.bk[data-id]').forEach(el=>{const b=B.find(x=>x.id===el.dataset.id);
  const on=(F.f==='all'||b.t)&&(F.ver==='all'||!b.v||b.v===F.ver)&&(!st||b.steps.some(s=>st.includes(s)))&&(!F.chain||b.ch.includes(F.chain));
  el.classList.toggle('dim',!on);});}
function bar(sel,key){all(sel).forEach(x=>x.addEventListener('click',()=>{all(sel).forEach(y=>y.setAttribute('aria-pressed',y===x));F[key]=x.dataset[key==='f'?'f':'ver'];apply();}));}
bar('[data-f]','f');bar('[data-ver]','ver');
$('#fstage').addEventListener('change',e=>{F.stage=e.target.value;apply()});
$('#fchain').addEventListener('change',e=>{F.chain=e.target.value;apply()});
function show(id){const b=B.find(x=>x.id===id);all('.bk.sel').forEach(x=>x.classList.remove('sel'));
 if(cur===id||!b){cur=null;$('#det').innerHTML='<p class="hint">点模块看详情。</p>';return;}
 cur=id;$('[data-id="'+id+'"]').classList.add('sel');
 $('#det').innerHTML=`<div class="crumb"><span>${esc(LN[b.l])}</span></div><h3>${esc(b.n)}</h3><span class="pill"><i class="dot ${b.st}"></i>${ST[b.st]}</span><p>${esc(b.d)}</p><p class="hint">组件：${esc(b.c)}</p>`
 +(b.t?`<p><b>近期：</b>${esc(b.t)}</p><p><b>验收：</b>${esc(b.a)}</p>`:'')
 +`<p><b>业务步骤：</b>${b.steps.map(s=>esc(SN[s])).join('、')||'无'}</p>`+(b.ch.length?`<p><b>链路：</b>${b.ch.map(c=>CH[c]).join('、')}</p>`:'');}
$('#lay').addEventListener('click',e=>{const x=e.target.closest('.bk[data-id]');if(x)show(x.dataset.id)});
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&cur)show(cur)});
