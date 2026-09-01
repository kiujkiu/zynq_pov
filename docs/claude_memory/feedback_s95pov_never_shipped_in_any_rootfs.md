---
name: feedback_s95pov_never_shipped_in_any_rootfs
description: 🔴 S95pov/POV_HOSTNAME 从来没进过任何做出来过的 initrd ⇒ AUTOBOOT 和 povboot.env 都是空操作; ✅ **2026-08-31 已解决并上板验证**: 冷启动全自动(WiFi/PL/povmem/povsh), hostname=dr1a, 串口依赖解除
metadata:
  type: feedback
---

# `S95pov` 从来没进过任何一个 initrd (2026-08-31 两个 agent 各自解包实证)

## 事实(一手, 解包实读不是转述)

```sh
tail -c +65 boot/rootfs_wifi.bin | lz4 -d | cpio -idm      # rootfs_wifi_v2.bin 同
```

| 查什么 | 命中 |
|---|---|
| `S95pov` | **0** |
| `POV_HOSTNAME` | **0** |
| `etc/init.d/` 真实内容 | `S01syslogd S02klogd S02sysctl S10mdev S20urandom S40network S41dhcpcd S90wifi automount.sh rcK rcS` |
| `etc/hostname` | `anlogic` |

⇒ **`tools/mkrootfs.sh:383-386` 的 `POV_HOSTNAME` 逻辑从来没被打进任何产物。**

## 因此这两件事都是**空操作**, 而且都不报错

1. 卡上 `touch pov/AUTOBOOT` —— 闸门是给一个**不存在的 `S95pov`** 看的
2. 卡上 `pov/povboot.env` 里写 `POV_HOSTNAME=` —— **没有任何进程会读它**

(与 [[feedback_rxd_default_pipeline_is_the_harmful_one]] 里那两个 shell bug 叠加:
就算 env 生效了, 读它的那个启动脚本本身也不存在。)

## 🎯 它是一整类问题的根

2026-08-31 调研"WiFi 能不能不找 IP 找名字", **六条独立路线全部死在这一条上**:
板子重启后 **povsh 不自启** ⇒ mDNS 没进程应答 / 9600 上没东西可扫 /
没有进程发信标 / DHCP 上报的是 `anlogic`。
**"名字 vs IP"根本不是那个问题, "重启后板上什么都不跑"才是。**

## ✅ 2026-08-31 已解决 — 上板验证通过

造了带 `S95pov` 的新 rootfs 并部署到卡上, 冷启动实测:
```
host=dr1a  up=79s
POVBOOT: PASS  (S95pov aggregate; every stage in 'povsh pl sw wifi' returned 0)
STATUS=0x00000008  auto_en=0     <- 自启**不点屏**(唯一能无人值守烧硬件的动作被排除在外)
POVSH_HOST=10.10.20.222 ./host/povsh_run.sh --ping  ->  ✅ 活着
```
⇒ **上电 → 自己连 WiFi → 自己烧 PL → 自己装 povmem → 自己起 povsh**, 全程无人干预。
⇒ `POV_HOSTNAME` 那条从来没生效过的链路活了, **hostname = `dr1a`**。
完整部署记录与卡上现状见 `dr1v90/docs/AUTOSTART_DEPLOYED.md` / commit `b37a8ab`。

🔴 **部署时撞到的、下次还会撞的两条**:
1. **卡上的 `povboot.sh` 可能没有你要的阶段** —— 第一次开闸门 `POVBOOT: FAIL (failed
   stages: povsh)`, 根因是卡上那份是 08-28 18:22 的, 而 `povsh)` 分支是 22:20 才加的。
   **先 `grep -o '^  [a-z]*)' povboot.sh` 看它有哪些阶段, 别假设。**
2. 🔴 **`povboot.sh` 在 `pov/MANIFEST.md5` 里, 换了它必须重算**, 否则下次开机
   `stage_card` FAIL、整条自启断在第一步。`povsh`/`povshd.sh`/`povboot.env` **不在** MANIFEST 里。

## How to apply

1. 🔴 **把"造一个真带 `S95pov` 的 rootfs 并上板验证自启"当成板子上转子前的硬门槛。**
   代价是 `boot/MAKE_CARD_DR1.md:189-196` 那四条**从未跑过**的链路(新基底重打 initrd →
   从没跑过的 `make_card_image_dr1.sh` → 赌一个 u-boot 从没加载过的 `boot.scr` →
   S95pov 首跑), **是全仓库风险最高的路径** —— 而多份调研把它一笔带过成"板端改动极小"。
2. 🔴 **必须在板子还能插串口的时候做完。上了转子没有第二次机会。**
3. 🎯 **教训: "源码里有" ≠ "产物里有"。** 引用 `mkrootfs.sh` 里的一段逻辑当"机制已存在"
   之前, 先解开真正的 `rootfs.bin` grep 一次。同族: [[feedback_bit_and_bitbin_can_disagree]]
   (`.bit` 与 `.bit.bin` 不同步) 和 08-28 那条"卡上的 povboot.sh 是旧版"。
   **这个项目已经在"仓库里的东西 ≠ 卡上的东西"上栽过三次了。**

相关: [[feedback_dr1_reboot_loses_everything]] [[project_dr1_panel_first_light]]
[[feedback_bit_and_bitbin_can_disagree]]
