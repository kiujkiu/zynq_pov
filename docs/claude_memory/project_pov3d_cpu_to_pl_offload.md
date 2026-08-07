---
name: CPU→PL 可搬项清单 + 必须留 CPU 的 (2026-08-07)
description: 现状 PS 163%/200% 全在解码+拷贝; PL lz4 一项就砍掉 51ms/帧且顺带消掉 memcpy; WiFi/协议控制面搬不了
type: project
---

2026-08-07 盘点。资源底数见 [[project_lz4_pl_decoder]] 的 Zynq 综合节，
分工战略见 [[project_pov3d_linux_pl_split]]。

## 现状: 芯片是空的, CPU 是满的

| | 用量 |
|---|---|
| **PL** (v3.1 bitstream, routed) | LUT **5.08%** / FF 2.72% / BRAM **6.43%** / **DSP 0%** / IOB 31(15.5%) / WNS +6.888ns |
| **PS** (双核 A9) | `pov_rxd` **163% / 200%** —— 而且这还只是**空闲动画**, 不是推流 |

PS 线程实测绑核: 解码 worker core0 73% + core1 72.6%, flip 线程 core1 17%, main 0.1%。

## 能搬的

### ① lz4 解码 —— 代码已写好, 且**顺带消掉 memcpy**
砍掉 **dec 24.9 + cpy 26.1 = 51 ms/帧**, 两个解码线程 + 拷贝线程一起消失。

🔴 **为什么 memcpy 也跟着没了**: CPU 不能直接解压进 bank, 是因为输出缓冲在 WC
内存里而 LZ77 回溯要读输出缓冲 ([[feedback_lz4_onboard_reality_check]])。
**PL 把 64 KB 历史放片上, 全程不回读 DDR**, 输出是纯顺序流 ⇒ 可以直接线性突发
写进 bank。**CPU 的那条限制对 PL 不成立** —— 这是整件事的关键。

代价: 2 引擎 = LUT 2.8% / BRAM 22.9% / DSP 0。详见 [[project_lz4_pl_decoder]]。

### ② 翻页自动化 —— 改动最小, 收益被低估
现在 flip 线程**软件轮询** POV_CTRL 的 slice 字段 (`usleep(200)` 一轮), 命中翻页窗
才写 `slice_base`。搬进 PL 只要一个"预约"寄存器: 软件写好新基址 + 置 arm 位,
PL 自己在下一个窗口沿切换。

砍掉的不只是一个线程, 还有**整个相位问题** —— `wait` 那 31 ms 和被证伪的
`--phase-lock` 那一大坨逻辑 ([[feedback_phase_lock_premise_wrong]]) 全部不再需要。
LUT 代价几百。

### ③ 顺手可搬
`delta XOR 重建` / `crc32` —— 都能折进 PL 解码器的写出通路, 纯流式。
crc32 现在默认关着 (省 11-18 ms/帧), 搬进 PL 就能一直开。

### ❌ 不建议搬: 切片渲染
HLS `pov_slice_v2` 已达标 (69 µs/片, 见 [[project_pov3d_hls_slicer_arch]]), 但
[[project_pov3d_icnd2260_datapath]] 那笔账是明确的: **对现在这块 1-bit 屏,
传几何比传压缩切片还贵**, 几何只在 ICND2260 目标上才省 4-7×。搬过来是负收益。

## 🔴 必须留在 CPU 的

| 项 | 为什么 |
|---|---|
| **WiFi + TCP/IP 协议栈** | 网卡是挂 PS USB 的 mt7921u dongle, **PL 里没有 MAC 也没有 PHY**。硬约束, `body 20.95 ms/帧` 只能留 PS |
| **会话与协议控制面** | accept / 帧头解析 / ACK-NAK / 关键帧与 GOP 恢复 / MSTREAM 流表 —— 不规则、有状态、要动态分配 |
| **文件系统与内容加载** | 空闲动画从 ext4 读 `anim.pvs`, SD 控制器在 PS |
| **上电 bring-up 与配置** | 寄存器上电序列 / systemd / WiFi 重连 / povmem.ko 映射 |

⇒ **搬完后 PS 上只剩"收包 + 协议"**, 正好回到 [[project_pov3d_linux_pl_split]]
定的战略: 所有硬实时在 PL, Linux 只管网络, DDR 是唯一契约。
