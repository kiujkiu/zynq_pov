---
name: linux-wifi-2026-06-16
description: 128³点云动图 Linux+RTL8822CS WiFi 能实现(现ESP32太慢250×); 真卡点是 glb skinning(动画源没做) + B1生成900ms/帧; 推荐预算循环架构绕过实时带宽/速度
metadata: 
  node_type: memory
  type: project
  created_at: 2026-06-16 15:30 CST
  updated_at: 2026-06-16 15:30 CST
  originSessionId: 241cce13-9bee-40a1-a353-d0f7b04250fa
---

## 问题: 用 Linux+WiFi 传点云动图能实现吗
**能 (128³), 但 WiFi/Linux 不是卡点, 真卡点在上游动画源 + B1 生成速度.**

## 带宽账
- 每帧点云 = 点数×16B. 128³~10万点=1.6MB/帧; 400³~100万点=16MB/帧.
- 8fps(=490RPM 每圈一帧): 128³ 需 **~100Mbps**; 400³ 需 ~1Gbps.
- WiFi: 现 ESP32-C5 桥 ~0.1-2Mbps **差 50-250× 远不够**; **RTL8822CS+Linux SDIO ~200Mbps real 够 128³**(见 [[project_lxb_sdio_wifi_plan]]); 400³ 要 GEM0 千兆.

## Linux 角色: 完美契合 (非卡点)
收 WiFi(wpa_supplicant+socket)→写 DDR 保留内存→UIO 触发 B1→显示读. = PS Linux+PL 时序分工 ([[project_pov3d_linux_pl_split]]), 渲染零占用全在 PL. 网络栈是 Linux 杀手锏.

## 真卡点 (排序)
1. **⛔ glb skinning 没实现**: host/glb_to_points.py 只出静态 bind pose, 不评估骨骼+蒙皮. 连动画点云序列都生不出. 纯 PC 软件, 解锁动图的第一钥匙. (见 [[project_pov3d_onchip_chain_handoff]] 动图卡点)
2. **B1 生成 900ms/帧** (128³ DDR gather): 实时只~1fps. 绕法:
   - **预算循环(推荐最现实)**: 动画各帧点云 WiFi 传一次→离线 B1 批算所有帧切片存 DDR→显示按转角循环播. WiFi 一次性传, B1 慢无所谓, 实时带宽要求消失, 8fps@490RPM 轻松. 限制=DDR 帧容量(512MB/5.76MB≈80帧) + 显示 13.6体帧/s 上限.
   - 真实时流: 要 BRAM 单色网格提速(彩色 6.3Mb 塞不进 7020 BRAM).

## 推荐架构 (128³ 动图)
PC 动画 glb →[skinning 每帧点云]→ WiFi(RTL8822CS) → Linux 收+存 DDR → B1 离线批算全帧切片 → 显示按转角循环播 (8fps@490RPM).
- WiFi/Linux 不卡; 卡点=①glb skinning(必做) ②B1 速度(预算模式绕). 400³/高fps 要千兆+UltraScale+.
关联 [[project_pov3d_hls_onchip_render]] [[project_pov3d_final_target]] [[reference_zynq_linux_vs_baremetal]].
