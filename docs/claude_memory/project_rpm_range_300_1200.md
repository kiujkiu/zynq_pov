---
name: project-rpm-range-300-1200
description: 10-15 用户定 V0/V1/V2 都要兼容 300–1200 rpm; PL 换帧受转速限制 (583 rpm 只 8 fps) 是第一个要解的
metadata:
  type: project
---
10-15 实转 583 rpm 时 PL 切片换帧要等整圈边界 → 内容只有 8 fps (CPU 切片时代 15 fps), 用户觉得卡。8 h 长跑用假转 16.15 rps 没暴露。
用户定: **最终 V0/V1/V2 都要兼容 300–1200 rpm**; 代码先行, 能在 V0 (2047) 验证的就在 V0 验证。

**Why:** 转速受机械/电机限制, 内容帧率不能被转速卡死。
**How to apply:** 验收要在多个转速点测帧率 (假转扫 5–20 rps + 实转), 不能只测一个假转速度。
物理上限: 两面偏置 180°, 半圈即可画完整体 → 换帧上限 2×rps (300 rpm = 10/s)。V1 2260 在 24 Hz/720 rpm 时序余量仅 0.4%, 1200 rpm 需按转速自适应每圈片数。
相关: [[project-sw-three-phases-1013]] [[project-arch-common-front-display-backend]]
