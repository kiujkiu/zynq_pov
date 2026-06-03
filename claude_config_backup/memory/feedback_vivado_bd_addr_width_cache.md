---
name: Vivado BD module_ref AXI ADDR_WIDTH 顽固缓存到 xci, 必须 rename module + 删 cache
description: 改 PL IP 的 s_axi_awaddr port width 后 BD 不重 parse, 一直按旧 port width elaborate. 8 个 build 白跑直到 rename module 强制 fresh
type: feedback
originSessionId: 37686ade-ae15-4bcf-a387-f01c094bd546
---
**规则**: Vivado BD `module_ref` 把 PL IP module port 描述缓存到 `<bd>/ip/<inst>/<inst>.xci`. 修改 module source 文件后, 各种重新加载方法都失败:

- `add_files` 重新加 PL IP 文件 → 没用
- `update_compile_order` → 没用
- `delete_bd_objs` + `create_bd_cell` → 没用 (cell 名变 _N+1 但 cache 复制过去)
- `set_property CONFIG.ADDR_WIDTH 16` 在 intf pin → 没用 (PROTOCOL/ADDR_WIDTH 是 read-only derived)
- 直接 sed 改 xci JSON 把 size_left 4 → 15 + ADDR_WIDTH 5 → 16 → `make_wrapper -force` 重新生成 wrapper 时又改回 5
- `update_module_reference <cell>` → Tcl error (syntax 不稳)

**唯一 work 的解**:
1. **Rename module** in PL IP `.v` 文件 (e.g. `hub75e_panel_seq` → `hub75e_panel_seq_v2`)
2. **删整个 BD ip cache 目录**: `rm -rf <bd>/ip/*<old_inst>*/` 跟 `<bd>.gen/ip/*<old_inst>*/`
3. Tcl 重 `create_bd_cell -reference <new_module_name>` 让 Vivado 看作完全新 module
4. 强制 fresh elaborate port info from source

**症状**: PL IP source 改 `[15:0] s_axi_awaddr` 但 BD wrapper synth 出来还是 `[4:0]`. 高地址 bit 直接接 GND. ARM 写 0x40028000 时 IP 只看到 awaddr=0x00 (低 5 bit). 任何 address-decode logic (例如 `cur_aw_addr[15]`) 永远 0.

**Debug 路径**: 加 `fb_we_count` 计数 AXI W handshake. 如果只 count 任何 W 都涨说明 AXI 到 IP. 加 last_fb_wdata sample 跟特定 addr decode 比较: 如果 last_fb_wdata 永远 0 即使 ARM 写非零, 那 addr decode 拦截了写入 (fb_top_we_main 永远 0). 看 generated wrapper `<bd>.gen/sources_1/bd/<bd>/ip/<inst>/synth/<inst>.v` 看实际 port width.

**相关**: `feedback_vivado_bd_module_ref_update.md` 提了类似问题但是改 xci JSON 方案, 这里说明 xci 改完会被 make_wrapper 覆盖, 必须 rename module.

**调试时间**: 2026-06-01 花 8 个 build (~1 小时) 才定位.
