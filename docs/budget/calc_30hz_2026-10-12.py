#!/usr/bin/env python3
"""30 Hz 整链预算复算 (2026-10-12, task cfg-30hz). 口径: 605 片/圈 × 15 rps (900 RPM), 双面, 192×216 RGB565.
数字来源见 budget_30hz_2026-10-12.md; 'SIM' 标的是本分支 tb_stress_core 实测值。"""
N, RPS = 605, 15
F = N * RPS                 # 每面片率 9,075
P = 1e6 / F                 # 片周期 µs
print(f"每面 {F} 片/s, 片周期 {P:.2f} us")

def m(t):  # 余量 (片周期 - 占用) / 片周期
    return (P - t) / P * 100

# ---- DDR (M90 16 bit DDR3, 双 HP 实测天花板 1.786 GB/s, 10-10 X1) ----
SL = 192 * 432             # 每片每面读量 82,944 B (192 列 × 216 行 × 2 B)
rd = 2 * SL * F / 1e6      # MB/s 两面
print(f"DDR PL 直供 {rd:.0f} MB/s vs 1786 ⇒ 余量 {(1786 - rd) / 1786 * 100:.1f}%; 每片最慢实测 95-98 us (长跑 133) vs {P:.2f}")
print(f"  调色板 8-bit {rd / 2:.0f} MB/s ⇒ {(1786 - rd / 2) / 1786 * 100:.1f}%")

# ---- 上行 (12 数据 lane + 校验, 每 beat 16 bit/lane, 每 64 beat 一个 SYNC) ----
beats = 1728 * 3 * 64 / 63
for lr in (800, 1000):
    t = beats / (lr / 16) ; print(f"上行 {lr}M ×12: 一片 {t:.2f} us ⇒ 余量 {m(t):+.1f}%  (帧间空闲 {P - t:.1f} us)")

# ---- 桥片 / 2260 链路帧长 ----
SEQ = 15591             # 序列器一圈 dclk (视频握手→回到门口), tb_stress_core 实测 (166.67 下 93.552 us); 公式件 64+64+24+15368+64 = 15584
for d in (150.0, 1000 / 6, 170.0):
    for nm, fr in (("公式 15584", 15584), ("SIM 一圈", SEQ)):
        t = fr / d; print(f"dclk {d:6.2f} {nm}: {t:.2f} us ⇒ 余量 {m(t):+.1f}%")
print(f"dclk 下限 (按一圈 {SEQ}) = {SEQ * F / 1e6:.1f} MHz")

# ---- 2260 显示 (模型 fps = GCLK / (扫描 × 分组 × Line_len 52), 已上板验证) ----
for d, r, nm in ((150, 4, "供应商表 (74 组/45 扫) @150"), (1000 / 6, 3, "30Hz 表 AA43 @166.67"),
                 (1000 / 6, 3.5, "备选 M4/P7 @166.67"), (150, 3, "30Hz 表 AA43 @150")):
    g = d * r
    grp, sc = (74, 45) if "供应商" in nm else (16, 48)
    fps = g * 1e6 / (sc * grp * 52)
    print(f"{nm}: GCLK {g:.0f} ⇒ {fps:,.0f} fps ⇒ 余量 {(fps / F - 1) * 100:+.1f}%; 一帧显示 {1e6 / fps:.1f} us ({1e6 / fps / P * 100:.0f}% 片周期)")
    print(f"   每行每片 GCLK 上界 = {g * P / 48:.0f} ; 每行每帧 (分组 × 52) = {grp * 52}")

# ---- WiFi ----
for kb in (220, 488):
    for cf in (15, 30): print(f"WiFi {kb} KB/帧 × {cf} fps = {kb * 8e3 * cf / 1e6:.0f} Mbit/s vs ≥160")
