---
name: project_dr1m90_gp0_first_light
description: 2026-09-22 DR1M90 GP0 首次点亮 (WS1 核心里程碑) — 用现有 RISC-V PS 封装(未重做 ARM PS!) + bootgen -arch dr1m90 出 bin, configfs overlay 加载 conn_rx.bin 一次成功; SRST_CTRL2 加载后 0x1100->0x1133(bit4 GP0M 复位放开, 与 DR1V90 OpenSBI 行为一致, ATF 头号风险排除); GP0 MAGIC/VERSION/SCRATCH/未映射全部正确, 零 CPU 挂死
metadata:
  type: project
---

# DR1M90 GP0 首次点亮 (2026-09-22, WS1)

延续 [[project_dr1m90_base_bringup]] 的只读核查, 当天继续做到**实际加载 PL + 读 GP0 成功**。
移植清单 [[project_dr1m90_jtag_port_checklist]] 预判的多个"未知风险"在这次实测里都有了答案。

## 🎯 关键结果: 比清单预判的乐观得多

1. **不需要重做 ARM PS 封装** —— 清单原判断"大概率要生成 ARM_Processor_System 封装"。
   实测: **只把 `B2B_DEVICE=DR1M90GEG484` 传给 TD, 现有 RISC-V PS IP 封装原样综合布局布线通过**,
   `dr1v90/lvds_b2b/build.sh conn_rx` 直接出 bit, 零改动 RTL/封装。
   ⇒ **PS IP 底层对 ARM/RISC-V 版共用同一原语 `DR1_PHY_PROCESSOR_SYSTEM`**(清单里猜过这条,
   现在是实测证据) ⇒ 移植清单里"必须等显示 PL 移植"那节的 PS 封装顾虑大幅降低, 至少对
   **不需要 ARM 专属外设(ACP/PPI/trace)** 的简单工程不构成阻塞。

2. **bootgen `-arch dr1m90` 一次成功** (`build.sh` 已改成按 `$DEVICE` 自动选 `-arch`,
   `*M90*` → `dr1m90`, 否则 `dr1v90`; 可用 `B2B_BOOTARCH` 覆盖)。

3. 🔴 **头号风险(SRST_CTRL2 bit4)排除**: 加载前 `0x00001100`(bit4=0, 与冷启动 DR1V90 相同),
   **fpga_manager 编程成功('fpga prog successfully', state=operating)后自动变成 `0x00001133`**
   (bit4=1 已放开; 低字节 0x33 = GP0M/GP1M/HP0/HP1 全放开, 与 DR1V90 上 OpenSBI 的行为完全一致)。
   `PLS_PROT` 同步从 `0x00000003` → `0x00000000`。
   ⇒ **DR1M90 的 ATF 在 PCAP 加载 PL 时做了和 DR1V90 OpenSBI 相同的事**, 不需要任何手动
   读改写置位的兜底代码(清单原来写的"碰 GP0 前必须先读改写置 bit4"现在证明不需要, 但仍应
   保留读判据作为安全网 —— 万一某次加载路径不同)。

4. **GP0 读写全部正确, 零挂死**:
   ```
   MAGIC   [0x80000000] = 0x42324200   ("B2B\0", 精确匹配 conn_rx.bin 的寄存器块)
   VERSION [0x80000004] = 0x00010630   (v1 NLANE=6 NSTEP=48)
   SCRATCH 写 0xA5A5F00D 读回一致
   未映射  [0x80000FFC] = 0xDEADBEEF   (总线不挂死, RRESP OKAY 设计生效)
   ```

## 实测细节 / 坑

- **出厂 buildroot 没自动挂 configfs**: `/sys/kernel/config/device-tree/overlays` 一开始不存在,
  `mount -t configfs none /sys/kernel/config` 一挂就出现。DR1M90 版加载脚本开头要加这一步
  (DR1V90 pov 镜像大概率已在 init 里挂好)。
- **dtbo 里的 `firmware-name` 是写死的**(`b2b_load.dts` 写死 `b2b.bin`), 固件必须放在
  `/lib/firmware/<那个名字>`, 名字不对 fpga_manager 会报 `-2 firmware request error`
  (**这个失败是干净的, fpga0 state 显示 "firmware request error" 不是 operating, 没有碰 GP0,
  也没有挂死** —— 验证了"加载没确认成功前绝不碰 GP0"这条设计在 DR1M90 上同样生效)。
- **本地用 `dtc -@ -I dts -O dtb` 编译 dtbo 再推 board, 不依赖板上有 dtc**
  (DR1M90 出厂 buildroot 没带 dtc, `which dtc` 空)。
- overlay 目录一旦创建过(哪怕失败), 下次要用前先 `rmdir` 清空, 否则 `cp dtbo` 报 `File exists`。

## 用的位流

`dr1v90/lvds_b2b/` 的 `conn_rx`(走马灯连通性测试位流, 挂 `b2b_sys` GP0 寄存器块) ——
选它只是因为它是现成的、带 GP0 从机的最小工程, 不是要在 DR1M90 上做连通性测试
(那需要两块板对插 CEP1, 本次只有一块 DR1M90 在手)。`out/conn_rx.bin` md5 `b37e23c4…`。

## 下一步

- WS1 台架/JTAG 那条线(`jtag_load/`)可以按同样的模式移植: 只换 `B2B_DEVICE`/器件串 +
  bootgen arch, 大概率不需要重做 PS 封装。
- 可以正式确认: **移植清单里"必须等显示 PL 移植"那一节的顾虑对本工程(无 ACP/PPI/trace 依赖)
  不成立**, 可以直接推进 WS1 的下一步(JTAG 加载线 / bridge_load 移植)。
- 下一步验证: 板端脚本(`load_b2b.sh`/`load_pl.sh` 等)加 `uname -m` 判断自动挂 configfs +
  自动选 firmware-name, 而不是手动摆弄 overlay 目录。

相关: [[project_dr1m90_base_bringup]] [[project_dr1m90_jtag_port_checklist]] [[project_pov3d_lvds_b2b_bench]]
