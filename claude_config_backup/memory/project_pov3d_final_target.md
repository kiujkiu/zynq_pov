---
name: POV3D 最终 LED 板性能目标
description: 最终量产 POV3D 体感显示器的关键硬件参数 + 推导出来的 PL 时间预算
type: project
originSessionId: bafc105a-a8db-471f-ae33-42571927b4da
---
## 🎯 屏幕级目标对齐 (2026-06-29 用户确认, 取代下方旧 8-bit 目标)
**最终目标 = ICND2047 / 6-bit / W=16(拆daisy) / 1/32扫 / 外部 BCM**:
- panel fps: 理论 12,401(显示卡 1e9/(40ns×32×63)) / **单缓冲实测 ≈ 9,500**
- 体刷新分配(=fps/slice): 360片×~26Hz(1583RPM) / 720片×~13Hz / 316片×30Hz
- IO: 48 lane(6×8芯片独立SDI)+控制
- gamma LUT 把 6-bit 感知补到≈8-bit
- 🔴 **旧的 720×30=21,600fps / 8-bit 目标做不到**: 8-bit 撞 OE 40ns 墙顶~3k; 内置GCLK芯片(ICN2053/2065)对POV慢(16-bit=15Hz/762fps, 见 [[reference_pov_chip_selection]]), 不是出路. 真8-bit高fps在已验证硬件上无解.
- 实现方法/帧率公式见 [[project_pov3d_panel_fps_roadmap]]; 待办: 拆daisy 48-lane IO 改造 + fb路径上板.

---
(以下为 2026-04-23 旧目标, 已被上面对齐结果取代/修正)
最终 LED 板需求（2026-04-23 用户确认）：
- **720 slice / 360° 转一圈**
- **体刷新 30 Hz**（= 1800 RPM 机械转速）
- **每 slice 分辨率 160 × 180 像素**
- **15-30 路并行 RGB** 电驱（ICND1069 驱动芯片级联）
- **HDMI 预览走 1920 × 1080**（刚好 160×180 × 72 个格子）

**Why：** 用户拿"体积感觉连续"标准倒推。1800 RPM 是机械上限，30 Hz 是人眼融合下限。720 slice 是角度分辨率标准。

**How to apply：** 任何渲染优化讨论都要对照 **21600 slice/sec** 这个硬指标（720 × 30）。单 slice 硬预算 46 μs 平均（架构 C 允许抖动缓冲；架构 B 是硬死线）。

目前单 IP 实测 ~355 μs/slice，差 8×。路线确定为：**4-8 路并行 IP + m_axi 优化**，预计可达成。备选：升级到 Zynq-7035 或降体刷新到 15 Hz。
