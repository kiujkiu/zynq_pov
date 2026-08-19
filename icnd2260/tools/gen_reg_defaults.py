#!/usr/bin/env python3
"""
gen_reg_defaults.py -- 生成 ICND2260 上电寄存器默认表 (TTL / mini-LVDS 两种)

数据源: 《ICND2260 编程指导 CN 2025 V2.8》第 31 页 §11「寄存器」表
        (原文只有一张图, 手册正文写明「该配置为 TTL-3 通道模式」)

自校验: 0xb4[5:4] 必须 = 2'b10 (TTL 3 通道), 0x06[9] / 0x1a[9] 必须 = 0 (TTL)
        —— 与 §3「传输模式」表的 TTL-3 通道行一致, 对不上说明表抄错了。

输出:
  rtl/icnd2260_regs.mem   $readmemh 用, 256 行 (0xEE..0xFF 补 0)
  sw/icnd2260_regs.h      PS 侧 C 数组

用法:
  python3 tools/gen_reg_defaults.py            # 两种模式的表都生成
"""
import sys
import os

# ---- §11 表格逐行照抄 (行 = 高 4 位, 列 = 低 4 位 0x0..0xf) -------------------
ROWS = {
    0x00: "3f3c 0020 0c00 003c 2d2d 1000 d088 19a0 5105 ffff ffff 0000 0000 0000 0000 0000",
    0x10: "0000 0000 ffff ffff ffff 0027 f81b 0900 0034 0508 0848 0188 0000 0000 0000 0000",
    0x20: "6020 1000 0006 0100 01cf 0f00 0000 0040 0020 01d5 0806 011f 000d 2218 2000 0000",
    0x30: "6020 1000 0006 0100 01cf 0f00 0000 0040 0020 01d5 0b0b 011f 0019 221f 2000 0000",
    0x40: "6020 1000 0006 0100 01cf 0f00 0000 0040 0020 01d5 0e0d 011f 001d 2219 2000 0000",
    0x50: "0a00 0c00 0000 0000 0000 ffff 4140 4141 ffff 1404 a47b 0000 0000 0000 0000 0000",
    0x60: "0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 004d 004d 0000 0000",
    0x70: "0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 000b 0000 0054 0054 0000 0000",
    0x80: "0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0060 0060 0000 0000",
    0x90: "0000 0000 0000 0000 0000 0000 0000 0000 0000 22ac 0000 0000 0000 0000 0000 0000",
    0xa0: "0000 0000 0000 0000 0000 0000 a5a5 1842 5a5a 2184 a5a5 4218 5a5a 8421 0000 0000",
    0xb0: "0070 1155 2804 3100 3028 0054 0021 0000 0000 0000 0000 0000 0000 0000 0000 0000",
    0xc0: "0000 0040 0000 0000 0020 0010 0010 0010 003f 0020 0020 0020 0000 0000 0000 0000",
    0xd0: "8888 8888 8888 8888 8888 8888 8888 8888 8888 8888 8888 8888 8888 8888 8888 8888",
    # 0xeX 只到 0xED, 手册表格 0xEE/0xEF 两格是空的 —— 不是 0, 是「不存在」
    0xe0: "8888 8888 8888 8888 8888 8888 8888 8888 8888 8888 8888 8888 8888 8888",
}

# 手册 §11 表格最后一个有效寄存器 (0xEE/0xEF 空白, 不发)
REG_LAST = 0xED
REG_COUNT = REG_LAST + 1          # 238

# §12 上电配置建议: 头两遍整表要屏蔽这两位
POWERON_MASK = {0x00: (1 << 3), 0x15: (1 << 5)}

# §3「传输模式」表: 手册 §11 给的默认值是 TTL-3 通道, 走 mini-LVDS 要改这两位。
# 0xb4[5:4]=10 (3 通道) 两种模式共用, 默认表里已经是 10, 不用动。
LVDS_SET = {0x06: (1 << 9), 0x1a: (1 << 9)}

# 0xb4[5:4] = 通道数: 00=1 通道, 01=2 通道, 10=3 通道, 11=6 通道(仅 TTL)
CH_CODE = {1: 0b00, 2: 0b01, 3: 0b10, 6: 0b11}


def set_channels(regs, n):
    r = list(regs)
    r[0xb4] = (r[0xb4] & ~0x0030) | (CH_CODE[n] << 4)
    return r


def build():
    regs = [0] * 256
    seen = set()
    for base, line in ROWS.items():
        vals = line.split()
        for i, v in enumerate(vals):
            addr = base + i
            assert addr not in seen, f"地址 0x{addr:02x} 重复"
            seen.add(addr)
            regs[addr] = int(v, 16)
    assert len(seen) == REG_COUNT, f"表格条目数 {len(seen)} != {REG_COUNT}"
    assert max(seen) == REG_LAST
    return regs


