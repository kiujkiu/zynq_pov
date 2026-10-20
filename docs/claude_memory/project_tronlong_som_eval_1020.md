---
name: project-tronlong-som-eval-1020
description: 10-20 用户想把主控从米联派 FS03 换成创龙 SOM-TLDR1 (DR1M90, 32bit DDR4-2666, eMMC, 4 bank 全引出); 已出询价清单 PDF, 待询价
metadata:
  type: project
---
10-20 评估结论: 推荐标准版 SOM-TLDR1-M90-64GE8GD-I-A1.0 (B2B 4×80pin, 37×57mm 14g, 4 安装孔); 不推荐 -S 邮票孔版 (Bank11 只半组, DDR4 仅 1333)。同芯片同封装, Bank 33/11 球号不变, PS IP 要按 DDR4 重生成; 代价=重画转接底板 (另一窗口) + 迁创龙 SDK_2025.1/Buildroot。
待厂家答: HP 口实测带宽、2GB vs DS1200 1GB 上限。离心固定: 用户 10-20 定 4 孔 M2 螺丝 + M2-L4 贴片螺母 (4mm=B2B 合高), 不再担心 B2B 脱开。
资料: D:\芯片资料\安路\DR1开发资料; 清单 zynq_pov/docs/progress/创龙核心板询价清单_2026-10-20.pdf。
**How to apply:** 先买样板+TLDR1-EVM 测带宽再画底板, 不打断当周回板验证。相关 [[project-ddr-budget-by-phase-1013]] [[feedback-window-split-sw-pcb]]
