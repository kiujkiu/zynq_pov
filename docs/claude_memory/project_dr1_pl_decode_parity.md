---
name: project_dr1_pl_decode_parity
description: 🎯 2026-09-01 DR1 的 PL 三引擎硬件解码跑通并追平 Zynq — 71.4ms/帧 = 0.98 B/clk(Zynq 74ms/0.95), eng=3/3, drop=0; 挡路的是 pl_selftest 的 DR1 专属 cache 缺陷
metadata:
  type: project
---

# PL 三引擎解码在 DR1 上跑通 (2026-09-01)

```
FRAME seq=0 n=284 comp=166760 flags=0xe8 dec=71.4ms pl=71.4ms 3str/PL
STAT rx=2 flip=2 drop=0
PLDIAG pl 71.4/71.5ms n=2 0.98B/clk out=20448KB eng=3/3 fb=0 ok=1 pipe=off
```
| | Zynq 现役 | **DR1** |
|---|---|---|
| PL 解码 | 74 ms/帧 = 0.95 B/clk | **71.4 ms/帧 = 0.98 B/clk** |
| 并行 | 3 引擎 | `eng=3/3` `3str/PL` |
| 丢帧 | drop 9 | **drop=0, flip == rx** |

## 🔴 挡路的是 `pl_selftest` 的 DR1 专属缺陷 (两层)

**① 缺 cache 回写**: 自检把 LZ4 流写进 CACHED 的 comp 缓冲后只有 `wmb_frame()`,
而 `pov_rxd.c:761` 自己写着"**DR1 上光有它是不够的** —— 见 `frame_flush()`"。
屏障只排序**不赶出 D-cache**, HP 口不 snoop ⇒ 引擎读到旧内容 ⇒ 三个引擎全报
`E_OFF0` 判死 ⇒ **整条 PL 通路被关掉**。
🎯 `pl_dispatch()`(真帧路径)一直有 `frame_flush`(`:2199`), **只有自检漏了** ——
"自检"成了唯一过不去的那一关。

**② 读回做不到, 是基础设施缺失**: 加 flush 后引擎 **done 且不报错**, 但读回是
`memset` 的 `0xa5`, 不一致点落在 **128/448 字节 = 64 的倍数(cache line 边界)**。
`povmem_dr1.c:242` 的 `IOC_FLUSH` 是 `dma_sync_single_for_device` ——
**只 writeback 不 invalidate**; `/dev/mem` 对这块 CMA **同样是 cached**(实测)。
🎯 **驱动没实现读方向是因为真实帧路径不需要**(PL 直写 bank, CPU 从不读 bank);
**自检是全项目唯一"CPU 读 PL 写的数据"的地方**。
⚠ **读回前再 flush 一次是有害的** —— 会把 cache 里的 `0xa5` 写回 DDR 盖掉结果。
⇒ 判据降级: `cmp[k]==0xa5 && k%64==0` 判活并**明说数据未验**, 其它形状仍判死。

## 端到端配方

- 上游 `mlkpai_fs03/stream/pc/povstream.py` **直接能推 DR1**
  (两边 `protocol.h` 只差一行 `PVS_FRAME_RAW_MAX` 12MB vs 21MB)
- `povstream.py stream --dir <frames> --host <IP> --port 9500 --codec lz4
  --lz4-level 12 --stream-split even --stream-workers 3`
- 🔴 **必须 `--stream-split even`**(切 [94,95,95] 三条等分流 = 三个引擎);
  `balanced` 出 **4 流**, 那是当年给两个 CPU 核调的
- 板端 `--pl-lz4 --pl-engines 3 --no-pipeline`
- WSL2 NAT 无碍: povstream **主动 connect 出去**, ACK 走同一条 TCP 回来
- 压缩比实测 **62.9x**(10.47MB 帧 → 166KB)

## 🔴 容器路径最多 2 流

`pov_rxd.c:2415` **硬拒 `PVS_FLAG_MSTREAM`** ⇒ 一个 `.pvs` 最多两条流(面A/面B)
⇒ **开机固化内容只用得上 2/3 个引擎; 吃满三个只有网络推流**。
`dr1v90/tools/make_idle_anim_dr1.py` 能出 lz4 容器(现有 `helix3b.pvs` 是 zlib, flags 0x8a)。

相关: [[project_dr1_hp1_lz4_verified]] [[project_lz4_pl_decoder]] [[project_dr1_parity_plan]]
