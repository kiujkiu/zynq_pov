---
name: project-wifi-stable-d22
description: 10-15 用户: 稳定 WiFi 是 V0 必须项, 不能靠串口 → D22; 每 124.5 s 卡 3 s 是测试的板上对拍造成 (非 WiFi)
metadata:
  type: project
---
用户 10-15: "你不能总是靠串口呀, 稳定的 wifi 连接是必须的 … 需要在 v0 搞定"。
已查清: 推流每 124.5 s 卡 3 s = soak 的 --pl-verify 1800 (每 ~120 s 板上对拍, 每次停 ~3 s), 测试工具自身, 产品默认不开; 同刻 ping 0 丢。
**How to apply:** 量流畅度/WiFi 的长跑一律 SOAK_PLV=0 (对拍另做短测); soak8h 已加 SOAK_PLV/SOAK_VS_EXTRA/SOAK_LAT/SOAK_PING_S 开关 (分支 task/d20c-diag)。
真实 WiFi 问题: 回放对照 (WSL/Windows 各 6 min) 有偶发 1–1.7 s ACK 停顿 (每 6 min 1–2 次); 公司 AP 会主动踢板 (deauth reason 8, 换 AP ~5 s)。
诊断工具 ~/realspin/netdiag.sh: 1 h 推流 + 板/PC 各 0.2 s ping 网关 + iw link + dmesg, 定位停顿在哪一跳。
候选对策: 板端锁频/少扫描加快重连、产品自带专用 AP 或板子开热点 (避开企业 WiFi 调度), 小播放缓冲。
相关: [[project-smoothness-first-class]] [[project-dr1m90-02-remote-ops]]
- 10-15 用户: "wifi 问题核心第一条, 不能脱离串口连不上" "这个要彻底解决" → D22 (Opus, task/d22-reach): 四层兜底 = 服务监护 (sshd/povmdns/povstat) + 硬件看门狗 (/dev/watchdog, pov/nowdt 关) + 兜底热点 POV-<板名> 192.168.77.1 (需静编 hostapd, 板上无 hostapd/udhcpd) + 故障注入上板验收 (不插串口按名字找回)。热点那项 PC 测不了 (单 WiFi 卡), 需用户手机确认一次。
- 10-15: PC 上插着 USB WiFi 联发科 MT7921AU (USB 0E8D:7961), Windows 未装驱动 (状态 Error)。用户定留着; 装好驱动后作第二块网卡专连板子兜底热点 (192.168.77.x), D22 热点测试可全自动。
- 10-16 00:4x: D22 合主线 d3024bb (上板演练 14/14, povnetd 1.2 硬故障立即重连 + povmdns 重关联重发 IGMP + povreach 看门狗/热点)。串口可拔。
