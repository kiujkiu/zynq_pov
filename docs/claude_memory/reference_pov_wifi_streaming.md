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

## 内容渲染: 三个改动的代价完全不同 (2026-07-28 定论)

| 改动 | 硬件能否解决 | 要重渲内容吗 |
|---|---|---|
| 双屏 (PHASE_B=180) | 本来就是硬件, 两屏共用同一份 360 片 | ❌ 不用 |
| 手性 / 镜像 | ✅ `mirror_a`/`mirror_b`, 几个 LUT | ❌ 不用 |
| **偏移平面几何 (gap 13.8mm)** | ❌ **结构上做不到** | ✅ **必须重渲** |

**为什么偏移补不了**: 镜像是**片内置换**(fb 写地址过查找表即可); 偏移是**跨切片重采样** —
屏上像素 u 的方位 = θ + atan2(off, u), **跟 u 有关**, 一列像素横跨近 180° 方位,
理论上要同时读 160 片。而 fb 里只放一片 (9 lane×512×32b BRAM), 拿不到别的片的数据。
⇒ 这正是**片上渲染**的核心价值: 几何变成寄存器, 机械结构改了整个内容库不用动。

## 重渲流程 (每个模型要单独定参)

glbanim 用**整段动画并集 bbox** 归一化(防帧间抖动), 导致单帧常常又小又偏。
机器人实测: 默认 scale=1.0 时竖直只占 66/180、偏下 19px、上方空 64px。

```bash
# ① 渲 1 帧量包络 → ② 定 --scale / --y-offset → ③ 渲全套
povstream.py render --anim glbanim --glb X.glb --frames 144 --render-slices 360 \
    --gap-mm 13.8 --scale 1.3 --y-offset 19 --out-dir frames_X
```
- `--y-offset` 是 2026-07-28 新加的 (原来只有 `--x-offset`)
- `--robust-fit` ([2,98] 分位 bbox) 单独就能放大 2.2× 但机器人上会裁切, 慎用
- 速度: **0.7-0.8 s/帧**, 144 帧约 2.5 分钟 (GLB 采样有缓存只做一次)
- ⚠ **量包络必须用整段动画**: 单帧测机器人 X 顶到 0..159 像是裁切,
  整段包络其实 4..155 根本没裁 —— 个别帧手臂张开而已

## 🔴 povstream 参数接线的坑

`--gap-mm` 加进 CLI、`render_packed_frame` 签名也改了, 但**忘了从调用点传进去**,
默认值 `axis_off=0.0` 静默生效 —— 不报错、看着像接通了、只有结果是错的, 排查极慢。
现已在 `gen_packed_frames` 开头打印实际几何:
```
[geom] gap=13.8mm → 每屏到轴垂距 7.36px (偏移平面) | mirror_u=ON
```
**教训**: 新增影响输出的参数, 一律在运行时打印实际生效值。
