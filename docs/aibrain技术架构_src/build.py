#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 aibrain L1 技术架构、L2 设备架构、L2 主机与云端架构三个单文件 HTML。"""
import json,pathlib,re,html,sys
d=pathlib.Path(__file__).resolve().parent; sys.path.insert(0,str(d))
import model as M, l2data as L
out=d.parent; DATE='2026-11-05'
css=(d.parent/'aibrain业务架构_src/style.css').read_text(encoding='utf-8')+(d/'extra.css').read_text(encoding='utf-8')
biz=(d.parent/'aibrain业务架构_src/data.js').read_text(encoding='utf-8')
STEPS={};STAGE=[]
for g in re.findall(r"\{id:'(g\w+)', n:'([^']+)', t:\[(.*?)\n  \]\}",biz,re.S):
    ids=re.findall(r"\['(s_\w+)','([^']+)'",g[2]); STAGE.append((g[1],[i for i,_ in ids]))
    for i,n in ids: STEPS[i]=n
S={'miss':'不达标','plan':'未建','blind':'看不见','near':'有差距','part':'部分有','unk':'未盘点','hw':'待上板','ok':'达标'}
ORD=list(S)
e=html.escape
dot=lambda s:f'<i class="dot {s}"></i>'
pill=lambda s:f'<span class="pill">{dot(s)}{S[s]}</span>'
def table(head,rows,widths=None):
    th=''.join(f'<th{f" style=\"width:{widths[i]}px\"" if widths and widths[i] else ""}>{h}</th>' for i,h in enumerate(head))
    return f'<div class="tw"><table><thead><tr>{th}</tr></thead><tbody>'+''.join('<tr>'+''.join(f'<td>{c}</td>' for c in r)+'</tr>' for r in rows)+'</tbody></table></div>'
def sec(n,t,p,body): return f'<section><div class="sec-h"><span class="num">{n:02d}</span><h2>{t}</h2><p>{p}</p></div>{body}</section>\n'
def page(title,eyebrow,lead,note,body,foot,js='',fn=''):
    h=f'''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{title}</title><style>body{{margin:0}}[hidden]{{display:none!important}}</style><style>{css}</style></head><body data-mode="flow" data-v="all">
<div class="wrap"><header><div class="eyebrow">{eyebrow}</div><h1>{title}</h1><p class="lead">{lead}</p><p class="v8n">{note}</p></header>
{body}<footer>{foot}</footer></div><script>{js}</script></body></html>'''
    (out/fn).write_text(h,encoding='utf-8'); print(fn,len(h))
LEG='<div class="legend">'+''.join(f'<span>{dot(k)}{v}</span>' for k,v in S.items())+'</div>'
STATE='<div><b>状态</b>：达标＝真硬件实测达到目标；待上板＝软件或仿真已就绪，等真硬件；部分有＝只做了一部分；有差距＝有数据，未达目标；看不见＝没有测量数据；未盘点＝没核过；未建＝还没有。</div>'
LINK={'biz':'aibrain业务架构_v1_2026-11-05.html','l1':f'aibrain-L1-技术架构_{DATE}.html','dev':f'aibrain-L2-设备架构_{DATE}.html','host':f'aibrain-L2-主机与云端架构_{DATE}.html'}
NAV=lambda cur:'<p class="nav">'+' · '.join((f'<b>{t}</b>' if k==cur else f'<a href="{LINK[k]}">{t}</a>') for k,t in [('biz','业务架构'),('l1','L1 技术架构'),('dev','L2 设备架构'),('host','L2 主机与云端')])+'</p>'

# ---------- L1 ----------
nm={l[0]:l[1] for l in M.LAYERS}
blocks=[dict(id=b[0],l=b[1],n=b[2],s=b[3],st=b[4],v=b[5],steps=b[6],ch=b[7],d=b[8],c=b[9],t=b[10],a=b[11]) for b in M.B]
lay=''
for k,n,en,what,rule in M.LAYERS:
    tiles=''.join(f'<button class="bk" type="button" data-id="{b["id"]}" data-s="{b["st"]}" data-v="{b["v"]}"><span class="bn">{dot(b["st"])}{e(b["n"])}{f"<em>{b["v"]}</em>" if b["v"] else ""}</span><span class="bs">{e(b["s"])}</span>{f"<span class=bt>{e(b["t"])}</span>" if b["t"] else ""}</button>' for b in blocks if b['l']==k)
    lay+=f'<div class="ly ly-{k}"><div class="lyh"><b>{n}</b><small>{en}</small></div><div class="bks">{tiles}</div></div>\n'
    ifn={'c':'WiFi：内容帧 · HTTP · 遥测','l':'DDR 共享网格 · 寄存器','p':'FPC：1.0G 上行 · 边带 · JTAG','b':'mini-LVDS','d':'无线供电 · 光电'}.get(k)
    if ifn: lay+=f'<div class="ifl"><span>{ifn}</span></div>\n'
