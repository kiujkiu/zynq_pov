#!/usr/bin/env python3
"""按 1 m 观看距离倒算清晰度、数据量、亮度和仰视遮挡 (第 04 节的数字来源)。"""
import math
D=1000.0; R=75.0; H=168.75; W=150.0
am=lambda mm: math.degrees(math.atan(mm/D))*60
print('显示体张角 %.1f° x %.1f°'%(2*math.degrees(math.atan(R/D)),2*math.degrees(math.atan(H/2/D))))
for n,p,S,rps in [('V1',0.9375,357,12),('V2',0.78125,605,15)]:
    t=2*math.pi*R/S
    print(n,'径向 %.2f mm %.2f′ 切向 %.2f mm %.2f′ 片时 %.0f us 视力当量 %.2f/%.2f'%(p,am(p),t,am(t),1e6/(S*rps),1/am(p),1/am(t)))
print('--- 档位')
base=16e9
for n,p in [('及格 1.0 mm',1.0),('好 2′',D*math.tan(math.radians(2/60))),('极限 1′',D*math.tan(math.radians(1/60)))]:
    px,py,S=W/p,H/p,2*math.pi*R/p
    g=px*py*S*15*36
    print(n,'p=%.2f'%p,'%.0f x %.0f, %.0f 片/圈, 每面 %.1f Gbit/s (15 rps,36 bit), 是 V2 13.5G 的 %.1f 倍'%(px,py,S,g/1e9,g/(192*216*605*15*36)))
print('V2 每面 %.1f Gbit/s'%(192*216*605*15*36/1e9))
print('--- 亮度: 感知 = 面板亮度 x 2N/S, N=视线上点亮的体素数')
L0=600
for n,S in [('V1',357),('V2',605)]:
    for N in (2,10,30): print(n,'N=%d 感知 %.1f nits'%(N,L0*2*N/S))
print('--- 室内黑底: 300/500 lux, 反射 5%')
for E,rho in [(300,.05),(500,.05),(300,.02)]:
    Lb=E*rho/math.pi
    print('E=%d rho=%.2f 黑底 %.1f nits, 10:1 需 %.0f nits, 5:1 需 %.0f nits'%(E,rho,Lb,9*Lb,4*Lb))
Lb=300*.05/math.pi; need=9*Lb
for n,S in [('V1',357),('V2',605)]:
    for N in (2,10): print(n,'N=%d 10:1 需面板 %.0f nits (规格 %.1f 倍)'%(N,need*S/(2*N),need*S/(2*N)/L0))
T=.5
print('灰罩 T=0.5: 黑底 %.1f, 10:1 需罩内 %.1f nits'%(Lb*T*T,9*Lb*T*T/T))
print('规格满白 %.1f W (两面 335 W/m2)'%(335*2*W*H/1e6))
print('--- 仰视 -20°: 转子底板扫过半径 %.1f mm, 屏下 9 mm'%math.hypot(70,40))
r=math.hypot(70,40); t=math.tan(math.radians(20))
for x,name in [(0,'轴心'),(-75,'远侧边'),(75,'近侧边')]:
    print(name,'下沿被挡 %.0f mm'%max(0,(r-x)*t-9))
for f in (30,40,60): print('%d Hz 需 %d rpm'%(f,f/2*60))
