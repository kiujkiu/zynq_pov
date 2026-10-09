---
name: feedback_acg525_led_active_high
description: ACG525 板载 LED 是高有效(FPGA 驱 1=灯亮), 不是低有效; 09-23 冒烟 KEY0 按下 LED0亮/LED2灭、松开相反, 坐实极性, 也解释了空闲态 LED0 灭=PLL 锁定
metadata:
  type: feedback
---

2026-09-23 ACG525-CORE-V2 + CB-V2 冒烟 (`dr1v90/gw5a_bridge/smoke/`):
`led[0]=~locked`、`led[2]=rstn`、`PLLA.RESET=~rstn`。用户回报 KEY0 **按下 LED0 亮 / LED2 灭, 松开 LED0 灭 / LED2 亮**, LED1 ~1 Hz 慢闪。

脚电平对灯: 松开 rstn=1 locked=1 ⇒ D14=0 灯灭、B9=1 灯亮; 按下反过来。⇒ **驱 1 = 亮, 高有效**。

**Why:** `gw5a_loop` README 写过"底板三极管驱动, 可能反相", 冒烟 RTL 按"多是低有效"先取反。取反之后空闲态 LED0 灭, 看起来像没锁, 其实锁住了。`loop_top.v` 的 `assign led = {…, locked}` **没取反, 那个才是对的**。

**How to apply:** ACG525 上 LED 一律按高有效写(1=亮)。KEY0 若接到 PLL.RESET, 按下会故意失锁, LED0 会跟着翻, 别判成接线错。完整桥/环回不要再写 `~locked` 去点灯。见 [[project_gw5a_bridge_firmware]]。
