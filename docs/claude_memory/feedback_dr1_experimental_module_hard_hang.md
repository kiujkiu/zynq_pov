---
name: feedback_dr1_experimental_module_hard_hang
description: 🔴 2026-09-15 上午 在 DR1 上换装实验性 mt76-usb.ko(gro+rxagg) 后 mt7921u probe 失败、回退时 rmmod mt7921u 段错误(内核 oops), 单核内核随后整机卡死(串口连回显都没有)只能断电; 部署脚本的"失败自动回退"救不了内核崩溃, 且 oops 文本全丢; 同时记下 pkill -f 自杀和上午空口拥挤让 A/B 作废
metadata:
  type: feedback
---

# 实验性内核模块把 DR1 弄死了 (2026-09-15)

## 经过

1. GRO-only 版 mt76-usb.ko 部署/测量/卸载都正常(deploy.sh RESULT PASS)。
2. 换 gro+rxagg 版: `insmod mt76-usb.ko rx_agg=1 rx_agg_buf_size=8192 rx_agg_tail=8` 成功 →
   `modprobe mt7921u` 后 **wlan0 30 s 没出现** → 脚本回退 `rmmod mt7921u` → **Segmentation fault**(= 卸载路径内核 oops)。
3. 之后串口输出变二进制乱码; 再之后**完全无响应: 只听 15 s 零字节, Ctrl-C/回车连回显都没有** ⇒ 不是 shell 卡住,
   是内核卡死(单核上关中断持锁 oops 后整机停)。CH342 串口设备仍在(板子有电)。
4. 芯片聚合寄存器这次**没动过**(聚合使能要等部署成功后才写), 所以不是寄存器问题, 是模块本身。
5. 🔴 **oops 文本没抓到**: dmesg 在内存里, 断电即丢; 当时串口输出被我的 `grep` 管道当成二进制吞掉了。

## 🎯 离线根因 (同日, 3 路独立排查 + 汇总, 有代码行号; 无 oops 文本故为中-高置信)

1. **probe 失败 = 我的帧长模型错了**: 真实 USB RX 帧布局是 **round_up(len,8)+4**, 我按 round_up(len,4)+8 设了
   `rx_agg_tail=8`。len%8∈{0,5,6,7} 的单帧 URB 被判 SPLIT 且 n=0 ⇒ **连第 1 帧都不投递**; 固件启动期 MCU 应答走 EP4
   (正是 rx_agg 队列) ⇒ 丢应答 → 3 s 超时 → init 重试 10 次全败 → wlan0 永不注册。
   (离线回放 1400 个真实样本: tail=8 丢 11 个, 含 type-7 事件。)
2. **rmmod 段错误 = 原版 mt7921u 的 bug, 被失败的 init 触发**: init 失败后 `MT76_STATE_INITIALIZED` 不清,
   `mt7921u_disconnect` 对**从未注册的 hw** 调 `mt76_unregister_device` → `wiphy_unregister` 持 `rtnl_mutex` 后
   `list_del_rcu` 空链表 → NULL 写 → oops, **rtnl_mutex 永久被占**。
3. **"卡死"大概率不是内核死, 是用户态死锁 + 我的工具假象**: oops 后串口还答了几分钟(Phase C 时序); 之后任何需要 rtnl 的
   命令(ip/ethtool/iw)进 D 态; `serial_run.ps1` 执行前关了回显、命令结束才恢复 ⇒ 敲键无回显、Ctrl-C 打不断 D 态;
   "二进制乱码"是主机 grep 对 GBK 超时横幅的反应。但单一 tty 被卡住的 shell 占着, **仍然只能断电**。
4. 已排除: mdev->rev 时序(rev 在 RX 队列分配前就读了)、GRO 与 rxagg 互扰、rxagg 缓冲释放路径、分配回退。

## How to apply

- 🔴 **上板加载实验性内核模块前, 先在主机上持续录串口原始字节到文件**(只听不发的后台读取), 整个换装过程都录;
  串口读取不要经过会丢二进制的 grep 管道。否则崩了之后没有任何证据, 只能靠读代码猜。
