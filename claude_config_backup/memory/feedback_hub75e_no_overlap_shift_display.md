---
name: HUB75E FM6124 overlap FSM 需要 OE-fall setup delay (v27→v28 翻案)
description: v27 直接 overlap → BCM 塌陷; v28 加 8 cycle OE_PRE 延迟让 FM6124DJ 缓存 SR → overlap 工作 +39% fps
type: feedback
originSessionId: cddd55be-5600-43d2-9b26-a291ffc28846
---
HUB75E PL 驱动想用 overlap FSM 省时间 (shift 下一帧 plane 数据进 SR, 同时 OE 拉低显示当前 plane). 关键是芯片**支持 OE-fall 缓存**: FM6124DJ datasheet 明示 "OE 下降沿缓存 16bit 显示数据", 即芯片内部双缓冲 (SR → display latch 在 OE 下降时快照), 之后 SR 可被新数据覆盖不影响显示.

## v27 翻车 (BCM 塌)

S_PHASE state 让 OE 拉低跟 DCLK 启动**同一个 clock cycle** 发生 (中间只隔 13.3ns @ 75M aclk). FM6124DJ OE-fall caching 需要的 setup time 不够 → SR 已经被新数据覆盖. 实测 6-bit BCM sweep R 值 63-70 几乎不变 = 塌陷成 1-bit. 当时误以为芯片不支持 overlap.

## v28 翻案 (overlap 正常)

加 S_OE_PRE state 在 S_ADDR_ABCDE 跟 S_PHASE 之间: 拉 OE 低后等 OE_PRE_CYC=8 cycles (107ns @ 75M) **不发 DCLK**. 给芯片足够 setup time 完成 OE-fall caching. 然后 S_PHASE 才开始 shift+display overlap.

实测 2026-06-02:
- SERIAL (overlap_en=0): **462 fps** @ TUNIT=32, 6-bit BCM
- OVERLAP (overlap_en=1, OE_PRE=8): **645 fps** → **+39% fps**
- 视觉 grid demo 两个 mode 几乎一样 (BCM 权重保留)
- datasheet 声称 "+50%", 实测 +39% (差 10% = OE_PRE overhead)

## CTRL[6]=overlap_en runtime 切换

v28 加 CTRL bit 6 = `overlap_en`, 可以在跑时切换两种 mode (无需重 bit). A/B 对照非常方便. SR mode (CTRL[4]=1) 始终走 serial path 不受 overlap_en 影响.

## How to apply

HUB75 overlap FSM **可以做**, 但**必须**给芯片 OE-fall setup 时间:
- 不能同一 clock 拉 OE + 启 DCLK (v27 翻车点)
- Setup 要求至少 ~100ns (8 cycle @ 75M aclk)
- 加 OE_PRE state 干等几个 cycle 没有副作用 (反正都是 display time 内)
- 验证方法: 跟 serial mode 对比 fps. overlap mode 应该 +30-40% 快, 视觉 BCM 一致

## 注意芯片 variant

FM6124**DJ** (datasheet 明示 OE-fall caching) vs FM6124 plain (datasheet 没写). 我们这块 panel 实测 overlap 可行, 说明芯片是 DJ 或同等支持. 换 panel 前要确认 datasheet 或拆 chip 看丝印.

类似芯片调研 (datasheet 待确认):
- FM6126 / FM6126A: 同样 SDR HUB75 系列, 可能支持
- ICN2053 / ICN2065: 高速 HUB75, datasheet 没明示 OE caching, 实测后再说
- MBI52xx: 内置 PWM, 跟 overlap 概念无关 (永远是芯片内部 PWM 跑灰度)
