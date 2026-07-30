---
name: aibrain-app 项目 — PC 侧 3D Viewer + PVS1 推流 (与 POV 同一条链)
description: pov-yjhh/aibrain-app; RK3588+NPU 目标但有纯软件 Docker demo; pvs_streamer.js 已实现滑动窗口
type: reference
---
`https://github.com/pov-yjhh/aibrain-app` — "Airbrian — RK3588 3D Viewer + Audio + Camera with NPU Face Detection"。
2026-07-30 clone 到 `/mnt/d/claude_workspace/pov3d/aibrain-app`。

## 🔴 与我们 POV 工作是同一条链, 不是独立项目

- 子模块 `reference/mlkpai_fs03` 直接指向我们的仓库 (branch `feature/icnd2047-dual-panel`)
- `server/pvs_streamer.js` — **PVS1 协议推流器**, 注释写明 "from mlkpai_fs03 reference",
  同样的 16B 头 + zlib + 360片×0x3000 + `offset = lane*1296 + row*24 + word*4`
- `server/mock_board.py` — PVS1 mock 接收端 (:9500), 可替代真板做回环测试

另一个子模块 `reference/catstudio` 指向内部 GitLab (`git@gitlab.undef.world`), clone 会失败,
**用户确认不重要, 不影响运行**。

## 🔴 pvs_streamer.js 已经实现了滑动窗口 — 我重复劳动了

文件头注释与我 2026-07-30 在 `povstream.py` 独立推导的结论**完全一致**:
"window=N allows up to N frames in flight... N=2 returns as soon as K-1 is ACKed,
so board processing of frame K-1 overlaps the transmission of frame K.
Board-side change: none (kernel recv buffer absorbs the extra frame)"

实现差异 (可互相借鉴):
- Node 侧用**序号阈值** `seq ≤ _ackedSeq + window - 1` (`_drain()`), 乱序/重连时更好推理
- 我的 Python 侧用 `_inflight` deque 长度, 但**多了收尾排空** `_drain_inflight()`;
  Node 侧未见对应逻辑, 流结束时最后 window-1 帧的 ACK 可能无人接收 (待验证)
- 入口: `new PvsStreamer(host, port, { window })`, 默认 1 = stop-and-wait

⚠ **教训**: 这是同一天第二次"没先搜现有实现就动手"(上午是没扫 `stream/` 目录,
见 [[reference_pov_wifi_streaming]])。动手前先全仓搜关键词。

## Docker 运行 (纯软件 demo, 不需要摄像头/NPU/音频)

```bash
cd aibrain-app && docker compose up --build     # → http://localhost:9070
```
镜像 `node:20-bookworm-slim` + python3/numpy; Node 依赖仅 three/jpeg-js/pngjs。
`infra/docker-entry.sh` 起两个进程: `node pc_server.js`(:9071, Three.js 骨骼蒙皮) 就绪后
再起 `python app.py --port 9070 --camera -1 --no-audio`(硬件全关)。

## ✅ 本机已跑通 (2026-07-30)

```
浏览器 http://localhost:9070      容器 aibrain-app-airbrian-1  Up (healthy)
```
启动日志关键行:
```
[pc_server] bake fps=26 zlib=6 maxModels=3 pvsWindow=2      ← 默认就开窗口=2
[pc_server] loaded steve.glb: 288 verts, 300000 surface samples, 2 clip(s)
[pc_server] baked clip 0 "Skeleton|Idle": 129 frames / clip 1 "Skeleton|Walking": 16 frames
[pc_server] bake complete in 11.6s
```
🔴 **`pvsWindow=2` 默认开启** — Node 侧早就在用滑动窗口, 而我们 `povstream.py` 直到
2026-07-30 才加上且默认仍是 1 ⇒ 一直跑 stop-and-wait。这解释了实测帧率上不去。
`bake fps=26` 也说明它按 26 fps 目标设计, 与 `04_sw_stream_26fps.md` 一致。

## 装 Docker 与启动 (本机 Ubuntu 26.04 resolute / amd64 / 无 systemd)

装机脚本 `/mnt/d/claude_workspace/pov3d/setup-docker.sh`。装到 Docker 29.6.2 + compose v5.3.1。
⚠ Docker 官方源无 resolute 仓库 → 脚本回退用 noble(24.04) 源, 二进制兼容。

🔴 **两个必须记住的坑:**

**① SysV 脚本在 WSL 下起不来 dockerd**
`/etc/init.d/docker:62 ulimit: error setting limit (Invalid argument)`, 且 systemctl 是 offline。
绕过它直接起 (2 秒就绪), **每次重开 WSL 都要跑一次**:
```bash
sudo sh -c 'nohup dockerd --host=unix:///var/run/docker.sock > /var/log/dockerd-manual.log 2>&1 &'
```

**② CRLF 导致 `exec /entry.sh: no such file or directory`**
Windows 侧 `core.autocrlf=true`, clone 时把 **11 个 .sh** 全转成 CRLF,
内核把 `#!/bin/bash\r` 整个当解释器路径找 ⇒ 容器起来就退。**不是项目 bug, 是 clone 环境造成的。**
```bash
for f in $(find . -name "*.sh" -not -path "./node_modules/*" -not -path "./.git/*"); do
    sed -i 's/\r$//' "$f"; done
```
⚠ 只修了 WSL 副本 `~/aibrain-app`; `/mnt/d/.../aibrain-app` 那份**仍是 CRLF**, 从那边构建会再撞。

⚠ 构建位置: 仓库在 /mnt/d 走 9P 跨界访问很慢, 已 `cp -r` 到 `~/aibrain-app` 再 build (300MB, 4.7s)。
`.dockerignore` 已排掉 reference/ docs/ ai/models/ .git/ node_modules/ 等大件。
