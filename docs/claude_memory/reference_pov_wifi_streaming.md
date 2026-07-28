---
name: PC→WiFi 实时推流通路 (PVS1) — 早就建好了, 别重复造轮子
description: stream/ 下完整推流链: povstream.py + pov_rxd + 30 多套现成动画帧; 实测 9.89fps 压缩 35.9x
type: reference
---
🔴 **2026-07-28 教训: 我搜"动画/推流"只翻了 `tools/` 和记忆库, 都没找到就动手自己写,
其实整套东西早在 `mlkpai_fs03/stream/` 下。搜索时务必扫 `stream/`。**

## 组件

| 组件 | 位置 |
|---|---|
| PC 推流端 | `stream/pc/povstream.py` + `pov_studio.py` + `POV_Studio.bat` |
| 动画生成 | `stream/pc/glb_anim.py` — 支持 glTF **骨骼 skinning / morph / 节点 TRS** |
| 协议 | `stream/protocol.h` — **PVS1**, 端口 **9500**, zlib + XOR delta + ACK |
| 板端接收 | `stream/board/pov_rxd` (v2, 开机自启, WC 映射经 `/dev/povmem`) |
| 设计文档 | `docs/design_icnd2047/04_sw_stream_26fps.md` |
| 现成动画 | **30+ 套** `stream/pc/frames_*`: robot 144帧 / groot 97 / zac_dance72 73 / bonsai / irelia / yasuo … |

## 用法

```bash
# 预渲染到磁盘 (numpy 秒级/帧, 正常流程必须先 render)
python3 povstream.py render --anim glbanim --glb Robot.glb --frames 144
# 推流
python3 povstream.py stream --dir frames_robot --host 10.10.21.3 --fps 10 --loop
```

## 实测 (2026-07-28)

| 指标 | 值 |
|---|---|
| 帧率 | **9.89 model fps** (目标 10) |
| 线速 | 1.22 MB/s = 10.1 Mbps, 链路占用 36% |
| 原始数据率 | 43.75 MB/s (360片 × 4.42MB/帧) |
| **压缩比** | **35.9×** (1-bit + 极稀疏, zlib 效果极好) |
| 按链路上限推算 | 76 fps 余量 |
| ARM 解压 | 52-71 ms/帧 |

⚠ **反直觉**: 「传点云比传切片省带宽」是**错的**。切片虽原始 4.42MB 但 1-bit 极稀疏、
压到 ~123KB; 点云带坐标压不了那么狠 (95K 体素 × 4B ≈ 380KB 原始, 压完 150-200KB)。
片上渲染的价值在**实时性**和**几何参数解耦**, 不在带宽。

## 陷阱

- **`pov_en` 必须=1**, 否则引擎读静态 fb, 推进 DDR 的帧根本不被消费
  (日志会刷 `drop=N` + `WARN: no flip window (engine idle?)`)。
  `pov6_chess.py` 之类会把 `pov_en` 清零, 推流前要重设。
- 正常工作的标志是日志出现 **`FRAME → FLIP` 交替**。
- `frames_*` 大多是 2026-07-09 渲的, 用的是**旧几何**(穿心/无镜像)。
  几何改了必须用 `povstream.py render` 重渲, 见 [[project_pov3d_offset_axis_geometry]]。
