---
name: WSL git push 走 cmd.exe 调 Windows git
description: WSL 里 /usr/bin/git push 失败 ("No such device or address"), 改用 cmd.exe /c 调 Windows git.exe 即可成功 — Windows Credential Manager 已缓存 PAT, 永久有效
type: reference
originSessionId: bafc105a-a8db-471f-ae33-42571927b4da
---
## 现象
WSL 内直接 `cd /mnt/d/workspace/zynq_pov && git push origin master` 会报：
```
fatal: could not read Username for 'https://github.com': No such device or address
```
原因：WSL `/usr/bin/git` 没有 credential helper, 而 Claude Code 的 Bash 工具是非交互 shell, 无 TTY 不能弹用户名密码。

## 解决（一行命令）
```bash
cd /mnt/d/workspace/zynq_pov && cmd.exe /c "cd /d D:\workspace\zynq_pov && git push origin master" 2>&1 | tail -15
```

## 为什么有效
- `cmd.exe /c` 在 Windows 侧执行
- 走 `/mnt/c/Program Files/Git/cmd/git.exe` (PATH 上有)
- Windows git 自动调用 **Git Credential Manager (GCM)**
- GCM 从 Windows Credential Store 读 GitHub PAT (永久缓存, 安装 Git for Windows 时由用户配过)
- 所以非交互也能拿到凭证

## 适用场景
- 任何 git 写操作 (push, fetch private, clone private)
- 仅当 working dir 在 Windows 文件系统 (D:/ 等可被 cmd.exe 访问) 时才行
- WSL 路径 (/home/...) 不能用此法, 因 cmd.exe 的 UNC 路径不被 cmd 默认支持

## 避坑
- 不要尝试在 WSL 配 credential.helper / SSH 等替代方案 — Windows GCM 已经现成可用
- 不要用 `2>&1 |` 之外的复杂管道, 输出可能含 GBK 编码的中文报错乱码
