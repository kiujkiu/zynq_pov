---
name: reference_dr1_ps_pl_enable
description: DR1 的 PS↔PL 接口默认是关的(gp_proten), 出厂 BOOT.bin 不会开; 从 Linux 用 devmem 写三个 0xF88x 寄存器即可, 不用重建 BOOT.bin
metadata:
  type: reference
---

# DR1 PS↔PL 接口要先使能, 而出厂 BOOT.bin 不会替你开 (2026-08-07 查实)

## 症状

PL 侧例化了 PS (`system_RISC_V_Processor_System_0`)、bitstream 加载成功
(`fpga0/state = operating`, dmesg 干净)、板子照常跑 —— 但从 Linux 读 PL 窗口
`devmem 0x80000000 32` 直接 **load access fault**：

```
status: 8000000200006020  badaddr: 0000000080000000  cause: 0000000000000005
```

（是干净的 fault: 只杀掉 devmem 进程, 板子不挂, 所以扫地址是安全的。）

## 根因

DR1 的 PS↔PL 接口由**软件初始化**打开, 不是 PL bitstream 打开的。
厂商 SDK 里对应 `int Soc_PsPlInit()` ——「initialize ps_pl only according to
user configuration」, 由 BOOT.bin 里的平台初始化调用。

**我们卡上跑的是出厂 BOOT.bin, 它对应的设计没有任何 PL AXI 接口**
⇒ `gp_proten` 仍然置位, GP 到 PL 的访问被保护位挡掉。

## 解法: 三个读改写, 全在 PS 控制区, Linux 里就能做

出处: `dr1v90/_demo2/07_pl_fdma_cs500/soc_hw/soc_prj.hpf`（zip）
→ `HPFs/soc_plat.c` 的 `ps_pl_0[]` 表（`Soc_PsPlInit()` 用它）：

```c
// Config PLS_PROT, gp normal acess to pl
CONFIG_REG_MASK(0xF8800080, 0x00000002, 0x00000000),  // PLS_PROT.gp_proten = 0
// Config CRG_SRST, Slave_AXI_HP0_Interface: reset release
CONFIG_REG_MASK(0xF8801078, 0x00000001, 0x00000001),  // SRST_CTRL2.nic_hp0_srst_n = 1
// Config HP_WIDTH, Slave_AXI_HP0_DATA_WIDTH: 64 bit
CONFIG_REG_MASK(0xF8800084, 0x00000001, 0x00000000),  // CFG_HP_WIDTH.wmode_hp0 = 0
```

`CONFIG_REG_MASK(addr, mask, value)` 语义 = `reg = (reg & ~mask) | (value & mask)`。

Linux 侧（busybox devmem, 见 `board/cmds_pspl_enable.txt`）：
```sh
v=$(devmem 0xF8800080 32); devmem 0xF8800080 32 $(( v & 0xFFFFFFFD ))   # gp_proten=0
v=$(devmem 0xF8801078 32); devmem 0xF8801078 32 $(( v | 0x1 ))          # hp0 解复位
v=$(devmem 0xF8800084 32); devmem 0xF8800084 32 $(( v & 0xFFFFFFFE ))   # hp0 64-bit
```

⚠ `0xF8801078` 落在 `/proc/iomem` 里 `f8801000.fpga-mgr` 声明的区间内。
devmem 走 `/dev/mem` 不检查 claim, 但若内核开了 `CONFIG_STRICT_DEVMEM` 会被拒。

🔴 **这三条重启后就没了** —— 要写进开机脚本（和 PL 加载放一起）。

## HPF handoff 里还有什么 (以后少走弯路)

`soc_prj.hpf` 是个 zip, 解开得到 `HPFs/`：
`soc_plat.c/.h`（全部平台初始化寄存器表）、`soc_plat_pl.dtsi`（PL 的 DT 片段，
demo 里是空的）、`soc_plat_dts.h`、`soc_prj.bit`、
`static/data/*.js`（clock/ddr/psio/**ps_pl**/peripheral 的寄存器视图）。
**要查任何 PS 侧配置寄存器, 先来这里, 比翻手册快。**

## 顺带确认的地址族

厂商 SDK `dr1v90_fpsoc_cpu0/driver/pl_driver/*/src/al_*_cfg.c` 里 PL 外设有**两族**地址：
- `0x8000_0000` / `0x8010_0000` / `0x8003_0000` —— 32 位族
- `0x1_C000_0000` / `0x1_F000_0000` / `0x1_F103_0000` —— **超过 4 GB**

后者正是 `master_gp0_axi_araddr` 为 **33 位**的原因。

相关：[[project_dr1_parity_plan]] [[feedback_dr1_load_bit_without_jtag]]
