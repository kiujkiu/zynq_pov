# WiFi 数据链路协议设计 (Phase 9 framework)

> 状态: **设计阶段, 无硬件**. 等 ESP32-WROOM-32 模块到位 + 选定 Zynq 走 GEM0/ESP32 桥两条路线之一再实现.
>
> 写于 2026-05-07, 分支 `experiment/wifi-framework`.

---

## 1. 背景与目标

### 1.1 现状瓶颈

| 链路            | 实测/理论吞吐         | 备注                                     |
|-----------------|-----------------------|------------------------------------------|
| UART 921600     | ~92 KB/s (effective)  | drain RX cost ~5%, 实际 87 KB/s          |
| UART 460800     | ~46 KB/s              | 老路径, 已弃用                           |
| GEM0 (鹿小班)   | hung @ TX             | gmii_to_rgmii BUG, 见 `project_luxiaoban_ethernet_blocker.md` |
| ESP32 WiFi 桥   | 2-5 MB/s 实测预期     | TCP via ESP32 → UART 921600 仍是 0.09 MB/s 瓶颈 |
| **直连 PL WiFi**| 不存在                | 鹿小班 PL 无 WiFi 模块                   |

### 1.2 目标参数 (来自 `project_pov3d_final_target.md`)

- 720 slice × 30 Hz × 160×180 (体素) = 21600 slice/s
- 单 slice 28800 voxel × 假设平均 4 B (sparse) ≈ 115 KB
- 整帧 720 slice ≈ **6.2 MB/frame**, 30 Hz ⇒ **186 MB/s**
- WiFi 实测上限 (2.4 GHz 11n 单流) **20-50 MB/s** ⇒ **不够**

⇒ **必须采用 cache + delta 增量更新**, 不能整帧上传.

### 1.3 协议分层

```
┌────────────────────────────────────────────────────────┐
│ Application layer   PMSH / PPCL / PSLD (slice delta)   │  现有 + 新增
├────────────────────────────────────────────────────────┤
│ Session layer       PWFR (wifi framing)                │  新增
├────────────────────────────────────────────────────────┤
│ Transport           TCP (control) + UDP (bulk slices)  │
├────────────────────────────────────────────────────────┤
│ Link / Phy          WiFi 802.11n 2.4 GHz               │
└────────────────────────────────────────────────────────┘
```

---

## 2. 数据流模型: cache + delta

### 2.1 关键洞察

整帧上传不可行, 但 **大部分 slice 帧间相关性极高** (旋转或单纯模型动画, 多数 voxel 不变). 板端缓存模型 + 主机推送 delta:

- **静态模型 + 旋转**: host 上传一次完整 voxel grid (~5-10 MB), 板端按角度 rotate 渲染 720 slice. host 只发 **rotation phase** 控制 (4 字节/帧).
- **动画模型** (anime, 60 frame): host 上传 N 个 keyframe 完整模型, 板端按时间 t 切换. host 每帧发 `(keyframe_idx, phase)` (6 字节).
- **morph / 实时变形**: host 发 **delta voxel list** = (added, removed) 两个 list of (idx24, rgb16). 实测 90% slice delta < 1000 cells = 5 KB/slice ⇒ 120 KB/frame ⇒ **3.6 MB/s @ 30 Hz**, WiFi 完全可承受.

### 2.2 三种工作模式

| 模式            | 上行带宽           | 适用场景             | 实现成本 |
|-----------------|--------------------|---------------------|----------|
| `MODE_FULL`     | 6 MB × 30 Hz = 180 MB/s | demo/调试, 离线整帧 | 已有     |
| `MODE_ROTATE`   | < 100 B/s          | 静态模型 + 旋转     | 板端 cache, host 只发 phase |
| `MODE_DELTA`    | 1-10 MB/s          | 动画 + morph        | 板端 cache + diff apply |

POV3D 产品目标 90% 时间在 `MODE_ROTATE`, 偶尔切换模型 → `MODE_FULL` 一次预加载.

---

## 3. Wire format

### 3.1 PWFR 容器 (WiFi framing) — 24 字节头

复用 PMSH/PPCL 现有 magic, 但加 **session header** 一层用于 TCP 流 reassembly + 重传:

```
offset  size  field          描述
0       4     magic          'PWFR' = 0x52465750  (LE)
4       2     ver            = 1
6       2     msg_type       见下表
8       4     seq            会话内 monotonically increasing
12      4     payload_len    后续 payload 字节数 (不含 header)
16      4     payload_crc32  payload CRC32 (zlib variant)
20      2     ack_seq        最近收到的 host→board ACK 的 seq, 用于流控 (board→host 时 0)
22      2     reserved
24+     N     payload        opaque, 由 msg_type 决定
```

### 3.2 msg_type 表

