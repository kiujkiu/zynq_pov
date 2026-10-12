---
name: project-ipg-wsl-kernel-switch
description: 2026-10-12 IT 给了 IP-guard 官方 WSL 兼容内核 6.6.114.1 (root@teclink), 准备换上试是否解决 D 盘 EIO; 文件已就位, 等 pov3d-4b 的 agent 跑完再切
metadata:
  type: project
---

**背景:** D 盘 EIO 根因嫌疑是 IP-guard 透明加密驱动 (见 [[feedback-wsl-d-eio-remount]])。IT 给了 `wsl2.zip` (两个 bzImage: 5.15.167.4 给 Ubuntu 20.04/22.04, 6.6.114.1 给 24.04, 都是 root@teclink 编) + 《WSL内核使用说明.docx》: "默认内核和 IP-guard 支持范围可能不适配, 需安装指定内核"; 要求 WSL > 2.6.3 (本机正好 2.6.3.0 → 先 `wsl --update`)。本机 Ubuntu **26.04** 不在支持表, 选 6.6.114.1。

**已就位 (未生效):** `C:\Users\wanqi.liu\wsl_kernel\` 下 `bzImage-ipg-6.6.114.1` (sha256 5fa3fe54…), `wslconfig.bak-20261012` (原配置), `wslconfig.ipg` (原配置 + `[wsl2]` 下 `kernel=C:\\Users\\wanqi.liu\\wsl_kernel\\bzImage-ipg-6.6.114.1`, CRLF)。

**切换步骤:** ① 等 pov3d-4b 的 agent 跑完 + 用户同意 ② `sync_to_d.sh` ③ `cp wslconfig.ipg ../.wslconfig` ④ 用户自己跑 `wsl --update` 和 `wsl --shutdown` (会断掉所有会话, /tmp 清空) ⑤ 重开后 `uname -r` 应为 6.6.114.1-microsoft-standard-WSL2, 再对 /mnt/d 做并发读写压测 + 观察一周, 结果补进给 IT 的文档 (claude.ai artifact 18e5659d…, 本地 `docs_out/WSL读写D盘出错_IT协助_2026-10-12.docx`)。
**回滚:** `cp wslconfig.bak-20261012 ../.wslconfig` + `wsl --shutdown`。

**影响面 (已核):** 串口全走 Windows 侧 COM 口 (host/serial_*.ps1 调 .NET SerialPort), 不受内核影响。**WSL 点对点 WiFi 台架会废**: MT7921AU usbipd 进 WSL + 针对 6.6.87.2 自编的 cfg80211/mac80211/mt76 (~/wslkernel, 5.2G, 不在 D 盘备份里) → 新内核要拿 6.6.114.1 源码 + 从 bzImage 抽出的 IKCFG 配置重编; pov3d-4b 说 WiFi 测速正考虑改用独立路由器+网线, 影响不大。新内核里 USB 串口驱动 (ch341/ftdi_sio/cp210x) 是模块且 IT 没给, cdc_acm/usbip 内建。

**2026-10-12 16:19 进度:** ①②③ 已做 (pov3d-4b 全部 agent 已停, 16:18 sync_to_d, `.wslconfig` 已换成 wslconfig.ipg)。等用户 `wsl --update` + `wsl --shutdown`。重开后第一件事: `uname -r` 核 6.6.114.1 → 对 /mnt/d 并发读写压测 → 写进 IT 文档。hostapd + MT7921AU (usbipd 2-4) 会随 shutdown 停掉, 要还给 Windows 用 `usbipd detach --busid 2-4`。

**2026-10-12 换完:** `uname -r` = 6.6.114.1-microsoft-standard-WSL2 ✅。首轮压测 (16 路并发 写/读/cp/cmp 各 200 个 64K–4M 文件 ≈13 GB, 外加并发 find 遍历) 173 s 零错误, dmesg 无 9p 报错。MT7921AU (2-4) 已是 Shared 未挂进 WSL。接下来: 观察一周 + 结果补进 IT 文档。

**10-12 晚复发:** 换上 6.6.114.1 约 4 小时后 (≈17:5x 和 18:0x) /mnt/d 又 EIO 两次 (多 agent 并发 TD 综合 + 仿真时), 新内核**没根治**。会话 cwd 在 /mnt/d 时连 bash 都起不来 (posix_spawn EIO), Claude 自己无法 remount (权限检查拦 dangerouslyDisableSandbox) ⇒ 让用户在普通终端跑 `bash ~/fixd.sh` (已写好, 内容即 umount -l + mount drvfs)。用户手敲长命令易错, 给脚本。待补进 IT 文档。
- 10-12 22:1x IT 文档已补晚间更新 (换内核后仍 EIO 至少 4 次、dmesg 无 9p 错、请 IT 查 17:30–22:00 vmwp.exe 记录 + 按第 1/2 项加白): docs_out/WSL读写D盘出错_IT协助_2026-10-12_晚间更新.{docx,pdf,html} (原 docx 未覆盖)。WSL 已是 3.0.1.0。
