---
name: Vivado 批处理脚本自动化
description: 从 WSL 通过 cmd.exe 调用 Windows Vivado 批处理模式，跑 Tcl 脚本修改 BD + 生成 bitstream + 导出 XSA
type: reference
originSessionId: bafc105a-a8db-471f-ae33-42571927b4da
---
**路径**：Vivado 安装在 `D:\Vivado\2024.2\bin\vivado.bat`，WSL 能通过 cmd.exe 调用

**必备条件**：
- 用户**先关闭 Vivado GUI**（同一 .xpr 不能两个实例打开）
- 工作目录必须是**Windows 路径**（用 `cd /d D:\...`），不能是 WSL 的 `/mnt/...` 路径（会报 CRITICAL WARNING 17-183 写不了日志）

**标准调用模板**：
```bash
rm -rf /mnt/d/workspace/zynq_pov/tools/logs/.Xil /mnt/d/workspace/zynq_pov/tools/logs/*.log /mnt/d/workspace/zynq_pov/tools/logs/*.jou /mnt/d/workspace/zynq_pov/tools/logs/*.out 2>/dev/null
cmd.exe /c "cd /d D:\\workspace\\zynq_pov\\tools\\logs && D:\\Vivado\\2024.2\\bin\\vivado.bat -mode batch -source D:\\workspace\\zynq_pov\\tools\\<script>.tcl -log vivado.log -journal vivado.jou -notrace" > /mnt/d/workspace/zynq_pov/tools/logs/cmd.out 2>&1 &
```

**用 run_in_background:true** — Synth+Impl+Bitstream 要 5-10 分钟，用 ScheduleWakeup 调 540-600 秒回来看结果

**关键 Tcl 习惯**：
- `connect_bd_net` 要么两个 pin 要么一个 pin+一个 net。`get_bd_nets -of_objects` 有时返回空，保险起见用 **两个 pin** 形式
- `validate_bd_design` 遇到 Critical Warning 会 throw exception → 用 `catch {validate_bd_design} e` 包住
- 修改 `CONFIG.NUM_MI` / `NUM_CLKS` 之后，对应 pin 才会出现，引用前确认
- 删连接要用 `delete_bd_objs [net]`，不是 `disconnect_bd_net`（后者只断某个 pin，net 本体还在）
- SmartConnect 砍 MI 后对应地址段也要手动删：`delete_bd_objs [get_bd_addr_segs /path/SEG_xxx]`
- `assign_bd_address -offset <addr> -range <size> [seg] -force`

**End-to-end 一把流**（我常用的）：
1. 写 TCL 修改 BD
2. `bash refresh_bit.sh <proj_root>` 刷 Vitis 缓存
3. 用户只需 Vitis Switch XSA + Clean + Build Platform + Build App + Run
