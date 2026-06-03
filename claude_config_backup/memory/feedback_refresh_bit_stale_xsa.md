---
name: refresh_bit.sh 读 stale xsa, 烧错 bit 一整下午
description: refresh_bit.sh 读 02_hello_zynq/*.xsa 但 Vivado 写 ../hello_plat/hw/*.xsa, 两个不同 xsa, 默默烧老 bit 导致新 IP 永远 dead
type: feedback
originSessionId: 37686ade-ae15-4bcf-a387-f01c094bd546
---
**踩坑**: `refresh_bit.sh <proj>` 从 `$proj/*.xsa` 读 xsa, 但当前 Vivado 流程 (`hub75e_bcm_build.tcl` 等) `write_hw_platform` 写到 `../hello_plat/hw/hello_zynq.xsa`. 两个 xsa 是 **不同位置**:

- `02_hello_zynq/02_hello_zynq.xsa` ← refresh_bit 读这里 (可能 stale)
- `hello_plat/hw/hello_zynq.xsa` ← Vivado 实际写这里 (fresh)

如果 02_hello_zynq/ 里那个老 xsa 没人清, refresh_bit 一直 copy 老 bit 到 vitis_ws, **xsdb dl 烧的是老 bit, 新 IP 不在里面 → AXI write DECERR**.

**症状**: 改 BD 加新 IP 后, xsdb mwr 新 IP 地址永远 "AHB AP transaction error DAP status 0xF0000021" 或 "Memory write aborted Fault status 0x8". 其他老 IP 全部 OK. 排查 timing/MMCM/CLK_DOMAIN/reset 都查不出问题, 因为问题不在新 build, 在烧的是老 bit.

**Debug 标志**: 烧完 bit 后 xsdb mrd 那个新 IP 基址永远报错, 但 0x40000000 / 0x41200000 / 0x43C00000 等老 IP 都能读. 这时检查 `ls -la <proj>/*.xsa ../hello_plat/hw/*.xsa`, 看两个时间戳是否一致.

**Fix**: 烧 bit 前先 `cp ../hello_plat/hw/hello_zynq.xsa <proj>/02_hello_zynq.xsa`, 再跑 refresh_bit. 或者改 refresh_bit 读那个 hello_plat/hw/ 路径.

**调试时间**: 2026-06-01, 跑 v26/v26b/v27 三个 build (~25 min) + xsdb 跑了 5-6 次都 dead, 最后才发现是 stale xsa.
