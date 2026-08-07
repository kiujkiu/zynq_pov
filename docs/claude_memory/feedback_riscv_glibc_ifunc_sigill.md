---
name: RISC-V 板上 glibc 静态程序必崩 (IFUNC 选了向量版) — 必须换 musl
description: Ubuntu glibc 的 riscv IFUNC 靠 riscv_hwprobe(Linux 6.4+) 探测, 在 6.1 内核上探测失败却选了 V 版 ⇒ SIGILL; 连 hello world 都崩
type: feedback
---

2026-08-05 DR1V90G 首次上板跑 [[reference_bench_codec_kit]] 时踩的。**排查 20 分钟, 但如果不知道这条会以为是自己代码的问题。**

## 现象

```
/tmp/bench_codec /tmp/frame_0000.bin 10
Illegal instruction
[  750.9] bench_codec[267]: unhandled signal 4 code 0x1 at 0x48c00
[  750.9] Hardware name: anlogic,dr1v90 (DT)
[  750.9] badaddr: 00000000cd817057  cause: 0000000000000002
```
**程序一行输出都没有就死** —— 死在 libc 启动阶段, 不是业务代码。

## 定位: 从 badaddr 直接解码指令

`badaddr` 就是那条非法指令的**指令字** `0xcd817057`:
- `opcode[6:0] = 0x57` = **OP-V**(向量扩展)
- `funct3 = 7` → OPCFG; `bits[31:30] = 11` → **`vsetivli`**

而 DR1V90 是 `rv64imafdc` —— **无 V**。⇒ 二进制里混进了向量指令。

## 根因

Ubuntu 的 `gcc-riscv64-linux-gnu` (glibc 2.42) 对 `memcpy/strlen/...` 用
**IFUNC 运行时派发**, 靠 **`riscv_hwprobe` 系统调用**探测 CPU 扩展。
🔴 **该系统调用 Linux 6.4 才加入, 板子内核是 6.1.111-rt42** ⇒ 探测失败,
解析器却选了**向量版本**, 启动时执行到 `vsetivli` 就 SIGILL。

🔴 **`-march=rv64gc -mabi=lp64d` 管不住这件事** —— 它只约束**编译器为我的代码生成什么**,
glibc 里那些向量例程是**发行版预编译好的**, 静态链接照样进来。

**判定实验(便宜且决定性)**: 编一个最小静态 hello world 丢上去 ——
**同样崩, 且 `badaddr` 一模一样**。⇒ 与业务代码无关, 是 libc。

客观计数:
```
riscv64-linux-gnu-objdump -d bench_codec_riscv64      | grep -c '\bvset'   → 534
riscv64-linux-musl-objdump -d bench_codec_riscv64musl | grep -c '\bvset'   → 0
```

## 解法: 换 musl 静态链

musl 没有 IFUNC 运行时派发, 一份实现走到底。
工具链 <https://musl.cc/riscv64-linux-musl-cross.tgz> (gcc 11.2.1),
Makefile 里的目标是 **`make riscv64musl`**。

⚠ **工具链必须解到 WSL 原生文件系统**(本机放 `~/toolchains/`)。
放 `/mnt/d` 会失败: NTFS 大小写不敏感, 内核头 `ip6t_HL.h` 与 `ip6t_hl.h` 撞名。

副作用: musl 版只有 **215 KB**(glibc 版 721 KB), 走串口传快 3 倍。

## 🔴 由此产生的对账陷阱

换 libc 之后, **DR1 是 musl 编的而 Zynq 基线是 glibc 编的, 两组数不可直接比** ——
musl 的 `memcpy` 明显慢于 glibc 手工优化版, 而"整帧预算"里正好有一次 4.4 MB memcpy。
⇒ 跨平台对比**必须两边同 libc**(已补 `arm-linux-musleabihf` 对照组)。
`lz4_dec` 受影响小(lz4 用自己的内联拷贝循环), `memcpy`/整帧预算受影响大。
