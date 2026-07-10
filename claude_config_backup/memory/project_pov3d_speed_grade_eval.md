---
name: pov3d-2-1
description: "当前 xc7z020clg484-2, FCLK1 85.7MHz 下 WNS=+0.113ns razor-thin; 换 -1(更慢)必掉时序, 需降 FCLK1 到 ~70-72MHz, PCB/RTL 不动"
metadata: 
  node_type: memory
  type: project
  created_at: 2026-06-15 23:10 CST
  updated_at: 2026-06-15 23:10 CST
  originSessionId: 241cce13-9bee-40a1-a353-d0f7b04250fa
---

## 当前
- 器件 `xc7z020clg484-2` (speed grade -2)
- impl 最终 timing met 但 **WNS=+0.113ns** (剩 113ps, 极紧, 因 FCLK1 超频 85.7MHz / period 11.67ns)
- 7系列速度: -1 < -2 < -3 (数字越大越快), **-1 比当前更慢**

## 换 -1 要改多少
**不用改**: PCB/引脚 (同裸片同 CLG484 同 pinout, BOM 只换型号尾缀) / RTL 逻辑 / 寄存器映射 / 软件流程.
**要改**:
1. Vivado `set_property part xc7z020clg484-1` 重跑 synth+impl
2. **FCLK1 降频** 85.7M→~70-72M (DCLK ~36M): 估 -1 比 -2 慢 10-15%, 85.7MHz 在 -1 上预估 WNS≈-1.4~-1.7ns 不过, 必须降. 改 SLCR 写值 0x00300700 + app 里同步
3. ANGLE_PERIOD 兜底重算: 720×8.16Hz=5880片/s → 72M/5880≈12245
4. 跑一轮 -1 impl 确认实际 WNS (经验估算, 以真报告为准)
5. 重建 BOOT.bin

## 影响
降频后 panel ~8230 fps (vs 当前 9800), 720片@490RPM 需 5880, **仍够 (1.4× 余量)**. 720片 RPM 上限 816→~686.
**判定**: 量产降成本→ -1 可行(降频即可); 要更多 headroom→ 应选 -3 不是 -1. 关联 [[project_pov3d_pcb_v1.md]] [[project_pov3d_48sdi_io_plan.md]].
