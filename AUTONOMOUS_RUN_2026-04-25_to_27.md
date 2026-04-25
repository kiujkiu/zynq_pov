# 自主运行计划 2026-04-25 21:30 → 2026-04-27 09:30

用户授权 ~36 小时无人监督完成全部非 LED 屏相关任务。每个里程碑 commit + push。

## 用户最终目标（2026-04-25 晚明确）

### A：主机端软件
- GUI（拖入 `.glb` 或其他 3D 文件）
- 自动采样 → 压缩 → UART 发送到板子
- 支持**静态**模型（发一次）和**动态**模型（动画序列流式）

### B：板子端 HDMI 显示
- **左半屏**：完整 3D 投影，10s/圈旋转
- **右半屏**：**36 个切片网格**（每 10° 一个，6×6 排列），每格是该 angle 下的 z 截面
- 36 切片同时静态显示（用户能一次看到全周角度的剖面）

## 36 小时排期

| 时段 | 任务 | 状态 |
|---|---|---|
| 第 1-4 h | 板子右屏 36 切片网格 | 进行中 |
| 第 4-12 h | Host GUI（拖入 + 静态发） | pending |
| 第 12-20 h | Host GUI 动态 glb 支持 | pending |
| 第 20-26 h | PL IP model-update bug 调试 | pending |
| 第 26-32 h | HDMI 双缓冲 + 1080p30 | pending |
| 第 32-36 h | 文档 + 回归测试 | pending |

## 自主期间行为约定

1. 不动板子物理连线（COM 口、JTAG、HDMI 现状）
2. bypass 权限模式
3. 每个 milestone commit + push
4. 遇到无法解决的 bug 写进 status 继续下一项
5. Vivado 长任务在跑时并行做 host 端工作

## 起始状态

- COM 口：COM9（USB 重新枚举过）
- HDMI：720p60 工作中
- HDMI 采集卡：C1-1 USB3 Video，可远程截图（`tools/capture_ffmpeg.py`）
- 当前 bitstream：1-IP pov_project_batch（model-update 有 bug）
- ARM USE_PL=1, DEFEAT_ADDR_CACHE=1（实验中）

## 进度日志

### Hour 0: 任务规划 + status 文档
- 复盘用户需求
- 调整任务优先级
- 文档化此运行
