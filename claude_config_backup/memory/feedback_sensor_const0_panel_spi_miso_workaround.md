---
name: hub75e-ip-sensor-pulse-tie-const0-fanout
description: "新加的 BD 外部输入口连到 IP input 会被 Vivado 综合 tie 成 const0 (sens_cnt 永 0); 解法=把 IP input fanout 到一个已驱动逻辑的现存外部口 (panel_spi_miso), 信号才真到"
metadata: 
  node_type: memory
  type: feedback
  created_at: 2026-06-15 21:30 CST
  updated_at: 2026-06-15 21:30 CST
  originSessionId: 241cce13-9bee-40a1-a353-d0f7b04250fa
---

## 现象
hub75e_panel_seq IP 新加 `sensor_pulse` 输入 + 新建 BD 外部 input 口 `sensor_pulse` 连上去, 综合后 IP input 被 tie 成 `<const0>` (探针 `hello_zynq_i/sensor_pulse <- <const0>`). 板上 sens_cnt(0x2C) 永远 0, angle_tracker 收不到脉冲. 试遍: module_ref recreate / inline RTL / dont_touch / ungated counter / nuclear regen / 关 incremental — **12 个 build 全失败**. RTL+BD HDL 都确认正确, 是综合层把"只连到顶层未约束输入口"的 IP 引脚优化没了.

## 解法 (2026-06-15 验证通)
**不要给 IP input 新建专用外部口**. 把 IP input fanout 接到一个**已经在驱动真实逻辑的现存外部输入口**上:
```tcl
# build_sensor_workaround.tcl 关键步骤
disconnect_bd_net [get_bd_nets sensor_pulse_1] [get_bd_pins hub75e_panel_seq_0/sensor_pulse]
delete_bd_objs [get_bd_ports sensor_pulse]   ; # 删死口
connect_bd_net [get_bd_pins hub75e_panel_seq_0/sensor_pulse] [get_bd_ports panel_spi_miso_tri_i]
# ↑ pin→port fanout. 传 port 对象, 不是 net 名字符串 (那样报 connect_bd_net requires 2 pins)
```
panel_spi_miso_tri_i 本来驱动 axi_gpio (net 是活的 fanout), 共享给 hub75e 后综合不会优化掉 → 信号真到. XDC 把光电开关脚 (V14) 从 sensor_pulse 改成 `panel_spi_miso_tri_i[0]`.

## 验证 (sens_cnt 0x2C 是决定性探针)
flash workaround bit (impl_1/hello_zynq_wrapper.bit, **不是** vitis_ws/sdt 那个 stale), CTRL bit15 sensor_en=1 (0xC5E1). 手转/挡光电开关 → sens_cnt 从 0→25→72 连续涨, rev_period(0x28) 从 0xFFFFFFFF 默认变 ~24.8M (3 转/s 合理值). **转子停着时 slice 冻在 0 是正确** (丢脉冲保护, 防过期角度). 闭环全验证需连续匀速转.

## Why / How to apply
**Why**: Vivado 综合对"只到顶层 input 口、无下游 fanout 竞争"的 IP 引脚有时直接 tie const. 标准 dont_touch/incremental 开关救不了.
**How**: 凡新 sensor/外部输入要喂 IP, 优先 fanout 到已验证 survive 的现存外部口, 别开新口. 调试探针必须是 IP 内部边沿计数器寄存器 (像 0x2C), 单读 slice_idx 会被丢脉冲兜底骗过. 关联 [[feedback_vivado_bd_addr_width_cache.md]] (同类 BD 综合顽固缓存), [[feedback_refresh_bit_stale_xsa.md]] (烧 bit 别用 vitis_ws stale).