- 🔴 **"失败自动回退"只对用户态失败有效**。probe 失败后再 `rmmod` 反而可能触发 oops; 对实验模块, probe 失败时
  **优先直接重启**(模块在 initrd 里, 重启即完全还原), 而不是在已损坏的状态上卸载。
- 新功能尽量**默认关、probe 成功后再运行时打开**(例如 rx_agg=0 加载, 确认 wlan0 正常后再切), 让 probe 走原版路径。
- 🔴 **每次上电后、换模块前先设**: `echo 1 > /proc/sys/kernel/sysrq; echo 1 > /proc/sys/kernel/panic_on_oops; echo 15 > /proc/sys/kernel/panic`
  ⇒ oops 直接打印并 15 s 后自动重启, 不会留下被占的 rtnl_mutex(需先验证一次 sysrq-b 真能复位, SBI SRST)。
- 🔴 **init 失败后绝不 rmmod mt7921u**(原版驱动的 disconnect 会对未注册 hw 注销 → oops), 直接重启。
- 帧格式类推断**必须覆盖 len%8 全部余数**再定参数; 只用 MTU 大帧测出的规律会碰巧对上两种不同公式。
- 🔴 **同日第二次卡 rtnl(与模块无关)**: eth0 **没插网线**时 `ip link set eth0 mtu 9000` 成功, 但改回 1500 时 stmmac 重开失败
  (`Failed to reset the dma` / `DMA engine initialization failed` / `failed reopening the interface after MTU change`, 大概率是无链路就没有 RGMII RX 时钟),
  随后 `ip link set eth0 down` **卡在 D 态 `napi_disable`, 永久占着 rtnl_mutex**; WiFi 数据面照常, 但 ip/iw/wpa 全挂, 串口 shell 被占。
  ⇒ **stmmac 无链路时不要改 MTU / 不要 down-up**; 查状态走 povsh(WiFi)只读 /proc、/sys, 别碰 rtnl 命令; 恢复靠 sysrq 重启(写 /proc 不需要 rtnl)。
- ✅ **sysrq 软重启已实测可用**(同日 15:22): 经 povsh 发 `echo 1 > /proc/sys/kernel/sysrq; sync; echo s > /proc/sysrq-trigger; sleep 3; echo b > /proc/sysrq-trigger`
  ⇒ 板子真的复位(SBI SRST), 约 80 s 后原版驱动 + WiFi + 两个 IP 自动恢复。⇒ **rtnl 卡死但 WiFi 数据面还通时, 不用人工断电**。
- 这块板**除了人工断电没有任何复位手段**(wlan0 没了、eth0 没接) —— 把"会不会弄死板子"当成上板前的必答题。
- 顺带两个我自己的坑:
  - `pkill -f "plan_full.sh"` 匹配到了执行它的那个 bash 自己的命令行, 把自己杀了。要按 PID 杀并排除 `$$`。
  - 上午 11 点办公室空口拥挤: 原版驱动 TCP 只有 21-41 Mbps 且 CPU 仅 33-69%、UDP 12k 只收到 5.6k pps
    ⇒ 瓶颈变成空口, **按判定规则 G0(busy<80%)这组 stock vs GRO 对比作废**。吞吐 A/B 要选空口安静的时段, 并先确认 busy≥85%。
  - `ab_mod.sh` 里 "tx/rx" 列取成了 txbytes/rxpkts(/proc/net/dev 第 11 列是 tx bytes, 第 12 列才是 tx packets), 该列作废。

## ✅ 09-15 下午 按 RUNBOOK 安全重测 (mt76agg3/RUNBOOK.md, 证据 mt76agg3/evidence/stepN/)
- step 1 全过: serial_session.ps1 首次实跑正常(独占 COM5, 全程录 serial.raw/log); **串口 BREAK+SysRq 经 CH342 可用**(`sersh --sysrq h` 出 HELP);
  串口会话下 sysrq s/b 真复位, ~30 s 回 login。板上 taint 4096 来自自家 povmem_dr1(O), 正常。
