---
name: feedback_vio_poke_survives_soft_rst
description: VIO poke 进寄存器 RAM 的值只有重烧 bit 才清, soft_rst 冲不掉; 2026-09-01 它制造了好几个"同一配置两次结果不同"的假象, 把帧率上限的测量全部污染
metadata:
  type: feedback
---

# poke 的值活得比你以为的久 (2026-09-01)

`icnd2260_seq.v` 的寄存器表是 **RAM 不是 ROM**:
```verilog
reg [15:0] reg_rom [0:255];
initial $readmemh(REG_MEM, reg_rom);              // 只在配置时装一次
always @(posedge clk) if (dbg_reg_we) reg_rom[dbg_reg_addr] <= dbg_reg_data;
```
⇒ **VIO poke 进去的值会一直留着。`soft_rst` 只复位状态机, 不碰这块 RAM。
   只有重新 `program_hw_devices`(BRAM 重新初始化)才恢复出厂表。**

## 它造成了什么

2026-09-01 晚测帧率上限时, 先后 poke 过 `0x15` / `0x00`(刷新分组 74→16) /
`0x03`(Line_len 52→66) / `0x01`(刷新倍率 32→16), 然后在**没有重烧**的情况下继续换时钟档、
换帧率、反复 soft_rst。结果:

- 同样"62.5MHz / 16 分组 / 479 fps", 一次报"9 格全对", 一次报"只有第一格正常"
- 我据此推断出"479 fps 是边缘工作点""可能有温漂"—— **两条都是错的**
- 而 `0x03`/`0x01` 直接决定芯片的显示帧时间 ⇒ 我用来算"芯片上限"的公式在那些点上根本不成立

**结论: 那一批边界读数全部作废。**

## How to apply

🔴 **每一个数据点之前必须重烧一次 bit**, 而且一次只动一个变量。
   `soft_rst` 只能用来"重跑上电流程", **不能**用来"回到已知状态"。

更一般的一条: **凡是"改完不会立刻生效、要等下一次刷新"的调试口, 都要问一句
"它什么时候被清掉"**。这个项目里同类的还有 VIO 的 probe_out(重烧才回 INIT 值)。

顺带: 判断"两次结果不同"时, **先怀疑自己有没有把状态复位干净, 再怀疑温漂/边缘工作点**。
今晚我把顺序搞反了, 白花了半小时去追一个不存在的边缘现象。

相关: [[feedback_vio_readback_tears_after_commit]] [[feedback_frame_rate_must_not_exceed_chip_display]]
