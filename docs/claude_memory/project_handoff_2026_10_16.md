---
name: project-handoff-2026-10-16
description: 周末交接 (10-17 晚更新): 主线 3bf094f; 周末合 D27/D27b/D28/D28b/D29方案/D30/D31/V2-3/V2-5/V2-6/D20e修; 02 24h 长跑 PASS; 03 24h 长跑在跑; 周一清单 PDF
metadata:
  type: project
---
**主线 dr1v90 feature/lvds-b2b = c8e8294** (以 git log 为准)。达成率 V0 95.5% / V1 79.0% / V2 71.0% (10-16 晚新增 D27/D28/D29 必须项拉低分母)。
10-16 合主线: D23 V1 显示后端 --disp 2260 / D24 立方体候选 (用户定开机保持 geo_loop) / KR7.3 16 位计数回绕 / D20e 相位锁定 (583 rpm 滑格 5.2→0.19%) / D25 V1 换档 358/286/210 / D12 lock-lead 150→70 ms (延迟 p50 133 ms) / D9 V1 端到端仿真逐像素 0 错 / D26 V2 位流重出 (余量 0.000 ns) / soak 产品配置开关 SOAK_PLV/MAXFPS/MARGIN。
**板子**: dr1m90-02 卡上 voxslice = D20e 版 ba243d71 (落后主线, V0 dump 逐字节同, 不急); dr1m90-03 = 新板 (卡由 D:\card03 镜像块级写, 控制台 COM30 CH342-A), 冷上电 u-boot "Card did not respond to voltage select -110" 停 =>, mmc rescan+boot 可起 → D29。03 wlan0 MAC 90:de:80:47:f0:fd (旧 dr1v90-2 的网卡)。
**周末在跑**: D27 (task/d27-link, Opus) / D28 (task/d28-bringup) / D29 (task/d29-sdboot, 用 03 + COM30; 改 uboot.env/boot.scr 需用户批准) / 02 24h 长跑 soak8h/runs/1016_wkend_24h (PLV=0 max-fps 20 margin 1.0)。
**待用户**: D11 C1 台架接线; D29 批准改 u-boot 读的文件; PC USB WiFi 驱动。
**已知不稳**: d20d P2 / d20c F3 帧间隔 std 判据在机器高负载时偶发超门槛, 空闲 0.1 ms; 待改失败重测。
**教训**: 写 TF 卡只能块级 (host/flash_card_raw.ps1, 用户管理员窗口 `powershell -ExecutionPolicy Bypass -File .\go.ps1`), 文件写会被 DLP 拒/加密; 串口发回车会打断 u-boot 自动启动, 看启动只听不发; build.sh 自带 flock, 外面再包 flock 自死锁 (D26 白等 2.5 h); 板上多步任务写进同一脚本串行; 排队只用 kill -0 PID。
用户偏好: 自主推进只同步结论, 结果记看板, 不阻塞; 流畅度与无串口连网是一等要求; 周额度到 70% 先保存再停 (用户报数)。

**10-17 晚更新**: 主线 dr1v90 = 3bf094f。周末已合: D27 SoC↔桥边带全功能 (仿真 E1-E5) / D27b D27 套位流出件 (主控 a36365e9 在 D:\claude_workspace\pov3d\_work\d10_v1bit_out\, 桥 e60c e7289b13) / D28+D28b V1 回板一键脚本 v1_bringup/ (--set cur|d27) / D29 冷启动认卡方案 (只改 uboot.env, 待批准) / D30 计时判据抗负载 / D31 V1 奇数档评估 / V2-3 映射 / V2-5 主控 p2 字槽格式器 / V2-6 2 期桥 p2 core / D20e 修本地播放半圈换回归 (根因 --pl-gate 作用到本地帧)。
全套 19 套回归在 fdb63f4 跑过 (修后各套已单独复验)。02 24 h 产品配置长跑 PASS 10/10 (progress/soak_v0/1016_wkend_24h)。02/03 卡上 voxslice = 63e7afea (主线 86caee5), 旧版 .bak-0717。03 24 h 长跑 10-17 22:26 起 (~/.soak_local/runs/1017_03_24h, 结束拷回 dr1v90/soak8h/runs/1017_03_24h)。
**周一给用户**: zynq_pov/docs/progress/周一待拍板_2026-10-19.pdf (A1 批准 D29 写卡+冷上电 20 次 / A2 回板用 D27 套 / A3 C1 台架接线 / B1 V1 357/285/209 / B2 24 Hz 满档 / B3 V2 605/513/461 / B4 JTAG 菊花链 R6 / B5 GW5A A/B / B6 ADC 复用脚 / B7 V2 桥板 3 颗 8 选 1)。
**新教训**: 守护类 verify ("现役代码不变") 要只比自己的合并提交, 否则后续正当改动全误报; soak.sh 现在先拷本地再跑; 新克隆在 D 盘 git 丢可执行位, 假板工具要沙箱 chmod; agent push 被拒时主会话从 _work 克隆 git fetch 本地分支 (先核 remote 只指本地)。
