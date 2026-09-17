---
name: feedback_experiment_side_effect_optimized_away
description: 实验变体里"只写不读"的副作用(写 static 数组逼 D-cache 逐出)被 gcc -O2 整段删掉, 实验臂悄悄变成对照组; 上板前必须在 objdump 里看到那段指令
metadata:
  type: feedback
---

2026-09-16 DR1 PL 解码区分实验 X2' 模式 2: 想在刷写后往 256 KB 的 `static uint8_t xscratch[]` 每 64 B 写一个字节, 把 D-cache 挤满逼脏行写回。
数组从来不被读 ⇒ `gcc -O2` 当死存储**整段删掉**, 二进制里连 `xscratch` 符号都没有。
那一臂实际等于原版, 跑出"逐出没用", 我据此推出一条"写回命令把行标成干净但没写 DDR"的解释并告诉了用户 —— 后来查 nm 才发现, 撤回。
改成 `static volatile uint8_t xscratch[...] __attribute__((used))` 后 objdump 里出现 4096 次 `sb` 循环, 重跑结果从"没用"变成"降 10×", 结论反转。

**Why:** 实验臂的效果全靠一个对程序语义无意义的副作用(缓存/时序/硬件), 编译器按语义优化就会把它当垃圾删掉, 而运行时毫无报错。
**How to apply:** 凡是为了硬件副作用而写的代码(逼缓存逐出、忙等、触摸页、写不读的寄存器影子), 用 `volatile` 并在上板前 `nm`/`objdump -d` 确认指令真在;
一臂"没效果"时先怀疑量具, 再改理论。相关: [[project_dr1_pl_decode_parity]] [[feedback_verify_signal_actually_connected]]
