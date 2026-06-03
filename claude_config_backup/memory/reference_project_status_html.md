---
name: POV3D 项目状态文档 (HTML)
description: 项目全景说明 + 任务认领看板 + 跨部门支持需求, 给团队解释项目用, 含任务 ID 体系和里程碑定义
type: reference
originSessionId: 97aa4d7f-a5d6-468a-bc1c-6af3e6981cf2
---
文件: `D:\claude_workspace\pov3d\project_status.html` (46 KB / 1224 行)

**用途**: 对内对外解释 POV3D 项目的标准文档, 面向新人 / 团队成员 / 非研发部门。当用户要求"整理项目状态"、"给团队解释"、"任务分配"时, **优先更新这个文件而不是重新生成**。

## 文档结构 (9 节)

1. 项目愿景 + KPI (160×180 × 8-bit × 30 Hz)
2. 系统架构 + 数据流 (PC → WiFi → Zynq → LED panel pipeline)
3. 数据量分析 (voxel 13.8 MB/帧, slice 31 MB/帧 → 必须传压缩 3D 描述)
4. 三大研发方向: 通信 (① COMM) / 渲染 (② RENDER) / LED 驱动 (③ LED)
5. (内容并入 4 节)
6. 任务认领看板 (按"立刻能开工 / 有阻塞 / 中长期"分类 + 角色推荐)
7. **跨部门支持需求** (采购 P / 硬件加工 H / 机械 M / 测试 Q / 财务 F / 法务 L / 行政 A)
8. 起步资源 (必读顺序 + 按方向深入 + 8 条踩坑 + 工具链)
9. 下个里程碑 (M1-M4 定义)

## 任务 ID 体系 (引用时直接用)

- **T-Cx**: 通信任务 (C1=ESP32-S3/P4 升级, C2=ARM parser dual-task, C3=IRQ UART, C4=GEM0 TX 修复, C5=mesh 增量协议)
- **T-Rx**: 渲染任务 (R1=4× IP HDMI 冲突, R2=slicemap LUT, R3=mesh slice 集成, R4=HDMI 颜色收尾, R5=HLS estimate gap)
- **T-Lx**: LED 任务 (L1=DSView trace, L2=改 panel_seq IP, L3=chain 拓扑, L4=PMOS 改板, L5=旋转机械)

## 里程碑定义 (M1-M4)

- **M1**: panel 首次点亮 (当前目标, panel 任一像素受控点亮)
- **M2**: 静态全屏 8-bit 显示稳定
- **M3**: 旋转 + POV 出像 (能看到漂浮 3D 物体)
- **M4**: 30 fps 全速 (终目标)

## 跨部门预算估算 (M1-M4 总)

~15K-35K 元, 不含人力。M1 阶段最紧急: PMOS 样品 + ICND1069 备件 + DSLogic 升级 + 实验室电源 (~3-5K)。

## 维护原则

- 用户修改/再次要求整理时直接 Edit 这个文件而不是 Write 重写
- 状态变更 (任务完成/里程碑达成/新卡点) 时更新对应章节并改顶部日期
- 任务 ID 跟里程碑都已固定, 添加新任务沿用 T-Cx/T-Rx/T-Lx 编号