def to_lvds(regs):
    r = list(regs)
    for a, m in LVDS_SET.items():
        r[a] |= m
    return r


def selfcheck(regs, lvds=False):
    """拿手册 §3 传输模式表反查 §11 表, 抄错了这里会炸"""
    ch = (regs[0xb4] >> 4) & 0x3
    assert ch == 0b10, f"0xb4[5:4]={ch:02b}, 期望 10 (3 通道)"
    want = 1 if lvds else 0
    assert (regs[0x06] >> 9) & 1 == want, f"0x06[9] 应为 {want}"
    assert (regs[0x1a] >> 9) & 1 == want, f"0x1a[9] 应为 {want}"
    # §1: 灰度分组数 reg0x00[14:8]+1, 手册要求 >= 16
    grp = ((regs[0x00] >> 8) & 0x7f) + 1
    assert grp >= 16, f"刷新分组数 {grp} < 16, 违反手册要求"
    return {"channels": 3, "groups": grp, "reg01_width": regs[0x01] & 0x1fff}


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..")
    regs = build()
    info = selfcheck(regs)
    regs_lvds = to_lvds(regs)
    selfcheck(regs_lvds, lvds=True)
    regs_lvds1 = set_channels(regs_lvds, 1)

    for name, tbl, desc in [
            ("icnd2260_regs.mem",       regs,       "TTL-3 通道 (手册 §11 原值)"),
            ("icnd2260_regs_lvds.mem",  regs_lvds,  "mini-LVDS 3 通道 (0x06[9]=1, 0x1a[9]=1)"),
            ("icnd2260_regs_lvds1.mem", regs_lvds1, "mini-LVDS **单通道** (0xb4[5:4]=00), 只用 D0 对")]:
        mem = os.path.join(root, "rtl", name)
        with open(mem, "w") as f:
            f.write("// 由 tools/gen_reg_defaults.py 生成, 勿手改\n")
            f.write(f"// 源: ICND2260 编程指导 V2.8 §11 + §3 传输模式表 -> {desc}\n")
            f.write(f"// 有效范围 0x00..0x{REG_LAST:02X} ({REG_COUNT} 个), 其余补 0 只为凑满 256 深度\n")
            for a in range(256):
                tag = f"// 0x{a:02X}" + ("  <-- 表外补零" if a > REG_LAST else "")
                if a in LVDS_SET and tbl is not regs:
                    tag += "  <-- LVDS 使能位"
                if a == 0xb4:
                    tag += f"  <-- 通道数 [5:4]={(tbl[a] >> 4) & 3:02b}"
                f.write(f"{tbl[a]:04x}   {tag}\n")
        print(f"OK  {REG_COUNT} regs -> {mem}   ({desc})")

    hdr = os.path.join(root, "sw", "icnd2260_regs.h")
    with open(hdr, "w") as f:
        f.write("/* 由 tools/gen_reg_defaults.py 生成, 勿手改 */\n")
        f.write("/* 源: ICND2260 编程指导 V2.8 §11 (TTL-3 通道默认配置) */\n")
        f.write("#ifndef ICND2260_REGS_H\n#define ICND2260_REGS_H\n\n")
        f.write("#include <stdint.h>\n\n")
        f.write(f"#define ICND2260_REG_COUNT {REG_COUNT}u   /* 0x00 .. 0x{REG_LAST:02X} */\n\n")
        f.write("/* §12 上电配置建议: 头两遍整表要把这两位清掉 */\n")
        for a, m in sorted(POWERON_MASK.items()):
            f.write(f"#define ICND2260_POWERON_MASK_{a:02X} 0x{m:04x}u\n")
        f.write("\nstatic const uint16_t icnd2260_reg_default[ICND2260_REG_COUNT] = {\n")
        for a in range(REG_COUNT):
            if a % 8 == 0:
                f.write(f"    /* 0x{a:02X} */ ")
            f.write(f"0x{regs[a]:04x},")
            f.write("\n" if a % 8 == 7 else " ")
        if REG_COUNT % 8:
            f.write("\n")
        f.write("};\n\n#endif /* ICND2260_REGS_H */\n")

    print(f"OK  {REG_COUNT} regs -> {hdr}")
    print(f"selfcheck: {info}")
    print(f"  单通道版 0xb4 = 0x{regs_lvds1[0xb4]:04x} ([5:4]={(regs_lvds1[0xb4] >> 4) & 3:02b})")


if __name__ == "__main__":
    main()
