#!/usr/bin/env python3
"""derive_eta_wr.py -- regenerate hls/pov_eta_wr.cpp from hls_proj/pov_slice_v2.cpp.

Only two mechanical edits: top name -> pov_eta_wr, return pragma -> ap_ctrl_hs.
Run again whenever pov_slice_v2.cpp changes, so the 'as-is IP' gauge never drifts
from the real IP. Exit code 1 if the master source no longer matches expectations.
"""
import os, sys
here = os.path.dirname(os.path.abspath(__file__))
root = os.path.normpath(os.path.join(here, '..'))
master = os.path.join(root, '..', 'hls_proj', 'pov_slice_v2.cpp')
out = os.path.join(root, 'hls', 'pov_eta_wr.cpp')
src = open(master, encoding='utf-8').read()
hdr = '''/* pov_eta_wr.cpp — pov_slice_v2 的「原样 (读+写) + 引脚级启停」变体, 供 η 实测的第二组对照
 *
 * 与 zynq_pov/hls_proj/pov_slice_v2.cpp 的差别只有两处 (其余逐字相同, 由脚本自动派生):
 *   - 顶层函数名 pov_slice_v2 -> pov_eta_wr
 *   - `#pragma HLS INTERFACE s_axilite port=return` -> `ap_ctrl_hs port=return`
 *     ⇒ ap_start/ap_done/ap_idle 成为引脚, 由 eta_mon.v 启停/计数 (见 pov_eta_rd.cpp 注释③)
 * 用途: 昨天判据的字面版本 (现有 IP 两实例并发, 读+写都落 DDR) —— 若它也过, 是更强的 GO;
 *       若它不过而 pov_eta_rd 过, 说明差的是写流, 与「切片不落 DDR」拓扑无关。
 * 派生命令 (勿手改本文件): python3 tools/derive_eta_wr.py
 */
'''
if '#include "pov_slice_v2.h"' not in src:
    sys.exit("master source lacks the expected include")
body = '#include "pov_slice_v2.h"' + src.split('#include "pov_slice_v2.h"', 1)[1]
if body.count('void pov_slice_v2(') != 1:
    sys.exit("expected exactly one top 'void pov_slice_v2('")
body = body.replace('void pov_slice_v2(', 'void pov_eta_wr(')
ret = '#pragma HLS INTERFACE s_axilite port=return      bundle=control'
if body.count(ret) != 1:
    sys.exit("expected exactly one s_axilite return pragma; master changed, update this script")
body = body.replace(ret, '#pragma HLS INTERFACE ap_ctrl_hs port=return')
open(out, 'w', encoding='utf-8').write(hdr + body)
print("wrote", out)
