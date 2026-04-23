# 2026-04-23 下班前状态

## 硬件当前在跑的版本

ARM ELF `helloworld.c` 现版本（刚下板）：
- **VDMA: circular mode，2 fstore 都指 FB_A**（等效单缓冲）
- **N_POV_IPS = 1**（4-IP dispatcher 在代码里但只用 IP 0）
- 720p60 HDMI，1280×720 fb

Bitstream（`impl_1/hello_zynq_wrapper.bit`）仍是：
- 4 个 pov IP 实例（IP 1/2/3 存在但 ARM 没启动它们）
- VDMA num_fstores=2, linebuffer 512
- VTC 配 720p60（BD revert 过）

## 状态

- ✅ Git 推 GitHub: https://github.com/kiujkiu/zynq_pov
- ✅ 4-IP 并行 dispatcher 代码写好，综合过（timing OK）
- ✅ VDMA PARK_PTR 寄存器写入验证生效（`[park] readback` 匹配写入）
- ❌ **HDMI 黑屏无法诊断**——现场没我也没摄像头，只能靠用户目测
- ❌ 4-IP + 双缓冲 + 720p 时：UART 显示 FPS 稳，VDMA park 切换正确，但用户肉眼 HDMI 无画面
- ❌ revert BD 回 720p 后还是无画面

## 下次验证顺序（用户回来后）

### 先看现在这版 HDMI 是否回来
如果回来了 → 瓶颈确认是**双缓冲 park 模式 + rgb2dvi 下游不兼容**。
策略：保留单缓冲，接受 HDMI 撕裂（反正最终是 LED 板不看 HDMI）。4-IP 并行可以开。

如果还是黑 → 4-IP 本身就把 HDMI 弄挂。可能因子：
- axi_smc 从 3M 到 7M 重新布线影响 VTC/VDMA 控制路径
- HP2 port 启用改变 PS7 内部 DDR 仲裁
- 新 smc_pov_hp2 的时钟 CDC

## 如果现在这版 HDMI 还黑，下一步

```bash
# git 回 1-IP 初始版本（4-IP 之前，38ce7b7 已经有 4-IP 代码，但 BD 是单 IP）
# 其实没有干净的单 IP commit 在 git。从另外个路线走：
# 手动禁用 4-IP BD 相关 + 恢复 ARM 单 IP 原版

# 方案 B：手写一个 bd_remove_extra_pov.tcl，从 BD 里删掉 pov_project_1/2/3 + smc_pov_hp2
# 然后重新综合验证 HDMI
```

已经写好的 revert tcl：`tools/bd_revert_to_720p.tcl` 只回滚 VTC/VDMA 到 720p，没删 4 个 IP。
可以扩展成 `bd_remove_pov123.tcl` 删掉多余 IP。

## 未解之谜

1. 4-IP + double-buffer 下，FPS 47.76，VDMA park 切换 curR=0/1 alternate，看起来完全正常 — 为什么 HDMI 没信号？
2. 如果是 rgb2dvi 的问题，什么 rgb2dvi 内部状态变了？
3. Vivado impl 的 timing 干净（WNS 0.24ns 过 150MHz），不是 timing 坏。

## 今天产出

- Git 化 + 云备份 ✓
- TortoiseGit 装好 + 中文包 ✓
- 4-IP + 1080p30 BD 跑通 ✓
- HLS 驱动路径优化（355 μs/slice）✓
- 点云流协议 + Host/ARM 端跑通 ✓
- 明确了 LED 板最终需求（720 slice × 30 Hz × 160×180，21600 slice/sec）✓
- 资源预算确认：4-IP + LED driver + VDMA 能塞进 XC7Z020 ✓

## 明天建议 3 件事

1. **修 HDMI** — 最紧急，不然肉眼没法 debug
2. **Task #2 LED 板架构设计** — PCB 下单是 critical path
3. **Phase 4b 收尾** — 写 Phase 4b 的 milestone 到 DEBUG_LOG 2026-04-23 并升级任务状态

Last edit: 2026-04-23 晚上
