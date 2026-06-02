---
name: Zynq 7020 Linux vs 裸机 10 维对比
description: 评估 Zynq 7020 上是否切 Linux 时的决策框架, 10 个维度对比 + PREEMPT_RT 实时性数据 + 学习曲线估算
type: reference
originSessionId: b7a84340-ed43-45b4-b468-71142eb587e9
---
针对 Zynq 7020（也适用 7000 系列 / UltraScale+ MPSoC）评估"该不该上 Linux"的对比框架。每条标注对 POV3D 项目的影响。

## 10 维对比

| 维度 | 裸机 | Linux 普通 | Linux PREEMPT_RT |
|---|---|---|---|
| 启动时间 | ~2 s | 15–30 s | 同普通 |
| IRQ 延迟 | < 1 μs | 50–500 μs | 10–50 μs |
| 调度抖动 | 无 | ms 级 | < 100 μs |
| DDR 占用 | 你独占 | kernel+glibc 30–50 MB | 同普通 |
| 硬件访问 | `Xil_Out32` 直写 | `/dev/mem` mmap / driver / UIO | 同普通 |
| 多任务 | 手撸 / FreeRTOS | pthread + epoll | 同普通 + RT 优先级 |
| 网络栈 | lwIP（无 wpa_supplicant） | 完整 mac80211 + wpa | 同普通 |
| 文件系统 | 无 / FAT 手读 | ext4/squashfs | 同普通 |
| 调试 | xsdb + JTAG | gdb / strace / perf | 同普通 |
| 学习成本 | 已会 | PetaLinux+DT+driver 1–2 月 | 同普通 |

## 关键结论

**硬实时永远在 PL，不在 Linux**
- LED panel DCLK / POV slice timing / HLS fire — 必须 PL FSM
- PREEMPT_RT 50 μs 抖动也救不了 500 ns 时序
- 这条决定了 Zynq 上 Linux 一定要配 "PS Linux + PL 时序" 分工（见 project_pov3d_linux_pl_split）

**Linux 的真正杀手锏（按重要性）**
1. 网络栈（WiFi mac80211 / wpa_supplicant / TCP）— 替换 ESP32 桥的核心理由
2. 多任务隔离（pthread/epoll）— 解决 UART poll 嵌套丢事件、byte parser 阻塞
3. 文件系统 — anime/model 数据 scp 上去, 不用编 ELF
4. 调试体验 — gdb/strace/perf 比裸机舒服

**Linux 不擅长的事**
- ARM 直写 PL 寄存器密集循环（调度抢占 → jitter）→ 改 PL FSM
- 严格周期任务（< 100 μs）→ 改 PL FSM
- 极短启动时间 → 走 FSBL+裸机 / 加 splash

## 硬件访问三种方式（重要）

| 方式 | 速度 | 工程量 | 量产合适 |
|---|---|---|---|
| `/dev/mem` mmap | 快 | 小 | ❌ 丑 |
| UIO | 中 | 中 | ✓ 推荐 |
| Kernel platform_driver | 慢 | 大 | ✓ 标准 |

POV3D 这种 HLS IP 控制场景：**UIO 最合适**，kernel 注册中断和地址映射，user-space 写控制逻辑。

## 学习曲线分解（FPGA 工程师视角）

- PetaLinux/Yocto BSP 流程：2–4 周
- devicetree（必须，描述 PL IP 给 kernel）：1 周
- UIO / platform_driver：1–2 周
- shell / Makefile / cross-compile：已有底子，3 天
- systemd / 网络 / 包管理：跟桌面 Linux 一样，1–2 周
- **总计**：全职 1–2 月到独立做项目

## 何时引用此 reference
- 评估某个 feature 是否需要切 Linux
- 决定某个时序敏感模块应该放 PL 还是 PS
- 跟其他工程师讨论"Linux vs 裸机"取舍
- 学习路径排期估算

## 相关 memory
- `project_pov3d_linux_pl_split.md` — POV3D 锁定 PS Linux + PL 时序分工
- `project_lxb_sdio_wifi_plan.md` — Linux WiFi 选型（RTL8822CS）
- `reference_luxiaoban_qspi_flash.md` — Linux flash 预算（32 MB QSPI 够）
- `reference_lxb_no_usb_host.md` — 鹿小班无 USB → 只能 SDIO 路线
