#!/usr/bin/env python3
"""从供应商给的 xlsx 导出寄存器表 -> rtl/icnd2260_regs_vendor.mem

来源: 供应商(映己鸿鹄)提供的 2260lvds.xlsx —— 他们**实际点亮这块 40x45 样板**用的配置。
两列: reg_num (十进制 0..237) / reg_data (0xNNNN)。

这份是「已知能工作」的参照物, 优先级高于我们从手册 §11 反推的那份:
  - 手册 §11 那张表原文写明是 **TTL-3 通道** 的默认值, 不是 LVDS 的
  - 我们靠 §3 传输模式表自行推断 0x06[9]/0x1a[9] 置 1 来切 LVDS —— 本文件证实推断正确
  - 但另外还有 46 处差异是我们无从推断的 (电流/时序/扫描参数, 与这块板的 LED 特性绑定)

跑法: python3 tools/import_vendor_regs.py [xlsx路径]
"""
import zipfile, re, html, sys, os

DEFAULT_XLSX = "/mnt/c/Users/wanqi.liu/Documents/xwechat_files/wxid_ebm7chfacn7c21_e95f/msg/file/2026-08/2260lvds.xlsx"
REG_COUNT = 238          # 必须与 rtl/icnd2260_seq.v 的 REG_COUNT 一致
DEPTH     = 256          # reg_rom 深度

def read_xlsx(path):
    z = zipfile.ZipFile(path)
    d = z.read('xl/sharedStrings.xml').decode('utf-8')
    ss = [html.unescape(''.join(re.findall(r'<x:t[^>]*>(.*?)</x:t>', m.group(1), re.S)))
          for m in re.finditer(r'<x:si>(.*?)</x:si>', d, re.S)]
    s = z.read('xl/worksheets/sheet.xml').decode('utf-8')
    tbl = {}
    for _rn, body in re.findall(r'<x:row r="(\d+)"[^>]*>(.*?)</x:row>', s, re.S):
        c = {}
        for m in re.finditer(r'<x:c r="([A-Z]+)\d+"([^>]*)>(.*?)</x:c>', body, re.S):
            col, attr, inner = m.groups()
            v = re.search(r'<x:v>(.*?)</x:v>', inner, re.S)
            if v:
                c[col] = ss[int(v.group(1))] if 't="s"' in attr else v.group(1)
        a, b = c.get('A', ''), c.get('B', '')
        if a.isdigit() and b.lower().startswith('0x'):
            tbl[int(a)] = int(b, 16)
    return tbl

def main():
    xlsx = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_XLSX
    tbl = read_xlsx(xlsx)

    # ---- 自校验: 这份表必须真的是 mini-LVDS 配置, 否则白忙 ----
    miss = [a for a in range(REG_COUNT) if a not in tbl]
    assert not miss, f"缺寄存器 {miss[:8]}... (共 {len(miss)} 个)"
    assert max(tbl) == REG_COUNT - 1, f"最大地址 {max(tbl)}, 期望 {REG_COUNT-1}"
    assert (tbl[0x06] >> 9) & 1 == 1, f"0x06[9]=0 -> 这不是 LVDS 配置 (0x06={tbl[0x06]:04x})"
    assert (tbl[0x1a] >> 9) & 1 == 1, f"0x1a[9]=0 -> 这不是 LVDS 配置 (0x1a={tbl[0x1a]:04x})"
    ch = (tbl[0xb4] >> 4) & 3
    assert ch == 0b10, f"0xb4[5:4]={ch:02b}, 期望 10 (3 通道)"
    grp = ((tbl[0x00] >> 8) & 0x7f) + 1
    assert grp >= 16, f"刷新分组数 {grp} < 16, 违反手册要求"

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "rtl", "icnd2260_regs_vendor.mem")
    with open(out, "w") as f:
        f.write("// 由 tools/import_vendor_regs.py 生成, 勿手改\n")
        f.write(f"// 源: 供应商提供的 {os.path.basename(xlsx)} —— 实测能点亮本样板的 mini-LVDS 配置\n")
        f.write(f"// 0x06[9]={(tbl[0x06]>>9)&1} 0x1a[9]={(tbl[0x1a]>>9)&1} (LVDS 使能), "
                f"0xb4[5:4]={ch:02b} (3 通道), 灰度分组数={grp}\n")
        f.write(f"// 有效范围 0x00..0x{REG_COUNT-1:02X} ({REG_COUNT} 个), 其余补 0 只为凑满 {DEPTH} 深度\n")
        for a in range(DEPTH):
            v = tbl.get(a, 0)
            f.write(f"{v:04x}   // 0x{a:02x}\n")
    print(f"写出 {out}")

    # ---- 帧率估算 (§1: 帧频 = GCLK / (灰度等级 x 扫描数)) ----
    n  = 1 << ((tbl[0x00] >> 4) & 3)
    wx = tbl[0x01] & 0x1fff
    G  = grp * wx * n
    print(f"灰度: 分组数={grp} x Width_X={wx} x N={n} = G={G}")
    for scan in (45, 48):
        print(f"  扫描数 {scan}: 帧频 <= 600MHz/({G}x{scan}) = {600e6/(G*scan):.0f} fps")

if __name__ == "__main__":
    main()
