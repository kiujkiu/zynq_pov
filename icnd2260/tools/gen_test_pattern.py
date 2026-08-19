#!/usr/bin/env python3
"""
gen_test_pattern.py -- 生成 ICND2260 帧缓存初值 (.mem)

单颗 ICND2260 = 40 像素 x 48 扫描行。每像素 3 色 x 16 bit,
帧缓存一条的字序取决于**哪一路是「第一通道」**, 而 TTL 与 mini-LVDS 不一样:

  手册 §3「传输模式」表的「寄存器配置」列:
    TTL  1/2/3/6 通道 → 一律 SDI_R1   ⇒ 第一通道 = R
    mLVDS 1/2/3 通道  → 一律 D0IP/N   ⇒ 第一通道 = D0 = SDI_B1 = **B**

  而「第一通道」除了发配置, 还独家发 VHEAD ⇒ 它必须是 tx 的 lane0。
  ⇒ TTL  模式: 一条 = {B, G, R}, 低 16 位 = R
  ⇒ LVDS 模式: 一条 = {R, G, B}, 低 16 位 = B
  ⚠ 搞反了不会报错, 只会红蓝对调 —— 首光看到颜色不对先查这里。
地址 = line * PIX + px, 与《编程指导》§5「先第一行、每行先第一个像素」一致。

⚠ 首次点亮请用低电流: 默认把满量程压到 1/16 (SCALE)。
   芯片实际灰度只有 10 bit (线上位宽固定 16 bit), 低位是白付的, 见 docs。

用法:
  python3 tools/gen_test_pattern.py                 # 默认 gradient
  python3 tools/gen_test_pattern.py --mode single   # 只点第 0 行第 0 个像素的红
  python3 tools/gen_test_pattern.py --mode cross --scale 32
  python3 tools/gen_test_pattern.py --iface lvds --mode single   # LVDS 用的字序
"""
import argparse
import os

PIX = 40
LINES = 48


def clamp16(v):
    return max(0, min(0xFFFF, int(v)))


def gen(mode, scale, cascade):
    """返回 [(r,g,b)] 列表, 长度 = PIX*LINES*cascade"""
    out = []
    full = 0xFFFF // scale
    for chip in range(cascade):
        for ln in range(LINES):
            for px in range(PIX):
                r = g = b = 0
                if mode == "off":
                    pass
                elif mode == "single":
                    if ln == 0 and px == 0 and chip == 0:
                        r = full
                elif mode == "cross":
                    if ln == LINES // 2 or px == PIX // 2:
                        r = g = b = full
                    if ln == 0 or ln == LINES - 1 or px == 0 or px == PIX - 1:
                        b = full
                elif mode == "gradient":
                    r = full * px // (PIX - 1)
                    g = full * ln // (LINES - 1)
                    b = full if (ln == 0 or px == 0) else 0      # 原点标记, 用来定方向
                    if ln < 2 and px < 2:
                        r = g = b = full                          # 左上角白块
                else:
                    raise SystemExit(f"未知 mode {mode}")
                out.append((clamp16(r), clamp16(g), clamp16(b)))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", default="gradient",
                    choices=["gradient", "single", "cross", "off"])
    ap.add_argument("--scale", type=int, default=16,
                    help="满量程的 1/scale, 首光别调小 (电流)")
    ap.add_argument("--cascade", type=int, default=1)
    ap.add_argument("--iface", dest="iface", default="ttl", choices=["ttl", "lvds"],
                    help="ttl: 低16位=R;  lvds: 低16位=B (见文件头说明)")
    ap.add_argument("--out", default=None)
    a = ap.parse_args()

    root = os.path.join(os.path.dirname(__file__), "..")
    dflt = "icnd2260_fb.mem" if a.iface == "ttl" else "icnd2260_fb_lvds.mem"
    out = a.out or os.path.join(root, "rtl", dflt)
    px = gen(a.mode, a.scale, a.cascade)

    with open(out, "w") as f:
        f.write(f"// 由 tools/gen_test_pattern.py 生成: mode={a.mode} scale=1/{a.scale} "
                f"cascade={a.cascade} iface={a.iface}\n")
        lay = "{B,G,R} 低16位=R" if a.iface == "ttl" else "{R,G,B} 低16位=B (第一通道 D0=B)"
        f.write(f"// 每行 = {lay}, 地址 = line*40 + px\n")
        for i, (r, g, b) in enumerate(px):
            ln, p = divmod(i % (PIX * LINES), PIX)
            w = f"{b:04x}{g:04x}{r:04x}" if a.iface == "ttl" else f"{r:04x}{g:04x}{b:04x}"
            f.write(f"{w}   // line {ln:2d} px {p:2d}\n")

    lit = sum(1 for r, g, b in px if r or g or b)
    print(f"OK  {len(px)} px -> {out}   (非零像素 {lit})")


if __name__ == "__main__":
    main()
