---
name: feedback-wsl-d-eio-remount
description: "WSL 里 /mnt/d 报 EIO 时不用重启电脑, sudo umount -l + mount -t drvfs 即可恢复 (Windows 侧 D 盘本身健康)"
metadata:
  node_type: memory
  type: feedback
  originSessionId: c9892ebe-8249-4a6c-9658-3a7a297a50b4
  modified: 2026-10-12T03:34:00.521Z
---

2026-10-12 D 盘在 WSL 里第二次 EIO (第一次让用户重启了电脑)。Windows 侧 `Get-Volume D` = Healthy, 坏的只是 WSL 的 9p 挂载。
修法 (有免密 sudo): `sudo umount -l /mnt/d && sudo mount -t drvfs D: /mnt/d -o metadata,uid=1000,gid=1000`, 秒恢复。

**Why:** 重启电脑会打断所有后台 agent 和串口抓取; remount 只影响 cwd 在 /mnt/d 的旧进程。
**How to apply:** 看到 `/mnt/d` Input/output error 先用 powershell 确认 D 盘健康, 再 remount; 然后通知在跑的 agent cd 回绝对路径重试、查 git status 有无截断文件。疑似多 agent 并发重 IO (Gowin 构建/仿真) 时触发, 并行度高时留意。
