#!/usr/bin/env python3
"""单颗 ICND2260 (40x45) 的灰阶棋盘格 —— 用来量"帧率涨、色深掉"的代价。

8 列 x 9 行 = 72 格, 每格 5x5 像素, 正好铺满 40x45 (40/8=5, 45/9=5)。
格子按 **行主序** 编号 k = r*8 + c, 值随 k 单调递增
  => 相邻格只差一个台阶, 色深不够时"两格看起来一样"直接肉眼可见。

.mem 格式与 gen_panel_pattern.py 完全一致:
  每行 %012x = 48 bit = {B,G,R}, 每通道 16 bit, **低 16 位 = R**
  地址 = line*40 + px  (单颗, 所以没有 chip*1800 这一项)

⚠ 历史教训: 之前 --flipv 把颜色图例搞乱过。这里**不做图像翻转**,
  而是直接在"硬件地址 -> 物理位置"这一步做一次显式映射, 并在最后打印校验表。
"""
import argparse

PIX, LINES = 40, 45
CCOL, CROW = 8, 9           # 8 列 x 9 行
CW,   CH   = PIX//CCOL, LINES//CROW   # 5 x 5
NCELL = CCOL * CROW         # 72

def levels(mode, n=NCELL):
    if mode == "full":   lo, hi = 0, 0xFFFF
    elif mode == "low":  lo, hi = 0, 0x1FFF      # 只扫底部 1/8, 对丢低位最敏感
    elif mode == "high": lo, hi = 0xE000, 0xFFFF
    else:                lo, hi = 0, 0xFFFF
    if mode == "gamma":  # 感知等间距: v = (k/(n-1))^2.2
        return [int(round(((k/(n-1))**2.2) * 0xFFFF)) for k in range(n)]
    return [lo + int(round(k * (hi-lo) / (n-1))) for k in range(n)]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pattern", default="cells", choices=["cells","rgbstrip","curvetest","depth","rgbdepth","rfull"],
                    help="cells=8x9灰阶棋盘格; rgbstrip=R/G/B/白四条渐变带; curvetest=四条**全白**40级渐变但编码不同(线性/x^2.2/x^0.45/x^4), 用来一次问出芯片的传输曲线到底是哪条")
    ap.add_argument("--mode", default="full", choices=["full","low","high","gamma"])
    ap.add_argument("--chan", default="gray", choices=["gray","r","g","b"],
                    help="gray = R=G=B 一起走台阶; r/g/b = 只让该通道走台阶")
    ap.add_argument("--rot180", action="store_true", help="上下+左右都翻")
    ap.add_argument("--flipv", action="store_true",
                    help="只翻上下。🔴 2026-09-02 实测这块屏是**上下镜像**不是180度旋转: "
                         "定位白点在 --rot180 下落到物理右上角(应在左上角), "
                         "且第一颗出现在物理左下(180度旋转的话该在右下)")
    ap.add_argument("--steps", type=int, default=0,
                    help="把 40 列量化成 N 个离散台阶。0=连续。🔴 连续渐变对相机和眼睛都不友好"
                         "(自动曝光一钳位, 中高段全糊成一片); 离散台阶把判读从'斜率平不平滑'"
                         "变成'能数出几级', 而后者正是要测的量。")
    ap.add_argument("--origin-dot", action="store_true",
                    help="在 0 号格(最暗)的角上点一个满亮像素做定位标记")
    ap.add_argument("--pad-chips", type=int, default=0,
                    help="在图案后面再补 N 颗全黑的块(每颗 1800 字)。"
                         "CASCADE=1 时下游第一颗会把残帧解成雪花并点亮, "
                         "补一颗全黑喂给它就能让整屏只剩第一块 —— 代价只有 2 倍链路带宽。")
    ap.add_argument("--lsb", type=int, default=32,
                    help="rfull 的每级码数。32=11位LSB(覆盖88%%满量程, 但感知上90%%的面积都很亮, "
                         "暗端被挤进最上面几行); **1 = 把整条斜坡压进 0~1799 码(2.7%%满量程)**, "
                         "量化台阶变成可数的色带: 11位->56带 12位->112带 14位->450带 16位->平滑。")
    ap.add_argument("--out", default="rtl/icnd2260_fb_lvds.mem")
    a = ap.parse_args()

    lv = levels(a.mode)
    words = [0]*(PIX*LINES)

    if a.pattern == "rfull":
        # 🔴 用全部 1800 个像素铺满 R 的一整条色深斜坡, 一人一级。
        #    1800 ≈ 2^10.8 ⇒ 11 位(2048 级)最贴合; 像素 i 的值 = i × 32 (32 = 11位的 1 LSB)
        #    i=0 -> 0, i=1799 -> 57,568 (88% 满量程)
        #    读法: 平滑无级 ⇒ 位深 ≥ 11; 看得出并级 ⇒ 数带数 = 实际级数
        #    ⚠ 并级一定先出现在**暗端**(那里量化台阶占比最大), 重点看斜坡起点。
        #    ⚠ 暗室 + 长曝光拍(和测帧率的短曝光相反)。
        LSB = a.lsb
        for line in range(LINES):
            for px in range(PIX):
                prow = (LINES-1-line) if (a.rot180 or a.flipv) else line
                pcol = (PIX  -1-px  ) if a.rot180 else px
                idx  = prow*PIX + pcol            # 光栅序: 0..1799
                v    = min(idx*LSB, 0xFFFF)
                R = v
                if a.origin_dot and prow==0 and pcol==0: R=0xFFFF
                words[line*PIX+px] = R            # 只有 R (低 16 位)
        _write(a, words, lv, f"rfull: R 单通道 1800 级斜坡, 每级 {LSB} 码 (11 位 LSB)")
        return

    if a.pattern == "rgbdepth":
        # 🔴 RGB 色深尺: 3 色 x 3 档步长 = 9 条带, 每条 5 行, 正好 45 行。
        #    每条带 40 列一个斜坡, 步长 1/4/16。
        #    量化台阶在**暗端是相对巨大的**(值 0 与 16 在 12 位下差整整一级 = 亮度差 100%),
        #    所以判据是"哪一档开始出现 40 个分立台阶":
        #      12 位(量化16):  步长1→~3级  步长4→~10级  步长16→40级
        #      14 位(量化 4):  步长1→~10级 步长4→40级   步长16→40级
        #    ⚠ 必须**暗室 + 长曝光**拍(和测帧率时的短曝光相反), 否则底部台阶看不见。
        STEPS=[1,4,16]
        BH=LINES//9                                # 45/9 = 5 行
        for line in range(LINES):
            for px in range(PIX):
                prow = (LINES-1-line) if (a.rot180 or a.flipv) else line
                pcol = (PIX  -1-px  ) if a.rot180 else px
                band=min(prow//BH, 8)
                ch, si = band//3, band%3           # 0=R 1=G 2=B
                v=min(pcol*STEPS[si], 0xFFFF)
                R=G=B=0
                if ch==0: R=v
                elif ch==1: G=v
                else: B=v
                if a.origin_dot and prow==0 and pcol==0: R=G=B=0xFFFF
                words[line*PIX+px]=(B<<32)|(G<<16)|R
        _write(a, words, lv, "rgbdepth: 3色 x 步长1/4/16, 9 条带 x 5 行")
        return

    if a.pattern == "depth":
        # 🔴 色深尺: 45 行切 5 条带, 每条 40 列一个斜坡, **步长逐带 x4**。
        #    哪条带开始能看出 40 个分立台阶, 量化台阶就是那个步长。
        #    12.0 位(量化 16 码) -> 带3 开始清晰; 14.2 位(量化 3.5) -> 带2 就清晰。
        #    为什么不能用 8 级 gamma 台阶: 它最小间距 850 码 >> 16, 一级都不会并, 测不出。
        STEPS=[1,4,16,64,256]
        BH=LINES//len(STEPS)                      # 45/5 = 9 行
        for line in range(LINES):
            for px in range(PIX):
                prow = (LINES-1-line) if (a.rot180 or a.flipv) else line
                pcol = (PIX  -1-px  ) if a.rot180 else px
                b=min(prow//BH, len(STEPS)-1)
                v=min(pcol*STEPS[b], 0xFFFF)
                if a.origin_dot and prow==0 and pcol==0: v=0xFFFF
                words[line*PIX+px]=(v<<32)|(v<<16)|v
        _write(a, words, lv, "depth: 5 条带 x 40 列, 步长 1/4/16/64/256")
        return

    if a.pattern == "curvetest":
        # 四条带都是 40 级全白渐变, 只有编码指数不同。
        # 哪条看起来均匀 => 芯片的传输曲线就是那条的逆。
        # 若四条在照片里一样平 => 是相机钳位, 不是芯片。
        EXPS = [(0,12,1.00), (12,24,2.20), (24,36,0.45), (36,45,4.00)]
        for line in range(LINES):
            for px in range(PIX):
                prow = (LINES-1-line) if (a.rot180 or a.flipv) else line
                pcol = (PIX  -1-px  ) if a.rot180 else px
                x = pcol/(PIX-1)
                v = 0
                for lo,hi,e in EXPS:
                    if lo <= prow < hi:
                        v = int(round((x**e)*0xFFFF)); break
                if a.origin_dot and prow == 0 and pcol == 0: v = 0xFFFF
                words[line*PIX+px] = (v<<32)|(v<<16)|v
        _write(a, words, lv, "curvetest: 4条40级全白渐变 指数 1.0/2.2/0.45/4.0")
        return

    if a.pattern == "rgbstrip":
        # 四条横向渐变带: R(0..11) G(12..23) B(24..35) 白(36..44)
        # 每条从左到右 0 -> 满量程, 40 个台阶。白条三通道一起走, 对丢低位最敏感。
        BANDS = [(0,12,'r'), (12,24,'g'), (24,36,'b'), (36,45,'w')]
        for line in range(LINES):
            for px in range(PIX):
                prow = (LINES-1-line) if (a.rot180 or a.flipv) else line
                pcol = (PIX  -1-px  ) if a.rot180 else px
                if a.steps > 0:                      # 量化成离散台阶
                    k = min(pcol * a.steps // PIX, a.steps-1)
                    x = k / (a.steps - 1)
                else:
                    x = pcol / (PIX-1)
                # gamma 预补偿: LED 是线性 PWM 而人眼约 2.2 次方响应,
                # 线性数值斜坡看起来是"暗端突变、亮端一片平"。取 x^2.2 让人眼看到等间距。
                v = int(round((x**2.2 if a.mode=="gamma" else x) * 0xFFFF))
                R = G = B = 0
                for lo,hi,ch in BANDS:
                    if lo <= prow < hi:
                        if ch=='r': R=v
                        elif ch=='g': G=v
                        elif ch=='b': B=v
                        else: R=G=B=v
                        break
                if a.origin_dot and prow == 0 and pcol == 0: R=G=B=0xFFFF
                words[line*PIX+px] = (B<<32)|(G<<16)|R
        _write(a, words, lv, "rgbstrip: R/G/B/W 四条横向渐变, 每条 40 级")
        return

    for line in range(LINES):
        for px in range(PIX):
            # 硬件地址 -> 物理位置 (唯一一处几何变换, 显式且可校验)
            prow = (LINES-1-line) if (a.rot180 or a.flipv) else line
            pcol = (PIX  -1-px  ) if a.rot180 else px
            r, c = prow//CH, pcol//CW
            k = r*CCOL + c
            v = lv[k]
            if a.chan == "gray": R = G = B = v
            else:
                R = G = B = 0
                if a.chan == "r": R = v
                if a.chan == "g": G = v
                if a.chan == "b": B = v
            if a.origin_dot and prow == 0 and pcol == 0:
                R = G = B = 0xFFFF
            words[line*PIX + px] = (B << 32) | (G << 16) | R

    _write(a, words, lv, f"cells: {CCOL}x{CROW}={NCELL} 格灰阶棋盘格")

def _write(a, words, lv, desc):
    if getattr(a, "pad_chips", 0):
        words = list(words) + [0]*(PIX*LINES*a.pad_chips)
        desc += f" +{a.pad_chips}颗全黑"
    with open(a.out, "w") as f:
        f.write(f"// gen_single_ramp.py {desc} mode={a.mode} chan={a.chan}"
                f"{' rot180' if a.rot180 else ''}{' origin-dot' if a.origin_dot else ''}\n")
        f.write(f"// 单颗 {PIX}x{LINES}, {CCOL}列x{CROW}行 = {NCELL} 格, 每格 {CW}x{CH} 像素\n")
        f.write(f"// 台阶 k=r*{CCOL}+c 行主序递增: lv[0]=0x{lv[0]:04X} .. lv[{NCELL-1}]=0x{lv[-1]:04X}"
                f"  步长约 {lv[1]-lv[0]}\n")
        f.write("// 每行 {B,G,R} 低16位=R; 地址 = line*40 + px\n")
        for w in words: f.write("%012x\n" % w)

    print(f"写出 {a.out}: {len(words)} 字 ({CCOL}x{CROW}={NCELL} 格, 每格 {CW}x{CH})")
    print(f"台阶: lv[0]=0x{lv[0]:04X}  lv[35]=0x{lv[35]:04X}  lv[71]=0x{lv[-1]:04X}  步长≈{lv[1]-lv[0]} (16bit LSB)")
    print("校验 —— 直接从写出的数组里读回, 不是重算:")
    for (ln,p,tag) in [(0,0,"hw 首像素"), (0,PIX-1,"hw 第0行末"),
                       (LINES-1,0,"hw 末行首"), (LINES-1,PIX-1,"hw 末像素"),
                       (22,20,"hw 正中")]:
        w = words[ln*PIX+p]
        print(f"   addr({ln:2d},{p:2d}) {tag:9s} = {w:012x}   R=0x{w&0xFFFF:04X}")

if __name__ == "__main__":
    main()