base=''.join(f'<div class="rb">{dot(r[3])}<b>{e(r[1])}</b><small>{e(r[2])}</small><span>{e(r[4])}</span></div>' for r in M.BASE)
ctrl='<div class="modebar"><span class="mb-l">视图</span><button type="button" data-f="all" aria-pressed="true">全部</button><button type="button" data-f="todo" aria-pressed="false">近期要改</button><span class="mb-l sep">版本</span><button type="button" data-ver="all" aria-pressed="true">全部</button><button type="button" data-ver="V1" aria-pressed="false">V1</button><button type="button" data-ver="V2" aria-pressed="false">V2</button><span class="mb-l sep">业务段</span><select id="fstage"><option value="">全部</option>'+''.join(f'<option value="{",".join(i)}">{n}</option>' for n,i in STAGE)+'</select><span class="mb-l sep">链路</span><select id="fchain"><option value="">全部</option>'+''.join(f'<option value="{k}">{v}</option>' for k,v in M.CHAINS.items())+'</select></div>'
b=NAV('l1')
b+=sec(1,'六层各管什么','数据从上往下流：内容从电脑到 WiFi，进主控，切成片，送桥，点亮灯板。研发底座在右侧，不在数据路径上。',table(['层','管什么','边界规则'],[[f'<b>{n}</b>',e(w),e(r)] for k,n,en,w,r in M.LAYERS],[160,None,None]))
b+=sec(2,'架构图','点任一模块看现状和任务；可以按版本、业务段、链路筛选。',ctrl+f'<div class="t-arch"><div class="t-main"><div id="lay">{lay}</div></div><aside class="t-side"><div id="det" class="t-det"><p class="hint">点模块看详情。</p></div><div class="rbh">研发底座</div>{base}</aside></div>'+LEG)
b+=sec(3,'层与层之间怎么接','层间只认这几条接口。',table(['接口','通道','传什么','能力','现状'],[[f'<b>{e(i[0])}</b>',e(i[1]),e(i[2]),e(i[3]),f'{pill(i[4])}<div class="ts">{e(i[5])}</div>'] for i in M.IFS],[200,None,None,130,190]))
b+=sec(4,'主链路落在哪一层','业务架构第 04 节的 10 步核心技术，对应到架构层。',table(['步骤','所在层','模块','现状'],[[f'<b>{i+1}. {e(p[0])}</b>',' → '.join(nm[x] for x in p[1].split('→')),e(p[2]),e(p[3])] for i,p in enumerate(M.PIPE)],[200,240,None,170]))
rows=[]
for k,n,*_ in M.LAYERS:
    bs=[x for x in blocks if x['l']==k]; c={}
    for x in bs:c[x['st']]=c.get(x['st'],0)+1
    bar='<span class="bar">'+''.join(f'<span class="seg {s}" style="flex:{c[s]}" title="{S[s]} {c[s]}"></span>' for s in ORD if s in c)+'</span>'
    gap='、'.join(x['n'] for x in bs if x['st'] in('miss','near','blind','plan')) or '无'
    rows.append([f'<b>{n}</b>',str(len(bs)),bar,e(gap),e('、'.join(x['n'] for x in bs if x['t'])or '无')])
