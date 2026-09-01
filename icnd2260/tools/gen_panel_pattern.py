#!/usr/bin/env python3
"""
gen_panel_pattern.py -- 按**面板真实几何**生成 ICND2260 帧缓存 (.mem)

面板 120x135 = 3x3 颗, 每颗 40x45。链序从左上角起**横向 S 型**:

      chip0 → chip1 → chip2          (第 0 行, 左→右)
                        ↓
      chip5 ← chip4 ← chip3          (第 1 行, 右→左)
        ↓
      chip6 → chip7 → chip8          (第 2 行, 左→右)

⚠ 假设每颗芯片自己的 40x45 区域**朝向一致**(9 颗在同一块板上, S 型只是数据链的走法,
  不是模组翻转)。若实测发现隔行镜像, 加 --flip-odd-row。

🔴 字序 **{B,G,R}, 低 16 位 = R** —— 2026-09-01 首光实测定的:
   数字棋盘格里"我生成蓝、屏上显示红 / 我生成红、屏上显示蓝", 绿不变 ⇒ 红蓝对调。
   也就是说 **lane0(D0) 实际驱动的是 R**, 不是我们之前从引脚名 SDI_B1 推的 B。
   (引脚表里 F1 叫 `SDI_B1/L_D0IP` —— TTL 的通道名不代表 mLVDS 的颜色映射。)
地址 = chip*1800 + line*40 + px, 与《编程指导》§5「先第一颗、每颗先第一行、每行先第一个像素」一致。

用法:
  python3 tools/gen_panel_pattern.py --mode chipnum          # 数字棋盘格(点屏第 2 步)
  python3 tools/gen_panel_pattern.py --mode solid --color w
  python3 tools/gen_panel_pattern.py --mode chipnum --rot180 # 屏physically 装反时
"""
import argparse

PIX, LINES = 40, 45
TCOL, TROW = 3, 3
W, H = PIX * TCOL, LINES * TROW          # 120 x 135
CASCADE = TCOL * TROW

FONT = {  # 3x5, 用 1..9 (面向人的编号, 链上第 1 颗 = 1)
 '1': ["010", "110", "010", "010", "111"],
 '2': ["111", "001", "111", "100", "111"],
 '3': ["111", "001", "111", "001", "111"],
 '4': ["101", "101", "111", "001", "001"],
 '5': ["111", "100", "111", "001", "111"],
 '6': ["111", "100", "111", "101", "111"],
 '7': ["111", "001", "001", "001", "001"],
 '8': ["111", "101", "111", "101", "111"],
 '9': ["111", "101", "111", "001", "111"],
}


def chip_of(tc, tr):
    """(贴片列, 贴片行) -> 链上第几颗 (0 基)。横向 S 型。"""
    return tr * TCOL + (tc if (tr % 2 == 0) else (TCOL - 1 - tc))


