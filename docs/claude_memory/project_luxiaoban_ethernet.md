---
name: 鹿小班 LXB-ZYNQ7000 以太网 GEM0 + gmii_to_rgmii 配置
description: PS GEM0 以太网通过 gmii_to_rgmii IP 转 RGMII 到板上 PHY 的已验证 BD/XDC/时钟配置
type: project
originSessionId: bafc105a-a8db-471f-ae33-42571927b4da
---
**验证通过（2026-04-22）**：鹿小班板千兆以太网工作路径。

**BD 架构**（抄 vendor `HelloZynqPS_Linux_ETH`）：
```
PS GEM0 (EMIO) → GMII_ETHERNET_0 接口 → gmii_to_rgmii_0.GMII
PS MDIO        → MDIO_ETHERNET_0 接口 → gmii_to_rgmii_0.MDIO_GEM
gmii_to_rgmii_0.MDIO_PHY → external MDIO_PHY_0
gmii_to_rgmii_0.RGMII    → external RGMII_0
FCLK_CLK2 (200 MHz) → gmii_to_rgmii_0.clkin   # 必须 200 MHz 参考!
FCLK_RESET0_N → util_vector_logic(NOT) → gmii_to_rgmii_0.rx_reset + tx_reset
```

**PS 关键配置**：
```
CONFIG.PCW_EN_ENET0 = 1
CONFIG.PCW_ENET0_ENET0_IO = EMIO
CONFIG.PCW_EN_EMIO_ENET0 = 1
CONFIG.PCW_ENET0_GRP_MDIO_ENABLE = 1
CONFIG.PCW_ENET0_GRP_MDIO_IO = EMIO
CONFIG.PCW_ENET0_PERIPHERAL_FREQMHZ = "1000 Mbps"
# 给 gmii_to_rgmii 的 clkin
CONFIG.PCW_EN_CLK2_PORT = 1
CONFIG.PCW_FPGA2_PERIPHERAL_FREQMHZ = 200
```

**⚠️ 关键坑：FCLK 频率**
`gmii_to_rgmii` IP 的内部 MMCM 参数（MULT=5, DIV=1）是按 **200 MHz 输入** 算的。如果你给它 50 MHz 输入，VCO = 250 MHz 会撞 DRC [PDRC-34]（合法 600-1440 MHz）。vendor 工程能跑是因为他们 FCLK_CLK0 就是 200 MHz；我们的 FCLK_CLK0=50MHz 跑 AXI，所以另开 **FCLK_CLK2=200MHz 专门给 gmii_to_rgmii**。

**XDC 管脚（Bank 35 推测，LVCMOS33）**：
```
MDIO_PHY_0_mdc:     G21
MDIO_PHY_0_mdio_io: H22
RGMII_0_rd[0]:      A22     RGMII_0_rd[1]: A18
RGMII_0_rd[2]:      A19     RGMII_0_rd[3]: B20
RGMII_0_rx_ctl:     A21     RGMII_0_rxc:   B19
RGMII_0_td[0]:      E21     RGMII_0_td[1]: F21   (SLEW FAST)
RGMII_0_td[2]:      F22     RGMII_0_td[3]: G20   (SLEW FAST)
RGMII_0_tx_ctl:     G22     RGMII_0_txc:   D21   (SLEW FAST)
create_clock -period 8.000 -name RGMII_0_rxc [get_ports RGMII_0_rxc]
```
保存文件：`D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/constrs_1/new/eth_pins.xdc`

**util_vector_logic 配置**：`C_OPERATION=not`, `C_SIZE=1` — 把 FCLK_RESET0_N 低有效翻成高有效给 gmii_to_rgmii 的 rst 输入。

**Tcl 脚本**：
- 加 ETH：`D:/workspace/zynq_pov/tools/bd_add_ethernet.tcl`
- 修时钟：`D:/workspace/zynq_pov/tools/bd_fix_eth_clock.tcl`

**How to apply**：以后要在别的鹿小班项目里加以太网，两个 Tcl 合起来能照抄。
