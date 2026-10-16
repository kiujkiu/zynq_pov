---
name: project-handoff-2026-10-16
description: 10-16 晚交接 (周末自主跑到周一): 主线 c8e8294; 两块板 02/03 都验收 6/6; 跑着 D27 SoC↔桥全功能 / D28 V1 回板脚本 / D29 03 冷启动认卡 / 02 24h 长跑
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
