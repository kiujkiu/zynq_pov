---
name: feedback_musl_static_pie_cjson_hooks_null
description: 🔴 入库的 riscv64 iperf3(musl.cc gcc 11 + libtool -all-static)是 static-pie, cJSON 全局 hooks 里 malloc/free/realloc 三个指针是 R_RISCV_64 符号重定位, musl static-pie 启动代码只做 RELATIVE ⇒ 一碰 JSON 就跳地址 0; --version 和监听都正常所以 file 判据抓不到; 修法 -fno-pie/-no-pie 纯静态, qemu-riscv64 回环先验
metadata:
  type: feedback
---

# 入库的 iperf3 从来就不能用 (2026-09-14 第一次上板才发现)

`dr1v90/measure/03_wifibw/out/iperf3`(08-26 建, 已进卡) —— 连 PC 那一下服务端就退出。

## 症状 (板上与 qemu 两边都复现)

| 端 | 表现 |
|---|---|
| 服务端 | `unable to receive parameters from client: Out of memory` + dmesg `__vm_enough_memory ... no enough memory`; PC 侧看到 `control socket has closed unexpectedly`, 之后全是 `Connection refused` |
| 客户端(板内回环) | `unhandled signal 11 ... epc: 0000000000000000` —— 跳到地址 0 |
| 能正常的 | `--version`、监听端口、打印 banner —— 都不走函数指针 |

## 根因

```
readelf -rW out/iperf3 | grep -v RELATIVE
  R_RISCV_64  malloc + 0
  R_RISCV_64  free + 0
  R_RISCV_64  realloc + 0          ← cJSON 的 global_hooks = { malloc, free, realloc }
```
- musl.cc 的 gcc 默认 PIE, `-static` ⇒ **static-pie**; 自重定位由 rcrt1 的 `_dlstart_c` 做, **只处理 RELATIVE**。
- 这三条是**带符号**的绝对重定位 ⇒ 永远不被填 ⇒ cJSON 分配内存时调到 0(客户端崩)或拿垃圾值(服务端报 OOM)。
- 同批的 `05_rxcap/out/rxcap` 也是 static-pie, 但只有 44 条 RELATIVE、**零条符号重定位** ⇒ 这个机制咬不到它(仍未上板验)。

## 修法 (已验证)

```bash
./configure --host=riscv64-linux-musl ... CFLAGS="-O2 -fno-pie" LDFLAGS="-no-pie -static"
make LDFLAGS="-all-static -no-pie"
# 判据: file 显示 "statically linked"(不是 static-pie), readelf -r 里 R_RISCV 条数 = 0
```
产物 176 KB, md5 `747a7b8f0d9b0c40ab8dbcad681cb39d`(strip 后)。

## 🔴 教训: 量具必须先跑一次真功能

`build_iperf3.sh` 的判据只查 `file` 里有没有 `statically linked\|static-pie` ——
**"能 exec" ≠ "能测"**。同 [[feedback_verdict_design_before_blaming_dut]]: 当时要不是先怀疑工具,
差点把"服务端退出"算到 WiFi 或板子头上。
⇒ 交叉编译的工具, 入库前**必须 `qemu-riscv64` 本机回环跑出一个完整结果**(本机 `/usr/bin/qemu-riscv64` 可用):
```bash
qemu-riscv64 ./iperf3 -s -1 -p 5299 & sleep 2; qemu-riscv64 ./iperf3 -c 127.0.0.1 -p 5299 -t 3
```
⇒ 凡是 static-pie 的产物, 先 `readelf -rW | grep -v RELATIVE` —— 有符号重定位就别用。

相关: [[project_dr1_measure_bench]] [[feedback_riscv_glibc_ifunc_sigill]] [[feedback_dr1_wifi_dongle_brownout_reboot_loop]]
