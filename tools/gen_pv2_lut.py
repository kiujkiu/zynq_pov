#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen_pv2_lut.py — 生成 pov_slice_v2 的 Q8 角度表 hls_proj/pov_slice_v2_lut_<N>.h

表值 = round(256·cos(2πi/N)) / round(256·sin(2πi/N)), 与 gen_pv2_golden.py /
scatter/check_slice_ref.py 的 q8_lut() 同一公式。

用法:
  python3 tools/gen_pv2_lut.py 358            # 验证板 (2026-10-10 定: 24 Hz / 720 RPM / 358 片)
  python3 tools/gen_pv2_lut.py --check 360 603  # 重新生成到内存, 与仓库里的现表逐字节比

2026-10-10 补写: 现表 (360/603) 的头注释一直写"由 tools/gen_pv2_lut.py 生成",
但脚本本身从没入库。本脚本对 360/603 的输出与现表逐字节相同 (--check 验证)。
"""
import argparse
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
HLS = os.path.join(HERE, '..', 'hls_proj')
PER_LINE = 12


def q8(n):
    cos8 = [int(round(256 * math.cos(2 * math.pi * i / n))) for i in range(n)]
    sin8 = [int(round(256 * math.sin(2 * math.pi * i / n))) for i in range(n)]
    return cos8, sin8


def body(name, vals):
    out = [f'static const int16_t {name}[{len(vals)}] = {{']
    for i in range(0, len(vals), PER_LINE):
        out.append('   ' + ','.join(f'{v:6d}' for v in vals[i:i + PER_LINE]) + ',')
    out.append('};')
    return '\n'.join(out)


def render(n):
    cos8, sin8 = q8(n)
    g = f'POV_SLICE_V2_LUT_{n}_H'
    return (f'/* pov_slice_v2_lut_{n}.h — {n} 档角度 Q8 定点 cos/sin (脚本生成, 勿手改)\n'
            f' * 生成: tools/gen_pv2_lut.py   由最外圈像素间距定切片数, '
            f'见 memory project_pov3d_final_target */\n'
            f'#ifndef {g}\n#define {g}\n#include <stdint.h>\n\n'
            f'{body("PV2_COS8", cos8)}\n\n{body("PV2_SIN8", sin8)}\n\n#endif\n')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('n', type=int, nargs='+')
    ap.add_argument('--check', action='store_true',
                    help='不写文件, 与 hls_proj 里已有的表逐字节比')
    a = ap.parse_args()
    bad = 0
    for n in a.n:
        path = os.path.join(HLS, f'pov_slice_v2_lut_{n}.h')
        txt = render(n)
        if a.check:
            old = open(path, encoding='utf-8').read()
            same = old == txt
            bad += not same
            print(f'{os.path.basename(path)}: {"逐字节相同" if same else "✗ 不同"}')
        else:
            with open(path, 'w', encoding='utf-8', newline='\n') as f:
                f.write(txt)
            print(f'写出 {path}')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
