---
name: 换 bitstream 必须冷启动, reboot 不重载 PL
description: reboot 只重启 Linux 不经过 FSBL → PL 里还是旧 bit; 用"写新寄存器位再回读"判定比看 uptime 硬
type: feedback
---
2026-07-28 换了带 `mirror_b` 的新 bit 后，用户说「重启了」，但现象跟旧 bit 一样。

**根因**: bitstream 是 **FSBL 在上电时**从 SD 的 `BOOT.bin` 烧进 PL 的。
`reboot` 只重启 Linux，**走不到 FSBL**，PL 里还是旧的。**必须物理断电再上电。**

## 判定方法 (比看 uptime 硬)

给新 RTL 加一个**新寄存器位 + 状态回读位**，然后写进去再读回来：
```python
pw(0x10,(360<<16)|0x15); on  = (pr(0x00)>>13)&1   # 写 mirror_b=1
pw(0x10,(360<<16)|0x05); off = (pr(0x00)>>13)&1   # 写 mirror_b=0
新 bit 已加载  ⟺  on==1 and off==0
```
旧 bit 根本没有这两位，写了不认 → 一次读写就能确诊。
看 `uptime -s` 也能佐证（开机时刻没变 = 没冷启动），但**软重启会让 uptime 归零却不换 bit**，
所以寄存器判据更可靠。

**How to apply**: 以后每次换 bit，**先跑这个判据确认生效，再判断现象**。
否则「改了没生效」会被误判成「改错了」，白白推翻正确的改动 —— 今天差点就这样。

建议: 新增 RTL 功能时**顺手留一个状态回读位**，成本几乎为零，收益是每次换 bit 都能自证。