| 值      | 名称              | 方向         | payload                                          |
|---------|-------------------|--------------|--------------------------------------------------|
| 0x0001  | `MSG_PING`        | bidir        | 空 / 8B timestamp                                |
| 0x0002  | `MSG_PONG`        | bidir        | echo timestamp                                   |
| 0x0010  | `MSG_FULL_PMSH`   | host→board   | 现有 PMSH 完整字节流                             |
| 0x0011  | `MSG_FULL_PPCL`   | host→board   | 现有 PPCL 完整字节流                             |
| 0x0012  | `MSG_FULL_VOXEL`  | host→board   | sparse voxel: count u32 + (idx24+rgb16) × N      |
| 0x0020  | `MSG_DELTA_VOXEL` | host→board   | added_n u32, removed_n u32, added cells, removed idx24 |
| 0x0030  | `MSG_PHASE`       | host→board   | rotation phase u32 (Q16.16, 单位 turn) + frame_id u32 |
| 0x0040  | `MSG_MODE`        | host→board   | u8 mode (0=FULL,1=ROTATE,2=DELTA), 配置          |
| 0x0080  | `MSG_ACK`         | board→host   | u32 acked_seq, u8 status                         |
| 0x0081  | `MSG_NAK`         | board→host   | u32 missing_seq, u32 reason_code                 |
| 0x0090  | `MSG_FPS`         | board→host   | u32 frame_id, u16 measured_fps_q8, u16 dropped   |

### 3.3 PSLD (slice delta payload, 用于 MSG_DELTA_VOXEL)

```
offset  size           field
0       4              added_n
4       4              removed_n
8       added_n*5      added cells: idx24 (3B) + rgb565 (2B)
8+An*5  removed_n*3    removed: idx24 (3B)
```

CRC32 在 PWFR header. board 端验证后 apply 到 voxel grid (set/clear).

---

## 4. 传输层选择

### 4.1 TCP for control + small (<= 32 KB)

- 用 ESP32 桥时已有 (TCP:8888, see `esp32_bridge/firmware/main/pov_bridge.c`)
- 直 PS GEM0 时用 lwIP raw API 或 socket API
- TCP 自带重传/拥塞, 简单可靠
- 缺点: head-of-line blocking, 高 RTT 时 30 Hz delta 串行发送会卡

### 4.2 UDP for bulk slice burst

- 720 slice / 33 ms = 46 μs/slice 硬预算
- UDP 异步 burst, 单 packet ≤ 1472 B (MTU 1500 - IP/UDP)
- 单 slice (~5 KB delta) = 4 packets, 720 slice = ~2880 packet/frame ⇒ 86K pps
- ESP32 lwIP UDP 实测 5-15K pps 上限 ⇒ **ESP32 桥不够**, 必须直 PS GEM0
- **重传策略**: 应用层 NAK. board 收 PWFR 后 verify CRC + check seq 连续, 缺包发 `MSG_NAK(missing_seq)`. host 重发该 PWFR.
- 容忍丢包: `MODE_ROTATE` 丢一帧 phase 无所谓 (下一帧覆盖); `MODE_DELTA` 丢 delta 必须重传 (否则 voxel grid 失同步), 板端遇 NAK 太多直接请求 `MSG_FULL_VOXEL` 全量同步.

### 4.3 流控

- TCP: 让 OS 处理
- UDP: 应用层滑动窗口, host 每发 N 个 PWFR 等一个 ACK (window = 8). board 每 8 个 seq 发一次 cumulative ACK.

---

## 5. 主机端 ↔ 板端 现有协议 mapping

| 现有 wire        | WiFi 走法                      | 说明                              |
|------------------|--------------------------------|-----------------------------------|
| PMSH (mesh)      | `MSG_FULL_PMSH` 整包 over TCP  | 4 MB texture 单次, 不频繁         |
| PPCL (pointcloud)| `MSG_FULL_PPCL` 整包 over TCP  | 30K points × 16B = 480 KB         |
| PPCL sparse voxel| `MSG_FULL_VOXEL` over TCP      | 同上, 5B/cell                     |
| (新) phase only  | `MSG_PHASE` over UDP, 30 Hz    | 8 字节, 旋转动画                  |
| (新) delta voxel | `MSG_DELTA_VOXEL` over UDP     | 实时变形/morph                    |

板端 RX 路径 (`uart_poll_frame()` → 改为 `wifi_poll_frame()` ): 把 PWFR 头剥掉, 拿 payload 走老路径 (PMSH/PPCL). MODE_PHASE/DELTA 是新分支.

---

## 6. 实施路线 (3 阶段)

### Phase 9-A: framework (本 PR)

- 协议文档 ✅ (本文件)
- host/wifi_stream.py: TCP socket framework, mock send
- 板端 stub C 代码 (尚未集成 lwIP, 仅占位接口)
- ESP32 bridge 已有完整代码 (透传, 不区分 PWFR/PMSH), 暂沿用

### Phase 9-B: ESP32 桥实测

- 买 ESP32-WROOM-32, 烧 `esp32_bridge/firmware/main/pov_bridge.c`
- host 走 socket → ESP32 → UART → Zynq, **不改 wire 协议**, 沿用 PMSH/PPCL
- 实测吞吐: 期望 100-300 KB/s (UART 921600 仍是 cap)
- 此阶段 PWFR 头不必引入, 透传足够

### Phase 9-C: 直 PS GEM0 + lwIP

