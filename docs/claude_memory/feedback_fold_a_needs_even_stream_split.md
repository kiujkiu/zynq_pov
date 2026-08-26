---
name: fold_a 的解码收益要靠 --stream-split even 才能兑现
description: 213 片按面切成 71/142 ⇒ makespan 被 142 封顶 ⇒ 收益全丢且**无任何报错**
type: feedback
---
2026-08-25。`fold_a` 把帧从 284 片 (10.47MB) 降到 213 片 (7.85MB), 解码 74 → 55.5ms。

🔴 **但只有配 `--stream-split even --stream-workers 3` 才拿得到。**

```
even     : 213 跨面切 71/71/71  ⇒ 完美均分, 3 个引擎同时完工
face     : 按面切 71/142        ⇒ makespan 被 142 那条封顶 = 没折叠时的 142
balanced : 面边界强制为流边界   ⇒ 更烂 (它是给板端**两个 CPU 核**调的)
```

⇒ 用错切分方式, fold 的收益**全部归零, 而且没有任何报错**。

## 之所以能跨面切

板端 MSTREAM 的落点是**纯累加** (`pov_rxd.c`: `dlen = s_nsl[i]*stride;
jobs[i].dst = buf + doff; doff += dlen;`), 完全不看 `face_b_off`,
而 bank 里 A/B 两面本来就是连续排布的。

⚠ `pov_rxd.c` 里那句「**FOLD_A 只省链路, 解码一分钱不省**」说的是**按面切**
的老前提 (两个 CPU 核, makespan 被面 B 封顶), **不是折叠本身**。同构硬件引擎
+ 跨面均分之后, 折叠省下的 25% 是实打实兑现的。别被那句注释劝退。

**How to apply**: 判据在板端日志的 `FRAME` 行 —— 看到 `2str` 就是没生效,
要 `3str`。`PLDIAG` 的 `pl` 字段也会直接反映 (55ms vs 74ms)。
