---
name: touch 成功 ≠ 介质可写 — 快速格式化也只写元数据
description: 一张数据区坏的卡, touch 和快速格式化都会成功; 必须实写数 MB 再读回比对 md5
type: feedback
---
2026-08-26。判断一张 SD 卡能不能写, **连续误判两次**:

1. `touch /mnt/x/f` 成功 ⇒ 判定"卡能写" → 实际 `cp` 全部 `error writing`
2. Windows **快速格式化**也成功 ⇒ 一度判定"卡是好的", 又反过来判定"卡坏了"

🔴 原因: `touch` 和快速格式化**只写元数据区**(目录项 / FAT 表), 数据区一个字节没碰。
症状长这样:

```
文件创建出来了, 但都是 0 字节
md5 全是 d41d8cd98f00b204e9800998ecf8427e   ← 空文件的 md5
cp: error writing ...
```

一张数据区写入故障的卡, 这两项都会给出**假阳性**。
(最后查明这次其实是 WSL 的 9p 限制, 见 [[feedback_wsl_cannot_write_removable_media]]
—— 但假阳性判据让我在"卡坏了/读卡器坏了/卡是好的"之间来回翻案了三次。)

## 正确判据: 实写实校

```bash
dd if=/dev/urandom of=/tmp/t bs=1M count=20 status=none
cp /tmp/t /mnt/x/t && sync
[ "$(md5sum < /tmp/t)" = "$(md5sum < /mnt/x/t)" ] && echo "可写" || echo "不可写"
```
要点: ① **真实数据**不是空文件 ② **足够大**(≥ 数 MB, 跨多个簇, 逼它分配新空间)
③ **读回比对**不是只看返回码。

**Why**: 又一个"判据自身失效, 且失效方向是看起来正常"的例子。
同类: [[feedback_pair_miss_sentinel_was_broken]] (16位计数器被当1位读)、
[[feedback_grep_treats_gbk_log_as_binary]] (grep 匹配到也 exit 1)。

**How to apply**: 验证存储介质、网络通路、任何"能不能写/能不能传"的能力时,
**用一份有内容、有体量的真实负载走完整条路, 再从另一端读回来比对**。
轻量探针(touch/ping/建空文件)只能证伪, 不能证明。
