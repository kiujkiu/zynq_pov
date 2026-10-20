---
name: project-tronlong-som-eval-1020
description: 10-20 用户想把主控从米联派 FS03 换成创龙 SOM-TLDR1 (DR1M90, 32bit DDR4-2666, eMMC, 4 bank 全引出); 已出询价清单 PDF, 待询价
metadata:
  type: project
---
10-20 评估结论: 推荐标准版 SOM-TLDR1-M90-64GE8GD-I-A1.0 (B2B 4×80pin, 37×57mm 14g, 4 安装孔); 不推荐 -S 邮票孔版 (Bank11 只半组, DDR4 仅 1333)。同芯片同封装, Bank 33/11 球号不变, PS IP 要按 DDR4 重生成; 代价=重画转接底板 (另一窗口) + 迁创龙 SDK_2025.1/Buildroot。
待厂家答: HP 口实测带宽。🔴 更正: DR1M90 不是只支持 1GB —— UG1214 §14.1.3 表 14-1: DDR3 最大 1GB, DDR4 最大 2GB (2×x16 8Gb); 地址映射低 1.5GB 线性 + 高位扩展段。离心固定: 用户 10-20 定 4 孔 M2 螺丝 + M2-L4 贴片螺母 (4mm=B2B 合高), 不再担心 B2B 脱开。
资料: D:\芯片资料\安路\DR1开发资料; 清单 zynq_pov/docs/progress/创龙核心板询价清单_2026-10-20.pdf。
**How to apply:** 先买样板+TLDR1-EVM 测带宽再画底板, 不打断当周回板验证。相关 [[project-ddr-budget-by-phase-1013]] [[feedback-window-split-sw-pcb]]

## 10-20 晚 [D52] 转接板接口规格已出
docs/创龙核心板转接板接口_2026-10-20.pdf (+ html, 数据 csv 在 docs/创龙核心板转接板接口_数据/)。原则: 对外接口=现 SoC 转接板 10-15 版, FPC1/FPC2 逐脚不变, 位流约束不变 (202 个 CEP 球全在核心板上); Bank33/11=2.5V, 32/31=3.3V; 新增 25MHz@L18、KEY L19、USB3320C PHY、串口、SD、JTAG、BOOT、CN4。引脚表 (表7) 已对原理图核实无偏移 (子 agent 报"差 2"是误读: 脚号印在线上方)。核心板内 LVDS 对内差 ≤4.8 mil。
