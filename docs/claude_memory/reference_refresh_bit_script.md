---
name: Vitis bit 缓存同步脚本 refresh_bit.sh
description: 每次 Vivado 重新 Export Hardware 后，把新 bit 刷到 Vitis 工程里所有缓存副本，避免 BSP 是新的但 Run 下载的还是旧 bit
type: reference
originSessionId: bafc105a-a8db-471f-ae33-42571927b4da
---
**位置**: `/mnt/d/workspace/zynq_pov/tools/refresh_bit.sh`

**用法**:
```bash
bash /mnt/d/workspace/zynq_pov/tools/refresh_bit.sh /mnt/d/workspace/zynq_pov/02_hello_zynq
```

**什么时候用**:
Vivado Export Hardware 之后，Vitis 里 Switch XSA + Clean + Build 完 platform（xparameters.h 已经包含新 IP）。这时 run 到板子上程序还炸 → 因为 Vitis 不会自动把新 XSA 里的 bitstream 刷进 `hello_plat/hw/*.bit` 和 `hello_world/_ide/bitstream/*.bit`。脚本就是干这个的。

**为啥存这里**:
用户 2026-04-21 的 HDMI 调试过程中，明明 xparameters.h 里 XPAR_V_TPG_0 都有了，Run 时板子还 data abort，就是因为 Run 配置里下载的 bit 是更早的 LED-only 版本。手动 cp 过一次搞定，但以后类似场景还会遇到，脚本化一劳永逸。

**触发**:
用户说"新 XSA 已导出"或 Vivado Bitstream 完成 + Export Hardware 之后，跑一次这脚本就对了。
