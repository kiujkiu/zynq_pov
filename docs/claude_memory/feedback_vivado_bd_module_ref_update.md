---
name: Vivado BD module_reference cell 端口加不上时直接改 xci JSON
description: 给 RTL 加新 port 后, update_module_reference 经常失败 (没报错就退出), 手改 xci 的 boundary.ports + bd 的 nets/ports 块, 然后 generate_target + make_wrapper 能成
type: feedback
originSessionId: 42b483be-17d4-4bd8-9194-41c6b8158af7
---
新加 row_out port 到 led_panel_seq.v 后, 想 Vivado BD 中已有的 cell instance pick up 新端口. `update_module_reference` 在 2024.2 batch mode 反复失败 (没报错, 直接退出脚本), delete+recreate cell 也触发 "Could not create slave interpreter rodin:slave2" 内部错误.

**Why**: Vivado 2024.2 IP 缓存机制有 bug, RTL 改动后 IPI metadata 不自动刷新. ipx::module 元数据缓存在 `<proj>.srcs/.../ip/<cell>.xci` 文件里, 必须手动改.

**How to apply (直接改 JSON, 跳过 update_module_reference)**:
1. Verilog 改完, RTL 文件已有新 port
2. 改 `<proj>.srcs/sources_1/bd/<bd>/ip/<bd>_<cell>_0/<bd>_<cell>_0.xci`:
   - 找 `"boundary": { "ports": { ... } }` 块
   - 加新 port: `"row_out": [ { "direction": "out" } ]`
3. 改 `<proj>.srcs/sources_1/bd/<bd>/<bd>.bd`:
   - 找 ports 块 (大约 line 339 那种, 看 panel_seq_dclk 邻近), 加新 external port
   - 找 nets 块, 加新 net 把 cell pin 连到 external port:
     ```
     "led_panel_seq_0_row_out": { "ports": [ "led_panel_seq_0/row_out", "panel_seq_row" ] }
     ```
4. 跑 tcl: `open_bd_design` + `validate_bd_design` + `save_bd_design` + `generate_target all` + `make_wrapper -import -force`
5. 重新 synth: `reset_run synth_1` + `reset_run impl_1` + `launch_runs impl_1 -to_step write_bitstream`

完整工作脚本: `tools/bd_connect_row.tcl` (验证过 2026-05-22)

注: 改 `.gen/.../ip/.../<cell>.xml` 那个文件没用 — Vivado 不读它, 只读 .srcs 下的 xci.
