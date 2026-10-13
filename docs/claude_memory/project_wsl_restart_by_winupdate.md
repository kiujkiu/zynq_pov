---
name: wsl-restart-by-winupdate
description: "10-13 11:19 WSL 整机重启不是崩溃, 是 Windows Update 自动装 WSL 3.0.3.0 把 VM 停了"
metadata:
  node_type: memory
  type: project
---

2026-10-13 11:17:54–11:19:26 Windows Update (SoftwareDistribution 下的 wsl.3.0.3.0.x64.msi) 自动升级 WSL, RestartManager 关掉 wslhost/wslrelay, VM 被拆再起。不是内核 panic; wsl-crashes/ 里只有用户进程 dump (11:15 git SIGBUS 是 D 盘 EIO, 见 [[feedback_wsl_d_eio_remount]])。

升级后自定义内核 6.6.114.1 仍生效 ([[project_ipg_wsl_kernel_switch]])。另: dmesg 每 10 s 刷 RequestReclaim memory.reclaim failed 22, 是 .wslconfig autoMemoryReclaim=gradual 与该内核不兼容, 无害。

"接收其他 Microsoft 产品更新"本来就是关的 (Microsoft Update 服务未注册), WSL 走的是 Windows Update 主通道, 关这个开关挡不住。10-13 已把 .wslconfig 改成 autoMemoryReclaim=disabled (备份 .wslconfig.bak-20261013), 下次 wsl --shutdown 后生效。

**Why:** 用户以为 WSL 本身开始崩了。
**How to apply:** 再遇到 WSL 整体重启, 先查 Windows 事件日志 MsiInstaller / RestartManager, 再怀疑内核。
