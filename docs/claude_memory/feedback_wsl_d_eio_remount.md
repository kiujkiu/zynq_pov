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

**根因 (2026-10-12 查实驱动存在, 因果仍是推断):** 7/17 从本地账户 kiujkiu 换成公司域账户 undef\wanqi.liu, 随之装了 IP-guard (TEC Solutions) DLP。注册表 (免管理员) 查到挂在文件系统上的 TEC minifilter: TFsdframe (alt 266000, 监控, 7/2), TNullFilter (160020), **TsdEncryptMF (149998.1, 加密段 = 透明加密, 8/19 更新)** —— 8/27 首次掉线, 10/8 sdhelper2 更新, 10/12 EIO 四次。WSL 读写 /mnt/d 实际由 Windows 侧 vmwp 进程执行, 照样过这些驱动。D: ACL 正常、NVMe 健康, 账户本身不是原因。
查法: 遍历 HKLM\SYSTEM\CurrentControlSet\Services 里 Type=2 且有 Instances 子键的服务, 读 Altitude/厂商 (fltmc 要管理员)。
**根治:** 高频 IO 全放 WSL ext4 (~/), D 盘只做同步备份; 不想迁就找 IT 给 vmwp.exe/wslservice.exe 或工作目录加白。透明加密下 WSL 读到的受控文件 (Office/图纸等) 可能是密文, 那只能找 IT。同一套 DLP 的另一面见 [[feedback_windows_dlp_encrypts_removable_writes]] (#OCULAR3# 头)。
**remount 副作用:** umount -l 后旧进程 cwd 留在已脱离的旧挂载上 (readlink /proc/PID/cwd 显示成 /claude_workspace/... 少了 /mnt/d), 这些会话要 cd 回绝对路径。

**2026-10-13 起自动恢复:** 装了 root 看门狗 `/usr/local/sbin/dwatch.sh` (由 /etc/wsl.conf `[boot] command=` 开机拉起, flock 防重复): 每 10 s 列 /mnt/d 目录, 5 s 内无返回算失败, 连续 2 次就 umount -l + `mount /mnt/d` (参数走 fstab, 不再带 metadata)。日志 `~/d_eio.log` 记掉线/恢复时间 → 给 IT 对 vmwp.exe 用。`~/fixd.sh` 只剩手动兜底 (调 ~/remount_d.sh)。Claude 改 wsl.conf/开机自启会被权限检查当"持久化"拦, 这类改动要写好命令让用户在 Ubuntu 终端跑。掉线后 cwd 在 /mnt/d 的旧会话仍要重开。
