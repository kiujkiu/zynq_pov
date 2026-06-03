---
name: 4× pov_project_batch IP 并行会破坏 HDMI 输出
description: 4 个 IP solo-fire 验证 OK, 但同时 fire_all 会让 HDMI 显示彩色噪点 grid. 单 IP 才正常.
type: feedback
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
zynq_pov 项目 USE_PL_4X=1 已知 regression: 4 个 pov_project_batch IP 同时 fire 会让 HDMI 12×6 grid 输出变成彩色噪点。但单独触发 (solo-fire) 每个 IP 都能正常 DONE, 渲染时间一致 (polls ~8433)。helloworld.c:845-846 历史注释也明确写过 "Single pov IP only ... future re-enable when 4-IP doesn't break HDMI"。

**已验证不是的原因**:
- BD 接线: tcl query 4 个 IP 的 ap_clk/ap_rst_n/s_axi_control/m_axi_gmem0+1 + 地址段全部正确
- AP_DONE 等不到: 修过的 clear-on-read latch bug 已修, wait_all 现在能正确等到 done
- 寄存器读写: 4 个 IP base 都能 AXI-Lite 读写 (sanity test 全部 OK)
- IP 个体正确性: solo-fire 4 个全部 DONE 时间一致

**最可能根本原因 (未验证)**:
- axi_smc_pov_hp NUM_SI=8 (4 IP × 2 m_axi) 合并到 HP1 master, 多 IP 同时突发写时 SmartConnect 仲裁可能丢/乱序写
- Cache 一致性: 4 个 IP 通过 HP1 写 ring buffer, CPU 后续 DCacheInvalidateRange 可能在 HP1 write FIFO 还没排空时就读, 看到部分旧数据
- 或者 IP m_axi gmem0 (model 读) 和 gmem1 (ring 写) 通过同一 SmartConnect 时 read/write 优先级竞争

**Why:** 4× IP 是 zynq_pov 渲染加速主路, 但 60 FPS 跑出来 HDMI 显示坏掉, 没意义。退回 1× IP 30 FPS 是当前唯一可用配置。

**How to apply:** 任何时候 `USE_PL_4X=1` 都默认会破坏 HDMI。要彻底修需要从 AXI smc 仲裁/HP1 write FIFO drain/cache 一致性三个方向系统排查, 不是简单 patch。优先把单 IP + 其他瓶颈 (WiFi/SDIO/CPU memcpy) 先做完, 4× IP 留到上 LED 之前再回来。