- 修 `project_luxiaoban_ethernet_blocker.md` 里的 gmii_to_rgmii TX hung
- BSP 加 lwip213 / lwip220 — **Vitis 2024.2 已自带 4 个版本**:
  - `C:\Xilinx\Vitis\2024.2\data\embeddedsw\ThirdParty\sw_services\lwip213_v1_0/_v1_1`
  - `C:\Xilinx\Vitis\2024.2\data\embeddedsw\ThirdParty\sw_services\lwip220_v1_0/_v1_1`
- 现成 reference apps (在 `embeddedsw/lib/sw_apps`):
  - `lwip_echo_server` — TCP echo, 改 callback 即可挂 `wifi_rx_push()`
  - `lwip_tcp_perf_server` / `_client` — 吞吐测量基线
  - `lwip_udp_perf_server` / `_client` — UDP burst 测量
- 集成步骤:
  1. Vitis: Domain → BSP Settings → 勾 `lwip213` → save
  2. 复制 `lwip_echo_server` 的 `main.c` / `echo.c` 到 hello_world/src/
  3. 把 `tcp_recv` callback 体改成调 `wifi_rx_push(p->payload, p->tot_len)`
  4. 主循环加 `wifi_poll_frame()` 调用 (跟 `uart_poll_frame()` 并列)
  5. PWFR magic 自动分流, 旧 PMSH/PPCL 路径不变
- 实测吞吐: 期望 10-30 MB/s (gigabit GEM0 理论 100 MB/s, lwIP socket overhead 拉到 20-30%)

---

## 7. Tradeoff 分析

### 7.1 WiFi vs USB3 vs PCIe

| 链路       | 吞吐         | 鹿小班可用? | 备注                              |
|------------|--------------|-------------|-----------------------------------|
| WiFi 11n   | 20-50 MB/s   | 待硬件      | 移动方便, 多客户端, 延迟 5-20 ms  |
| WiFi 11ac  | 80-200 MB/s  | 不支持      | 需要 ESP32-S3 或更贵模块          |
| USB3 (PL)  | 250 MB/s     | PL 无 PHY   | 鹿小班 PL 不引出 USB3             |
| PCIe       | 500 MB/s     | 鹿小班无    | 7020 太小                         |
| 直 GEM0 千兆 | 100 MB/s   | 是 (硬件 BUG) | 修 BD 后即可, 见 phase 9-C       |

**结论**: 千兆以太网 (GEM0) 是最实际的 100 MB/s 解, WiFi 是 fallback / 移动场景. 两者都不够 180 MB/s 整帧, 因此 cache + delta 是协议核心设计.

### 7.2 TCP vs UDP

- TCP 在 ESP32 桥阶段够用 (吞吐瓶颈在 UART)
- UDP 在直 GEM0 阶段必须用, 否则 30 Hz 实时 delta 跑不动
- **推荐双轨**: TCP:8080 走控制 + 大对象一次性传输; UDP:8081 走 30 Hz 实时帧

### 7.3 CRC32 vs 简单 checksum

- WiFi 自带 802.11 FCS, 但 ESP32 桥 + UART 中转时 UART 端会引入误码
- CRC32 (zlib) 板端约 100 cycle/byte (软件), 5 KB delta = 500 KB cycles @ 666 MHz ≈ 0.75 ms ⇒ 可承受
- 后期可走 Zynq PS 的 SHA/CRC 加速器 (XCsuDma) 若 7020 有

---

## 8. Open questions

1. ESP32 + UART 921600 实测能否稳定跑 30 Hz `MSG_PHASE`? 或需升 baud (3 Mbaud Zynq UARTPS 支持)?
2. 板端 voxel cache 静态分配 256³ = 16 MB, DDR 富余 (512 MB), 但 cache coherency: PL DMA 写 ring 时 ARM 的 voxel cache 会脏, 走 UNCACHED 区还是软 invalidate?
3. PWFR 头跟现有 PMSH/PPCL 共存策略: board 看头 4 字节 magic 自动分流 (PWFR vs PMSH vs PPCL), 已在 stub 实现.
4. WiFi 模块占用鹿小班什么引脚? SDIO 用户已划给 wifi → 见 `reference_luxiaoban_mio_pinout.md`, MIO40-45/47 可走 SDIO 接 WiFi 模块 (e.g. AP6181). 但当前优先级是 ESP32 桥 (外置).

---

## 9. 参考文件

- `host/wifi_stream.py` — 主机端 framework (本 PR 新增)
- `02_hello_zynq/vitis_ws/hello_world/src/wifi_recv_stub.c` — 板端 stub (本 PR 新增)
- `esp32_bridge/firmware/main/pov_bridge.c` — ESP32 桥固件 (已有, 等硬件)
- `host/mesh_proto.py` (在 `experiment/triangle-mesh`) — PMSH 现有 wire
- `host/pointcloud_proto.py` — PPCL 现有 wire
- `02_hello_zynq/vitis_ws/hello_world/src/helloworld.c::uart_poll_frame()` — 现有板端 RX 状态机
