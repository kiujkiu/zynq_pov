---
name: project_dr1_serial_transfer_channel
description: DR1 板的文件上板通路已验通(串口 base64 分块, 34KB/6块 md5 逐字节相同), 不依赖 WiFi/网线; 关键是必须关板端回显, 否则无流控下必丢字符
metadata:
  type: project
---

# 串口传输通道 (2026-08-27 验通, L0-L4 全过)

`dr1v90/host/serial_send.ps1` + `dr1v90/tools/stage_verify_link.sh`。
实测: 34 KB / 6 块, 板上 md5 与本机逐字节相同, 重复三次稳定。
⇒ **新 bit 有了不依赖 WiFi、不依赖网线的上板通路**(用户约束: 最终要旋转, 不能用网线)。

## 🔴 必须关板端回显, 这不是优化是前提

回显开着时**批量传输必丢字符, 且与缓冲区大小无关**:
板子每收 1 B 就要回发 1 B, 一条 2102 B 的行因此额外占 **182 ms 的 TX**;
N_TTY 输出缓冲一满就反过来**节流输入处理**, 而无流控下被节流的输入 = 被丢弃。

⚠ 原来 header 里"ChunkSize 上限是 `N_TTY_BUF_SIZE`=4096"是**误诊**: 2102 B 的行
在离上限 1.9 KB 的地方照样第一块就丢。真正的约束是**单核板子的排空速率**。
节流(`-PaceBytes`/`-PaceMs`)单独也救不了 —— 回显量随发送量同比增长。

## 它长什么样 (下次别再查一遍)

丢的那个字节在**单引号包着的 base64 里面** ⇒ shell 永远等不到闭合引号 ⇒ 挂在
**PS2 续行提示符**上 ⇒ 把之後送进来的一切都吞掉。**看起来完全就是板子死机。**

- **区分办法**: 暂存的 `.b64` 文件**根本不存在**。写了一半会留下文件;
  引号没闭合意味着重定向压根没执行。
- **恢复**: 送真正的 **Ctrl-C (0x03)**。送换行只会喂给续行。

## 关回显的代价怎么还的

`serial_cmd.ps1` 的判据是 "`__EOC__` 出现 >= 2 次", **第一次正是终端回显** ⇒
谁把回显关了不还, 它从此每条命令都等满超时, 看起来像板子挂了。
而 `finally` **会被 taskkill 跳过**(`tools/serial_run.sh` 开头就是 `taskkill /F`)。

✅ 解法: **恢复动作同时放到杀不掉的那一侧 —— 板子上**:
`{ sleep 900; stty echo; } &`, 主机怎么杀都够不着。
每次开工先按 pidfile (`/tmp/.serial_echo_guard`) 杀掉上一个 guard,
陈旧定时器不可能在後一次传输中途开火。

⚠ `serial_run.ps1` 也 `stty -echo`, 现在退出时交还。

## 速率

约 4 KB/s 上线(base64 1.333× + 节流 74% 线速)。bitstream 3 MB 压完约 37 KB
⇒ base64 约 50 KB ⇒ **十几秒**。够用, 不必去修。

相关: [[feedback_criterion_must_not_contain_its_answer]] [[project_dr1_parity_plan]]
