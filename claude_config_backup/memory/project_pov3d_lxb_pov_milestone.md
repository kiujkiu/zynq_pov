---
name: pov3d-lxb-pov-milestone
description: "鹿小班 Zynq7020 POV 显示三件套达成 (2026-06, 用户确认): FM6124 anime旋转体跑通 + ICND2047棋盘格实拍 + angle_tracker转速自动检测生效"
metadata: 
  node_type: memory
  type: project
  created_at: 2026-06-23 CST
  updated_at: 2026-06-23 CST
  originSessionId: fe6cecaa-6915-4b7c-91e6-2e0b62bc1aaa
---

鹿小班 (XC7Z020) POV 显示侧三件套全部达成 (用户 2026-06-23 确认):

| # | 内容 | 状态 |
|---|---|---|
| 1 | FM6124 **128×128** dual panel **anime POV 旋转体** | ✅ **跑通** (1-bit/W=128/32扫/~11.7k fps, 720片 compact, 冷启+热换 anime/globe 都通) |
| 2 | ICND2047 **128×64** 红绿棋盘格 | ✅ **实拍确认** (8色竖条+棋盘格, 色序/偏移/几何全对, commit 62031f3) |
| 3 | **angle_tracker 转速自动检测** | ✅ **已生效** (v8 集成 bb70adb, 光电开关测 rev_period 自动算 slice_idx) |

## 第3条机制 (部署真相)
部署的 BD panel IP = **hub75e_panel_seq_v8** (BD synth 网表 `x_ipName=hub75e_panel_seq_v8`, commit bb70adb 06-15):
- v8 line333 `wire sensor_en = reg_ctrl[15]`
- u_angle_trk 实例化: `.fake_en(~sensor_en) .fake_period(reg_angle_period)`, `slice_idx_live = trk_slice` 直接(无条件, sensor_pulse 不被 trim)
- 部署 **CTRL=0xC5E1 → bit15 sensor_en=1 → 真光电开关自动检测**; ANGLE_PERIOD(0x1C=14577) 退化成未lock时 fallback; DBG(0x24) bit16=trk_locked (本会话 globe 那次 locked=1)

## ⚠ 修正历史误判
早前(本会话)曾误判"angle_tracker 未接入/用手动假周期"——那是看了**旧版 v6**(06-11 确实没接, 注释"预留/暂不用"). 实际 v7(06-12)/v8(06-15) 已接入并部署. **教训: 追部署真相必看 BD synth 网表 `x_ipName` 用哪版, 别拿磁盘上某个旧 .v 当真相** (跟 W=16/W=128 同类错: 综合默认 vs 实际运行). 旧记忆 [[feedback_angle_tracker_two_interp_bugs]] "待验证" 和 dual_panel "待接入" 均已过期.

## 意义 + 下一步
鹿小班 **POV 显示侧能力完整**. 下一步 **Linux + USB-WiFi 主机侧转 MLKPAI-FS03 板** (米联客 FS03, 同 XC7Z020, 有 USB3320 ULPI PHY = USB host + 出厂 Linux), 鹿小班无 USB host 做不了 USB WiFi. 关联 [[project_pov3d_two_board_snapshot_2026-06-22]] [[project_pov3d_panel_fps_roadmap]] [[reference_lxb_no_usb_host]].
