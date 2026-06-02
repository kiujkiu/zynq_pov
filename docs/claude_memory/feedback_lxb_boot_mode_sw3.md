---
name: 鹿小班 LXB-ZYNQ7000 真 boot mode 拨码 = SW3
description: SW1/SW2 是 PL_KEY 用户按键无关 boot, SW3 才控制 BOOT_MODE strap. 切到 QSPI mode 需 toggle 配置.
type: feedback
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
**鹿小班 LXB-ZYNQ7000 板上 boot mode 拨码 = SW3** (不是 SW1/SW2!)

**Why**: SW1/SW2 是 PL_KEY1/PL_KEY2 用户按键, 跟 boot mode 完全无关. SW4 = PS_NRST 复位. 真正的 boot mode strap 拨码是 SW3, 旁边一群 R60-66 (10K) + R67/R68 (1K) 上拉电阻 + GND, 接 QSPI_IO0/1/2/3/CLK + MIO7/MIO8.

**How to apply**:
- SW3 是 dual SPST (2 个 toggle):
  - **Toggle 1** 控制 MIO[2,3,4,5,6] strap (= QSPI_IO0/1/2/3 + CLK)
  - **Toggle 2** 控制 MIO[7,8] strap
  - ON = strap 拉 GND (=0), OFF = 1K 上拉到 VCC3V3 (=1)
- 实测 BOOT_MODE 0x00010101 (bm[2:0]=001) = QSPI 24-bit single-SS 是 SW3 切到某种组合后 power-cycle 后读到. 具体哪个 toggle 组合给 0x1 — user 手动尝试.
- BOOT_MODE register 上电 latch, JTAG attach 不更新, 必须 power-cycle (拔电再插) 才更新.
- Default 出厂 SW3 = bm 0x2 (NAND), 板上没 NAND chip → BootROM fail-fall idle, JTAG dl 仍能用 (这是为什么默认配置用户也能调试的原因).
- QSPI boot 通过流程: SW3 切 QSPI → flash 烧 BOOT.bin (用 hello_world 含 fix qspi_flash_writer + bootgen 重打) → power-cycle → BootROM auto load fsbl + bit + elf → 完整 standalone.

**踩坑**: 我们 phase 8/9 一直误以为 S1=ON S2=OFF 是 QSPI mode, 实际 SW1/SW2 完全不影响 BOOT_MODE register. xsdb mrd 0xF8000A1C 直接读 register 才确认. 真正 boot mode 拨码必须看 schematic page 3 SW3 周边电路.
