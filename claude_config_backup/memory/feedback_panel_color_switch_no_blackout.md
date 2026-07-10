---
name: panel 切色不黑屏 = 单 xsdb + 内 while + BRAM 直填 + CTRL 保持
description: POV3D panel 8 色循环切换时不黑屏的关键模式. 反例 = 每次新 xsdb session 重写 CTRL=0x501 会重启 panel state machine 导致切色之间黑屏闪烁
type: feedback
created_at: 2026-06-10 22:15 CST
updated_at: 2026-06-10 22:15 CST
originSessionId: c78b366a-9956-43b2-b7a2-3266def74ae0
---
**规则**: panel 切换显示内容(颜色/图像)时, **xsdb 进程只能起一次** + while loop 在内部 + 一次性设 CTRL + 只改 BRAM 数据.

**Why**:
- panel state machine 在 CTRL=0x561 (OVERLAP) 或 0x521 (use_fb) 下持续输出, 改 BRAM 不打断扫描
- 每次新 xsdb session 重 connect + 重写 CTRL=0x501 = panel reset → 切色之间黑屏几百 ms
- 同时多 xsdb 抢 ARM 控制更糟 (用户原话 "多个进程抢屏幕控制"), panel 反复 reset

**How to apply**: 写 panel 显示循环脚本时, 模板:
```tcl
connect
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
# 一次性初始化
mwr -force 0xF8000180 0x00500500
mwr -force 0x40020014 0x00000608
mwr -force 0x40020008 127
mwr -force 0x40020000 0x561   ; # CTRL 设一次就别动
while {1} {
    mwr -force 0x40028000 $color 4096  ; # 只填 BRAM
    mwr -force 0x4002C000 $color 4096
    mwr -force 0x40038000 $color 4096
    mwr -force 0x4003C000 $color 4096
    after 2000
}
```

反例: `_8color_cycle.tcl` 单色单进程, shell 外面 for 循环 → 每次新 xsdb 重写 CTRL → 黑屏闪烁.
正例: `_8color_inner_loop.tcl` 单 xsdb + 内部 while → 12+ 圈无黑屏 (2026-06-10 22:05 cam 0 Insta360 验证).