b+=sec(5,'每层一览','缺口只列不达标、有差距、看不见、未建。',table(['层','模块数','现状分布','主要缺口','近期要动'],rows,[150,70,180,None,None]))
b+=sec(6,'近期要改的模块','每个模块写任务和验收。',table(['模块','层','现状','任务','验收'],[[f'<b>{e(x["n"])}</b>',nm[x['l']],pill(x['st']),e(x['t']),e(x['a'])] for x in blocks if x['t']],[150,130,100,None,None]))
b+=sec(7,'需要你确认的口径','图里按括号里的默认处理。','<div class="cards">'+''.join(f'<div class="cd"><h3>{i+1}. {t}</h3><p>{p}</p></div>' for i,(t,p) in enumerate([('版本状态','图上状态按 V1 写，V0 过不算 V1 过。例外是断线恢复：只涉及主控和 WiFi，V0、V1 硬件相同，按实测算达标。（默认：V2 只在模块说明里写。）'),('电机控制板放哪层','它和转子电路不通信，放在转子与定子硬件。（默认：不单列一层。）'),('主机 App','RK3588 App 放在内容端，标未盘点。（默认：不进 V1。）'),('云端','互联网还没开工，只画一个模块，L2 主机与云端里给规划框。（默认：规划项标未建。）')]))+'</div>')
js=f'const B={json.dumps(blocks,ensure_ascii=False)},ST={json.dumps(S,ensure_ascii=False)},SN={json.dumps(STEPS,ensure_ascii=False)},CH={json.dumps(M.CHAINS,ensure_ascii=False)},LN={json.dumps(nm,ensure_ascii=False)};'+(d/'l1.js').read_text(encoding='utf-8')
page('aibrain L1 技术架构',f'L1 技术架构 · 第一版 · {DATE}','aibrain 分六层：内容端、主控 Linux、主控 PL、桥 FPGA、灯板、转子与定子硬件。这份回答「系统分几层，每层有什么模块，层与层怎么接，近期改哪里」。','模块和业务架构的 30 个步骤一一对应，每个步骤都能找到承接它的模块。状态只认真机。',b,f'<div><b>依据</b>：V1 系统说明书（10-27，上行线速按 10-27 晚定的 1.0G 更新）、aibrain 业务架构 v1、配网工况表、V2 桥板交付包、电机固件仓库、代码仓库，截至 {DATE}。</div>'+STATE,js,LINK['l1'])

# ---------- L2 设备 ----------
def box(x,y,w,h,t,s='',cls=''):
    return f'<g class="sb {cls}"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6"/><text x="{x+w/2}" y="{y+(h/2 if not s else h/2-7)+4}" text-anchor="middle" class="st">{e(t)}</text>'+(f'<text x="{x+w/2}" y="{y+h/2+13}" text-anchor="middle" class="ss">{e(s)}</text>' if s else '')+'</g>'
