// 数据自检: 引用存在、GAP 齐全、步骤状态不虚高、无 Soulog 残留
const fs=require('fs'),vm=require('vm');
const src=fs.readFileSync(__dirname+'/data.js','utf8')+'\n;({S,SP,STAGES,CORES,SUPS,GAP,PLAN,FOCUS,SPRINT1,SPRINT2,SPRINT2_HW,SUBMARK,CASE_TODO,CARRIER,PROD,AI,AI_LV,LINES,SUP_LINE,REQ,HIRE_DEF})';
const D=vm.runInNewContext(src);let bad=0;const e=m=>{console.log('ERR',m);bad++};
const steps={};D.STAGES.forEach(g=>g.t.forEach(s=>{if(steps[s[0]])e('重复步骤 '+s[0]);steps[s[0]]=s;if(!(s[3] in D.S))e('状态 '+s[0]);if(!D.CARRIER[s[0]])e('无载体 '+s[0]);if(!s[5].length&&!s[6])e('无类型 '+s[0])}));
const subs={};D.CORES.forEach(G=>{if(!steps[G.step])e('缺步骤 '+G.step);G.t.forEach(c=>{if(subs[c[0]])e('重复子任务 '+c[0]);subs[c[0]]=c;if(!(c[3] in D.S))e('状态 '+c[0]);if(c[3]!=='ok'&&!D.GAP[c[0]]&&c[3]!=='unk')e('缺 GAP '+c[0]);if(c[3]==='ok'&&D.GAP[c[0]])e('达标却有 GAP '+c[0])});
 const w=G.t.filter(c=>c[3]!=='ok');if(steps[G.step]&&steps[G.step][3]==='ok'&&w.length)e('步骤虚高 '+G.step+': '+w.map(c=>c[1]))});
Object.keys(steps).forEach(s=>{if(!D.CORES.some(G=>G.step===s))e('无子任务 '+s);if(steps[s][3]!=='ok'&&!D.PLAN[s]&&!['s_unbox','s_place','s_safe','s_game'].includes(s))console.log('提示 无验收 '+s)});
D.SUPS.forEach(G=>{if(!G||!D.LINES.some(l=>l.k===G.line))e('线 '+(G&&G.code));if(!D.SUP_LINE[G.code])e('SUP_LINE '+G.code);if(!G.aido||!G.hudo||!G.role)e('分工 '+G.code);if(!D.HIRE_DEF[G.hire])e('建议 '+G.code);if(/V[0-9]/.test(G.g+G.s))e('组名含版本 '+G.code)});
D.SUPS.forEach(G=>G.t.forEach(u=>{if(!D.REQ[u[0]])e('缺招聘要求 '+u[0]);if(/\bV[0-9]/.test(u[1]+u[2]+u[6]))e('能力名含版本 '+u[0])}));
D.SUPS.forEach(G=>G.t.forEach(u=>{if(!D.AI_LV[D.AI[u[0]]])e('AI 分级 '+u[0]);if(!(u[3] in D.S))e('状态 '+u[0]);u[7].forEach(s=>{if(!steps[s])e('支撑引用 '+u[0]+'→'+s)})}));
for(const[n,o]of[['FOCUS',D.FOCUS],['SPRINT1',D.SPRINT1],['SPRINT2',D.SPRINT2],['SPRINT2_HW',D.SPRINT2_HW],['CASE_TODO',D.CASE_TODO]])Object.keys(o).forEach(k=>{if(!steps[k])e(n+' '+k)});
Object.keys(D.SUBMARK).forEach(k=>{if(!subs[k])e('SUBMARK '+k)});Object.keys(D.GAP).forEach(k=>{if(!subs[k])e('GAP 孤儿 '+k)});
Object.keys(D.PROD).forEach(k=>{if(!steps[k]&&!subs[k])e('PROD '+k)});
const c={};Object.values(subs).forEach(x=>c[x[3]]=(c[x[3]]||0)+1);
console.log('步骤',Object.keys(steps).length,'子任务',Object.keys(subs).length,c,'错误',bad);process.exit(bad?1:0);