- step 3 (gro_fixB = GRO + disconnect 修复, 无 rx_agg): RESULT PASS, 重编模块在板上内核能加载(MODVERSIONS 对上)。
  probe 期 usbmon 回放: **根因 1 实锤** —— 旧 tail=8 walker 丢 10 个 MCU 应答(eid 0x04 PATCH_SEM / 0x01 TARGET_ADDRESS_LEN,FW_START / 0xec)。
- 🔴 **新发现: ROM bootloader 阶段(补丁/固件下载, probe 前 ~160 ms)的 MCU 应答是 `actual == len`(36/36, 无 4 B 尾巴)**,
  RAM 固件起来后才是 round_up(len,8)+4 ⇒ um_replay 判 VERDICT 5。v3 原样代码回放: 第 0 帧 0 丢, 但 tail_mismatch=frame0_fallback=9
  并打一次 `rx_agg: framing mismatch` ⇒ 按原 RUNBOOK 的 FORBID_RE 第 4 步必定误判重启。处理: 代码不改(多帧解析要等 wiphy 注册后, 碰不到 ROM 阶段),
  只改判定: FORBID_RE 去掉 framing mismatch, 上线后允许 mismatch==fallback≈9, 流量期间增量必须 0。
- 🔧 sersh.sh 偶发 202(会话其实活着): PowerShell 每拍非原子重写 session.state, drvfs 上读到空文件 ⇒ session_alive 加 4×0.5 s 重试后消失。
- ⚠ 吞吐测不准的新坑: 板子重启后漫游到另一台 AP(53:dd ch149), PC 在 56:8d ch161; 当时 PC→网关 ping 均 43 ms、板→网关 8.9 ms,
  正反向都只有 ~10 Mbit ⇒ **瓶颈是 PC 那一跳 WiFi**。吞吐 A/B 前先 ping 网关分段查延迟, 两边最好在同一 AP、空口安静。
- ✅ step 4 (v3, multi off, 改后判定) PASS: 计数与主机回放预测一模一样(mismatch=fallback=9, frames==urbs, 其余 0);
  step 5 G2 / step 6 G3(运行时 multi_en=Y) 功能全过: 流量期间错误类增量全 0、1465 种 ping 包长 0 丢、扫描正常; 每步结束都在健康状态下 reboot 回原版。
  **整个过程 0 次人工断电** —— "先离线回放 + 串口全程录 + sysrq/看门狗兜底 + 一次只变一个量"这套流程有效, 以后上板实验模块照此办理。
- 🔴 **同一块板被别的会话共用**: 09-15 另一个会话按交接记忆"板子访问: dr1a"误连本板(WiFi .112), 15:52 在 boot 第 106 s 烧了 JTAG 测试位流、
  写了 PS↔PL 寄存器、SD 卡留 jtag_load/。只影响那一次开机(重启即回生产 PL)。⇒ 上板测试前/每次开机后查
  `dmesg | grep fpga_manager`(自启动只有 29-30 s 的 `writing pl.bin`, 其它都是外来的)和 `ps` 有无陌生进程; 多窗口并行时先确认谁在用哪块板。
- 小坑: 开机约 30 s 自启动烧 PL / 加载 povmem 时内核往控制台狂打, 这时经串口灌命令(sersh push)会 `ttyS0: input overrun` 丢字节 ⇒
  命令引号被截断 → `eval: syntax error` → sersh 超时并 BLOCKED。⇒ 重启后先只读等到 `povmem: bank` 出现、wlan0 拿到 IP、uptime>60 s 再写串口。
- 小坑: dmesg 检查的 `WARNING:` 会命中开机 29.9 s 的 `OF: overlay: WARNING: memory leak will occur if overlay removed`(自启动加载 FPGA overlay 自带), 与驱动无关, 判定时要排除。

相关: [[reference_dr1_wifi_ceiling_unestablished]] [[feedback_dr1_reboot_loses_everything]] [[feedback_dr1_wifi_dongle_brownout_reboot_loop]]