def arrow(x1,y1,x2,y2,t='',cls=''):
    mx,my=(x1+x2)/2,(y1+y2)/2
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" class="sl {cls}" marker-end="url(#ah)"/>'+(f'<text x="{mx}" y="{my-6}" text-anchor="middle" class="sa">{e(t)}</text>' if t else '')
def hwsvg(v):
    v1=v=='V1'; mk='ah'+v
    A=lambda *p,**k:arrow(*p,**k).replace('url(#ah)',f'url(#{mk})')
    path=lambda d,cls='',end=True:f'<path d="{d}" class="sl {cls}"'+(f' marker-end="url(#{mk})"' if end else '')+'/>'
    lab=lambda x,y,t,a='middle':f'<text x="{x}" y="{y}" text-anchor="{a}" class="sa">{e(t)}</text>'
    s=f'<svg viewBox="0 0 1120 470" class="hw" role="img" aria-label="{v} 硬件框图"><defs><marker id="{mk}" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0 0L8 4L0 8z" class="sm"/></marker></defs>'
    s+='<rect x="210" y="14" width="896" height="330" rx="10" class="zone"/><text x="226" y="36" class="zt">转子（跟灯板一起转）</text><rect x="210" y="360" width="896" height="96" rx="10" class="zone z2"/><text x="226" y="382" class="zt">定子（不转）</text>'
    s+=box(16,51,160,70,'电脑','内容 · 运维')+box(16,150,160,70,'手机','配网 · 遥控')+(box(16,250,160,70,'云','未建','pl') if not v1 else '')
    s+=box(236,56,170,60,'WiFi','MT7921AU' if v1 else 'BL-M7921AU1')
    s+=box(236,146,170,70,'主控 DR1M90',('FS03 · 16 bit DDR3L' if v1 else 'CZ06 · 32 bit DDR3L'))
    s+=box(236,250,170,70,'转接底板','140×80 · 24 V 转 5 / 2.5 V' if v1 else '140×80 6 层 · 只摆件')
    bn='ACG525 + 转接板' if v1 else '一体桥板 UG324S'
    s+=box(570,60,180,70,'面 A 桥',bn)+box(570,190,180,70,'面 B 桥',bn)
    ln='12 颗 2260 · 160×180' if v1 else '24 颗 2260 · 192×216'
    s+=box(860,60,226,70,'面 A 灯板',ln)+box(860,190,226,70,'面 B 灯板',ln)
    s+=A(176,86,236,86,cls='w')+path('M176 185 H196 V86','w',False)+(path('M176 285 H196 V185','w',False) if not v1 else '')
    s+=A(321,116,321,146)+lab(336,136,'USB','start')
    s+=A(321,216,321,250)+lab(336,238,'排针 H1/H2' if v1 else 'DF40 板对板','start')
    up='13 lane 1.0G' if v1 else '18 对 1.0G'
    s+=path('M406 270 H480 V95 H570')+path('M480 225 H570')+lab(443,264,'FPC × 2')+lab(525,89,up)+lab(525,219,up)
    dn='6 链 · AXK 100P' if v1 else '2 × 120P'
    s+=A(750,95,860,95)+lab(805,89,dn)+A(750,225,860,225)+lab(805,219,dn)
    s+=box(236,392,170,50,'无线发射','24 V 2 A')+box(520,392,200,50,'电机 + 电机控制板','LKS32MC453 · 无感')+box(860,392,226,50,'光电索引标记','每圈 1 脉冲')
    s+=A(321,392,321,320,cls='p')+lab(336,356,'48 W','start')
    s+=path('M973 392 V300 H406','o')+lab(690,294,'光电 0°')
    return s+'</svg>'
tier=''
for unit,gs in L.STACK:
    g=''
    for n,sub,items in gs:
        t=''.join(f'<div class="sc"><b>{e(i[0])}</b><small>{e(i[1])}</small><span class="dd"><span title="V1 {S[i[2]]}">{dot(i[2])}V1</span><span title="V2 {S[i[3]]}">{dot(i[3])}V2</span></span><code>{e(i[4])}</code></div>' for i in items)
        g+=f'<div class="sg"><div class="sgh"><b>{n}</b><small>{sub}</small></div><div class="scs">{t}</div></div>'
    tier+=f'<h3 class="tbl">{unit}</h3>{g}'
JM={'v':'✓','w':'⚠','x':'✗'}
assert [t[0] for t in L.TRACE]==list(STEPS) and len(STEPS)==30
assert {s for x in M.B for s in x[6]}<=set(STEPS) and set(STEPS)<={s for x in M.B for s in x[6]},'步骤未全覆盖'
tc={k:sum(1 for t in L.TRACE if t[6]==k) for k in JM}
b=NAV('dev')
b+=sec(1,'软件分层','四个执行单元从上到下读。每格两个圆点是 V1 和 V2 的现状，下面是源码或分支。',tier+LEG)
b+=sec(2,'硬件框图','功能边界图，不替代原理图。',f'<div class="vt"><button type="button" data-hv="V1" aria-pressed="true">V1 验证机</button><button type="button" data-hv="V2" aria-pressed="false">V2 产品机</button></div><div id="hwV1" class="hwp"><div class="hwcap">V1 验证机</div>{hwsvg("V1")}</div><div id="hwV2" class="hwp" hidden><div class="hwcap">V2 产品机</div>{hwsvg("V2")}</div><p class="hint">跨旋转面没有电线：供电靠无线，数据靠 WiFi，角度靠光电。电机控制板和转子电路不通信。5 V 电源线从底板到桥和灯板，图上没画，见电源树。V2 的 WiFi 模块焊在底板上。</p>')
b+=sec(3,'硬件模块','按功能块列硬件。',table(['编号','模块','器件','功能','说明','现状','依据'],[[r[0],f'<b>{e(r[1])}</b>',e(r[2]),e(r[3]),e(r[4]),pill(r[5]),e(r[6])] for r in L.CBB],[70,110,None,None,None,100,130]))
b+=sec(4,'电源树','转子全部用电来自 48 W 无线供电。',table(['电源','路径','供给','注意','现状'],[[f'<b>{e(r[0])}</b>',e(r[1]),e(r[2]),e(r[3]),pill(r[4])] for r in L.POWER],[150,None,150,None,100]))
b+=sec(5,'软件部署','每个执行单元上跑什么。',table(['执行单元','承载','现状','说明'],[[f'<b>{e(r[0])}</b>',e(r[1]),pill(r[2]),e(r[3])] for r in L.DEPLOY],[150,None,100,200]))
b+=sec(6,'功能映射与贯通校验',f'业务架构的 30 个步骤逐层往下查。✓ 全层有实现且真机验过（{tc["v"]} 项）；⚠ 全层有实现，但有层待真机或待验证（{tc["w"]} 项）；✗ 有层缺失（{tc["x"]} 项）。',table(['业务步骤','内容端','主控 Linux','主控 PL','桥','硬件 / 结构','判定','说明'],[[f'<b>{e(STEPS[t[0]])}</b>',e(t[1]),e(t[2]),e(t[3]),e(t[4]),e(t[5]),f'<span class="j {t[6]}">{JM[t[6]]}</span>',e(t[7])] for t in L.TRACE],[130,None,None,None,None,None,50,None]))
b+=sec(7,'代码实现对照','实际代码和硬件工程的状态。',table(['分支 / 工程','版本','内容','状态','现状'],[[f'<code>{e(r[0])}</code>',e(r[1]),e(r[2]),e(r[3]),pill(r[4])] for r in L.CODE],[210,None,None,150,100]))
b+=sec(8,'数据流','五条主流程。','<div class="fl">'+''.join(f'<div class="fr"><b>{e(n)}</b><div class="fc">'+'<i>→</i>'.join(f'<span>{e(x)}</span>' for x in xs)+'</div></div>' for n,xs in L.FLOWS)+'</div>')
b+=sec(9,'V1 和 V2 差在哪','公共前端相同，差异集中在显示后端和硬件。',table(['项','V1 验证机','V2 产品机'],[[f'<b>{e(r[0])}</b>',e(r[1]),e(r[2])] for r in L.ROUTE],[130,None,None]))
b+=sec(10,'设计实践','这个项目里定下来的做法。','<div class="cards">'+''.join(f'<div class="cd"><h3>{e(t)}</h3><p>{e(p)}</p></div>' for t,p in L.PRACT)+'</div>')
b+=sec(11,'待定清单','未定的都标在这里。',table(['事项','内容','状态'],[[f'<b>{e(r[0])}</b>',e(r[1]),e(r[2])] for r in L.TBD],[190,None,190]))
b+=sec(12,'术语','','<div class="gl">'+''.join(f'<span><b>{e(a)}</b>{e(c)}</span>' for a,c in L.GLOSS)+'</div>')
js="document.querySelector('.vt').addEventListener('click',e=>{const b=e.target.closest('[data-hv]');if(!b)return;document.querySelectorAll('[data-hv]').forEach(x=>x.setAttribute('aria-pressed',x===b));['V1','V2'].forEach(v=>document.getElementById('hw'+v).hidden=v!==b.dataset.hv)});"
page('aibrain L2 设备架构',f'L2 设备架构 · 第一版 · {DATE}','这份往下讲到设备内部：软件分层、硬件框图、电源、部署、代码状态，并逐个业务步骤核对从内容端到硬件是否贯通。','结论以代码和实测为准。V1 灯板未上屏，所以涉及显示的步骤大多是 ⚠。V1 圆点只认 V1 硬件，V0 过的项写在说明里。',b,f'<div><b>依据</b>：V1 系统说明书、切片规格、VOXSLICE 上板手册、转子运维 README、V2 桥板硬件交付包、V2 底板 README、电机固件仓库，截至 {DATE}。</div>'+STATE,js,LINK['dev'])

# ---------- L2 主机与云端 ----------
H=[('用户入口','USER',[('手机浏览器','配网、遥控、看状态','part','现状，方案由上位机同事确认'),('电脑工具','推流、升级、调试','ok','研发用'),('第三方 3D 软件','当 3D 显示器用','plan','接入方式未定')]),
('内容管线','CONTENT',[('模型体素化','glb_vox：撒点进网格','ok','192×216×192'),('动画体素化','anim_vox：逐帧归一','ok','实转可播'),('实时出帧','voxlive：每帧采样、编码','ok','p99 22 ms'),('模型帧','voxmodel：模型常驻，发位姿','part','动画未覆盖'),('内容编排','content_show：节目单','unk','10 类未验收'),('真实物体重建','扫描转点云','near','效果一般')]),
('推送与控制','PUSH',[('推流','voxpush：TCP 9500','ok','≥160 Mbit/s'),('网页遥控（主机）','voxweb：PC 上的手机页','ok','早期方案'),('网页遥控（板上）','povpair /remote','part','待真手机'),('配对授权','配对码、角色、接管','part','默认未开')]),
('运维工具','OPS',[('遥测','povstat_rx：终端和网页','ok','电脑可用'),('升级','povota：一条命令','ok','自动回滚'),('板端登录','dr1ssh：按网卡认板','ok','量产要关'),('回板流程','一键脚本和验证包','ok','复验 129/0')]),
('云端（规划）','CLOUD',[('设备接入','设备出站连云，不开入站','plan','规划'),('账号与绑定','用户、设备、权限','plan','规划'),('内容库与下发','内容上传、推到设备','plan','V2 首版'),('远程控制','播放、亮度、状态','plan','V2 首版'),('固件分发','OTA 包下发','plan','规划'),('互联网实时推流','跨网低延迟','plan','未排期')])]
hl=''.join(f'<div class="ly"><div class="lyh"><b>{n}</b><small>{en}</small></div><div class="bks">'+''.join(f'<div class="bk st"><span class="bn">{dot(i[2])}{e(i[0])}</span><span class="bs">{e(i[1])}</span><span class="bs2">{e(i[3])}</span></div>' for i in it)+'</div></div>' for n,en,it in H)
b=NAV('host')
b+=sec(1,'架构图','自上而下：用户入口、内容管线、推送与控制、运维工具、云端。云端全部是规划，还没有代码。',f'<div id="lay">{hl}</div>'+LEG)
b+=sec(2,'内容端接口','主机和设备之间现在有这些接口。',table(['接口','方向','内容','状态'],[[f'<b>{a}</b>',c,f2,pill(g)] for a,c,f2,g in [('TCP 9500','电脑 → 设备','PVS1 帧：体素表 + lz4，或位姿帧','ok'),('HTTP 配置页','手机 → 设备热点','WiFi 配置，试连后保存','part'),('HTTP /remote','手机 → 设备','选内容、暂停、亮度','part'),('局域网发现','设备 → 局域网','DNS-SD 服务记录','part'),('遥测','设备 → 电脑','状态、曲线、日志','ok'),('OTA','电脑 → 设备','A/B 槽升级包','ok')]],[170,190,None,110]))
b+=sec(3,'当 3D 显示器用，还差什么','现在内容格式是内部的，推流靠研发命令行。',table(['能力','现状','要做什么'],[[f'<b>{a}</b>',pill(c),f2] for a,c,f2 in [('用户工具','plan','给普通用户的推送工具，或 Blender、Unity 插件，方式待定'),('内容格式','part','公开并冻结体素帧和模型帧格式'),('设备发现和授权','part','手机和 Windows 发现实测，默认开授权'),('带宽自适应','unk','带宽不足时显示原因；降质量可后做'),('多来源切换','ok','第二台主机被拒，管理员可接管')]],[170,110,None]))
b+=sec(4,'互联网推送规划','还没定方案，下面是待定项，不是设计结论。','<div class="cards">'+''.join(f'<div class="cd"><h3>{t}</h3><p>{p}</p></div>' for t,p in [('范围','11-04 定首版只做远程控制和内容下发。是否含实时推流待定。'),('连接方向','设备只主动连云，不在设备上开公网入站端口（建议）。'),('账号','V1 不做账号；V2 要定用户、设备绑定和权限。'),('内容下发','内容先进设备本地，再本地播放，跨网抖动不影响显示（建议）。')])+'</div>')
page('aibrain L2 主机与云端架构',f'L2 主机与云端架构 · 第一版 · {DATE}','这份讲设备以外的部分：内容怎么做出来、怎么推上设备、怎么运维，以及互联网部分的规划。','云端还没开工，规划框不代表已定方案。',b,f'<div><b>依据</b>：host 目录工具、配网与推流工况表、业务架构 v1，截至 {DATE}。</div>'+STATE,'',LINK['host'])
