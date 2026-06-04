---
name: 鹿小班 SDIO WiFi 升级方案 (Linux + RTL8822CS)
description: LXB Zynq 7020 + PetaLinux + RTL8822CS SDIO WiFi 飞线方案, 200 Mbps SDIO 上限可接受, 取代 ESP32 SDIO 桥
type: project
originSessionId: b3c27305-3e71-472d-bb43-6bae56fdaada
---
日期：2026-06-01 锁定方案

## 需求 + 决策

- 后续扩展需要 200 Mbps 接口 + WiFi 300+ Mbps link rate
- Zynq 7020 PS SDHCI 不支持 UHS-I, **SDIO 实测顶 200 Mbps (50MHz × 4-bit)**
- 用户接受 200 Mbps SDIO 上限, WiFi 链路 867M 当余量
- 200M 扩展接口走 GEM0 千兆以太网分流

## 选定芯片

**RTL8822CS** (AW-CB375NF 模组，淘宝 ¥60-100)
- 11ac 2×2, link rate 867 Mbps
- SDIO 3.0 接口
- Linux mainline `rtw88_8822c` driver
- 备选：AP6398S (BCM4359, brcmfmac 更稳但贵)

## 硬件连接 (SD1 EMIO 出 GPIO1/2)

```
Zynq SD1 EMIO          AW-CB375NF
SD1_CLK     ──────►   SDIO_CLK
SD1_CMD     ◄────►   SDIO_CMD
SD1_DAT0-3  ◄────►   SDIO_DAT[0:3]
PL GPIO     ──────►   WL_REG_ON (enable, 拉高)
3.3V                   VBAT
1.8V                   VDDIO  ⚠ 需 TXS0108E 电平转换 (IO 1.8V)
GND
```

**注意**：模组 IO 是 1.8V，Zynq BANK33/35 是 3.3V，必须加电平转换或选 3.3V IO 版本。

## 软件 (PetaLinux 2024.2 — 匹配本机 Vivado 2024.2, 2026-06-04 修正)

Kernel config：
```
Device Drivers → Network → Wireless →
  Realtek 802.11ac wireless chips support (rtw88)
    Realtek 8822C SDIO support
```

Device tree (SD1 节点)：
```dts
&sdhci1 {
    status = "okay";
    bus-width = <4>;
    max-frequency = <50000000>;
    non-removable;
    rtw88_wifi@1 {
        compatible = "realtek,rtw8822cs";
        reg = <1>;
    };
};
```

Firmware：`/lib/firmware/rtw88/rtw8822c_fw.bin`

## 调测顺序

1. 1-bit SDIO @ 25 MHz 识别 WiFi 芯片 (`mmc` 命令)
2. 4-bit @ 25 MHz 测 iperf3 ~50 Mbps
3. 升 50 MHz 调 IDELAY tap, 目标 100-150 Mbps 实测
4. 端到端跑 anime stream

## 取代关系

- 替代当前 ESP32-C5 SDIO 桥 (`project_pov3d_wifi_data_path_live.md`, 100 KB/s 上限)
- ESP32 飞线接口可复用，只换远端芯片
- Linux 标准网络栈 (wpa_supplicant + iperf3), 不用自己写 parser daemon

## 后续升级路径

- LXB 板硬件上限就是 200 Mbps SDIO real
- 若需 300+ Mbps system throughput, 必须换 Zynq UltraScale+ (ZU2CG/ZU3EG), PS SDHCI 支持 UHS-I SDR104 (400 Mbps real) + USB 3.0/PCIe