def build(mode, full, color):
    """返回 img[y][x] = (r,g,b), 面板坐标系, 原点在左上"""
    img = [[(0, 0, 0)] * W for _ in range(H)]
    dim = max(1, full // 6)
    if mode == "solid":
        c = {"r": (full, 0, 0), "g": (0, full, 0), "b": (0, 0, full),
             "w": (full, full, full)}[color]
        for y in range(H):
            for x in range(W):
                img[y][x] = c
        return img
    if mode == "rgbbars":
        for y in range(H):
            for x in range(W):
                img[y][x] = [(full, 0, 0), (0, full, 0), (0, 0, full)][x * 3 // W]
        return img

    # ---- chipcolor: 每颗一个纯色, 一眼能读出链序 ----
    #   1红 2绿 3蓝 4黄 5青 6品红 7白 8橙 9深紫
    #   每颗左上角挖一个 3x3 黑洞做朝向标记(纯色底上挖黑最好认)
    if mode == "chipcolor":
        half = full // 3
        PAL = [(full, 0, 0), (0, full, 0), (0, 0, full),
               (full, full, 0), (0, full, full), (full, 0, full),
               (full, full, full), (full, half, 0), (half, 0, full)]
        for tr in range(TROW):
            for tc in range(TCOL):
                n = chip_of(tc, tr)
                ox, oy = tc * PIX, tr * LINES
                for ly in range(LINES):
                    for lx in range(PIX):
                        img[oy + ly][ox + lx] = PAL[n]
                for ly in range(3):
                    for lx in range(3):
                        img[oy + ly][ox + lx] = (0, 0, 0)
        return img

    # ---- chipnum: 棋盘底 + 每颗的编号 + 每颗左上角的红色朝向标记 ----
    for tr in range(TROW):
        for tc in range(TCOL):
            n = chip_of(tc, tr)
            ox, oy = tc * PIX, tr * LINES
            for ly in range(LINES):
                for lx in range(PIX):
                    # 棋盘底: 5x5 一格, 暗蓝
                    on = ((lx // 5) + (ly // 5)) % 2 == 0
                    img[oy + ly][ox + lx] = (0, 0, dim) if on else (0, 0, 0)
            # 1 像素白边框 = 贴片边界
            for lx in range(PIX):
                img[oy][ox + lx] = img[oy + LINES - 1][ox + lx] = (dim, dim, dim)
            for ly in range(LINES):
                img[oy + ly][ox] = img[oy + ly][ox + PIX - 1] = (dim, dim, dim)
            # 左上角 3x3 红块 = 每颗自己的原点/朝向
            for ly in range(3):
                for lx in range(3):
                    img[oy + ly][ox + lx] = (full, 0, 0)
            # 居中的编号 (1 基), 绿色, 3x5 字模放大 6 倍 = 18x30
            gl = FONT[str(n + 1)]
            sx, sy, S = ox + (PIX - 18) // 2, oy + (LINES - 30) // 2, 6
            for r in range(5):
                for c in range(3):
                    if gl[r][c] == '1':
                        for dy in range(S):
                            for dx in range(S):
                                img[sy + r * S + dy][sx + c * S + dx] = (0, full, 0)
    return img


def main():
    global LINES, H
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", default="chipnum",
                    choices=["chipnum", "chipcolor", "solid", "rgbbars"])
    ap.add_argument("--color", default="w", choices=["r", "g", "b", "w"])
    ap.add_argument("--scale", type=int, default=16, help="满量程的 1/scale, 首光别拉满")
    ap.add_argument("--rot180", action="store_true", help="上下+左右都翻 (= --flipv --fliph)")
    ap.add_argument("--flipv", action="store_true", help="只翻上下")
    ap.add_argument("--fliph", action="store_true", help="只翻左右")
    ap.add_argument("--flip-odd-row", action="store_true",
                    help="若实测发现 S 型隔行是镜像的, 打开这个")
    ap.add_argument("--lines", type=int, default=LINES,
                    help="每颗发多少行 (45 = 面板真实行数; 48 = 芯片满行数 40x48=1920 字)")
    ap.add_argument("-o", "--out", default="rtl/icnd2260_fb_lvds.mem")
    a = ap.parse_args()
    LINES = a.lines            # 每颗发多少行 (45=面板真实行数, 48=芯片满行数)
    H = LINES * TROW

    full = 0xFFFF // a.scale
    img = build(a.mode, full, a.color)
    # 2026-09-01 实测: 屏物理上下颠倒, 但左右本来就是对的(两个水平翻转互相抵消)
    #   ⇒ 正确的补偿是 **只翻上下**。判据: 每颗左上角的红色 3x3 原点标记应出现在左上角。
    fv = a.flipv or a.rot180
    fh = a.fliph or a.rot180
    if fv:
        img = img[::-1]
    if fh:
        img = [row[::-1] for row in img]

    # 🔴 chipcolor 直接按**链序**写字, 完全绕开图像与翻转 ——
    #    2026-09-01 踩过: 先翻图再映射会把"颜色↔链序"的对应打乱, 色标就是错的。
    if a.mode == "chipcolor":
        half = full // 3
        PAL = [(full,0,0),(0,full,0),(0,0,full),(full,full,0),(0,full,full),
               (full,0,full),(full,full,full),(full,half,0),(half,0,full)]
        words = []
        for ch in range(CASCADE):
            r,g,b = PAL[ch % 9]
            for ly in range(LINES):
                for lx in range(PIX):
                    v = 0 if (ly < 3 and lx < 3) else ((b<<32)|(g<<16)|r)
                    words.append(v)
        with open(a.out,"w") as f:
            f.write(f"// gen_panel_pattern.py mode=chipcolor scale=1/{a.scale} "
                    f"cascade={CASCADE}  **按链序上色, 与翻转无关**\n")
            f.write("// 1红 2绿 3蓝 4黄 5青 6品红 7白 8橙 9紫; 每颗左上角 3x3 黑洞 = 该颗原点\n")
            for w in words: f.write("%012x\n" % w)
        print(f"写入 {a.out}: {len(words)} 条, {CASCADE} 颗, 色标 = 链序")
        return

    words = [0] * (CASCADE * LINES * PIX)
    for y in range(H):
        for x in range(W):
            tc, tr = x // PIX, y // LINES
            lx, ly = x % PIX, y % LINES
            if a.flip_odd_row and tr % 2 == 1:
                lx, ly = PIX - 1 - lx, LINES - 1 - ly
            ch = chip_of(tc, tr)
            r, g, b = img[y][x]
            words[ch * LINES * PIX + ly * PIX + lx] = (b << 32) | (g << 16) | r

    with open(a.out, "w") as f:
        f.write(f"// gen_panel_pattern.py mode={a.mode} scale=1/{a.scale} "
                f"flipv={fv} fliph={fh} flip_odd_row={a.flip_odd_row}\n")
        f.write(f"// 面板 {W}x{H} = {TCOL}x{TROW} 颗 x {PIX}x{LINES}, 横向 S 型链序\n")
        f.write("// 每行 = {B,G,R} 低16位=R (2026-09-01 实测: lane0=R); 地址 = chip*1800 + line*40 + px\n")
        for w in words:
            f.write("%012x\n" % w)
    print(f"写入 {a.out}: {len(words)} 条 (= {CASCADE} 颗 x {LINES} 行 x {PIX} 像素)")
    print("链序 (贴片行, 列) -> 链上第几颗(1 基):")
    for tr in range(TROW):
        print("   " + "  ".join(f"[{tc},{tr}]={chip_of(tc,tr)+1}" for tc in range(TCOL)))


if __name__ == "__main__":
    main()
