---
name: 跨架构 codec 基准套件 bench_codec (riscv64/aarch64/arm/x86)
description: dr1v90/bench/, 一个二进制四架构全静态, 用同一真实帧对比换平台前后的解码能力
type: reference
---

2026-08-05 为 DR1 换平台决策做的。位置 **`D:\claude_workspace\pov3d\dr1v90\bench\`**。

## 为什么要它

[[reference_anlogic_dr1_fs03_eval]] 的结论是"PL 无风险，风险全在 PS"，而 PS 侧最能证伪的
单点就是**单核解码速度够不够**。这件事**不需要 TD、不需要 license、不需要下载器**，
板子一通电就能做 ⇒ 应该排在所有工具链工作之前。

## 内容

- `bench_codec.c` — 自包含，无 `/dev/mem` 依赖。测 memcpy / xor / crc32 /
  zlib enc+dec / lz4-HC9 enc+dec，各跑 N 轮取中位数，最后直接给
  "本机 lz4_dec = X MB/s ⇒ 单核可支撑 Y fps ⇒ 过线/不过线"。
- `Makefile` — `make riscv64|aarch64|arm|x86|qemu|kit`。
  每个架构自动 curl zlib 1.3.1 + lz4 1.10.0 源码交叉编译静态库到 `deps/<arch>/`
  (与 `stream/board/Makefile` 同一套做法，理由见那里)。全部 `-static`
  —— DR1 出厂是 Buildroot/busybox，没开发包也没匹配 libc。
- `make kit` → `_kit/`(三个板端二进制 + `frame_0000.bin` + README)，可直接 pscp/TF 卡上板。

## 关键细节

- **基准帧固定用 `mlkpai_fs03/stream/pc/frames_robot/frame_0000.bin`** (4,423,680 B)。
  解码速度强依赖帧内容(压缩比越高解码越接近 memcpy)，换模型数字就不可比。
  实测该帧 zlib-6 = 35.1× / lz4-HC9 = 33.7×，与历史账吻合。
- **crc32 是跨架构自检**：四个架构都必须打出 `crc=0x7902c2a5`，不一致说明数据或编译有问题。
- RISC-V 用 `-march=rv64gc -mabi=lp64d` —— 出厂 dtb 是 `rv64imafdc`(**无 B 无 V**)，
  开 `rv64gcb` 之类板上会非法指令。
- WSL 里 `qemu-riscv64`/`qemu-aarch64` 已装，`make qemu` 可先验证正确性
  (**速度数字无意义**，qemu 下 riscv 反而"比" aarch64 慢，纯翻译开销)。
- 交叉编译器: `gcc-riscv64-linux-gnu` / `gcc-aarch64-linux-gnu` / `gcc-arm-linux-gnueabihf`
  (apt 装，本机已装)。⚠ **FD 自带的 `aarch64-none-elf` / `riscv-none-embed-gcc` 是裸机 newlib，
  编不出 Linux 用户态程序**，别用错。

## 已测基线 (2026-08-05)

Zynq-7020 A9 @667MHz 单核，见 [[feedback_decode_bandwidth_halves_under_display_load]]:
**空载 lz4_dec 215.2 MB/s / 带载 111.8-130.9 MB/s**。30 fps 门槛 132.7 MB/s。
DR1 板起来后跑同一套，**必须同工况对比**。

## 板上跑法

```bash
IP=$(mlkpai_fs03/tools/board_ip.sh)
"/mnt/c/Program Files/PuTTY/pscp.exe" -pw root -batch -hostkey SHA256:u14U8c0RuKnVinQuaGH5ey6OKScaPOlRF3vMNqSnEGI \
    _kit/bench_codec_arm _kit/frame_0000.bin uisrc@$IP:/tmp/
"/mnt/c/Program Files/PuTTY/plink.exe" -ssh -pw root -batch -hostkey SHA256:... uisrc@$IP -m <win路径>\cmds.sh
```
多条命令必须写成脚本用 `-m` 传 (见 [[reference_fs03_board_access]])。
