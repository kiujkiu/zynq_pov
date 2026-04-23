# POV Projection HLS IP

PL 侧 3D 投影加速器. 输入点云 + 角度, 输出切片像素写到 DDR.

## 文件

| 文件 | 作用 |
|------|------|
| `pov_project.h`   | 公共接口定义 (point_t struct, 常量) |
| `cos_sin_lut.h`   | 72 个角度的 cos/sin 定点查表 |
| `pov_project.cpp` | HLS top function, 带 `#pragma` 综合指示 |
| `testbench.cpp`   | csim 用的软件参考比对测试 |
| `run_hls.tcl`     | 批处理综合脚本 |

## 下一步 (明天做)

### 1. 验证 HLS 安装
```powershell
where vitis_hls
# 应该输出 D:\Vitis\2024.2\bin\vitis_hls.bat
```

### 2. 跑综合 (约 2-5 分钟)
```powershell
cd D:\workspace\zynq_pov\hls_proj
D:\Vitis\2024.2\bin\vitis_hls.bat -f run_hls.tcl
```

成功会看到:
- `proj_pov/solution1/syn/report/pov_project_csynth.rpt` 综合报告 (检查 II=1, 时序收敛)
- `proj_pov/solution1/impl/ip/pov_project_ip.zip` 打包好的 IP

### 3. 检查综合报告
```
打开 proj_pov/solution1/syn/report/pov_project_csynth.rpt, 确认:
 - Timing: Target 6.67ns, Estimated ≤ 6.67ns (150MHz 通过)
 - Loop POINTS_LOOP: Initiation Interval (II) = 1
 - DSP48E usage: 合理 (应该 ~4-10 个)
 - BRAM: 最好是 0 或很少 (我们没有大内部存储)
```

### 4. 把 IP 加到 Vivado
需要写个 TCL 脚本:
- 在 `02_hello_zynq` 工程里 Settings → IP Repository 加
  `D:\workspace\zynq_pov\hls_proj\proj_pov\solution1\impl\ip\`
- BD 右键 Add IP 搜 "POV Project Engine"
- 接线:
  - `m_axi_gmem0` → axi_smc_hp (读模型)
  - `m_axi_gmem1` → 另一个 SmartConnect → PS S_AXI_HP0 (写帧缓冲)
  - `s_axi_control` → axi_smc (原来那个 AXI-Lite SmartConnect)
  - 时钟 / 复位: 全部 FCLK_CLK1 + proc_sys_reset_0

### 5. 改 ARM 代码
用生成的驱动 `xpov_project.h`:
```c
XPov_project pov;
XPov_project_Initialize(&pov, XPAR_POV_PROJECT_0_BASEADDR);

/* 在 DDR 放模型一次 */
#define MODEL_ADDR 0x20000000UL  /* 512MB 处, 避开 FRAMEBUF */
memcpy((void*)MODEL_ADDR, hardcoded_model, sizeof(hardcoded_model));
Xil_DCacheFlushRange(MODEL_ADDR, sizeof(hardcoded_model));

/* 每帧 72 次 */
for (int n = 0; n < 72; n++) {
    int col = n % 12, row = n / 12;
    XPov_project_Set_model(&pov, MODEL_ADDR);
    XPov_project_Set_num_points(&pov, NUM_POINTS);
    XPov_project_Set_angle_idx(&pov, (n + phase) % 72);
    XPov_project_Set_fb(&pov, FRAMEBUF_ADDR);
    XPov_project_Set_fb_stride(&pov, STRIDE);
    XPov_project_Set_dst_x(&pov, col * SLICE_W);
    XPov_project_Set_dst_y(&pov, row * SLICE_H);
    XPov_project_Start(&pov);
    while (!XPov_project_IsDone(&pov)) {}
}
```

## 预期性能 (设计目标)

假设模型 10,000 点, 72 个角度, 150MHz 综合目标:
- 渲染一片 (10K 点 + 清区): ≈ 10000 + 106*120 cycles = 22720 cycles
- 72 片/frame = 72 × 22720 = 1.64M cycles
- @150MHz = 10.9 ms/frame → **~92 FPS**

对比当前 ARM-only: ~45 FPS @ 300 点模型
→ HLS 版支持 30+ 倍点数, 刷新率翻倍

## 可能踩坑提醒

1. **pragma 不识别**: 老版 HLS 用 `#pragma HLS` 要写在循环内或函数头紧跟, 位置很严格
2. **struct 布局**: HLS 综合时 struct 拆分成多个端口信号, `_pad` 字段可能被优化掉也可能没有. 如果 AXI burst 性能差, 调 `point_t` 成 `ap_uint<128>` 裸打包
3. **AXI master burst**: 默认可能是单拍读写. 加 `#pragma HLS INTERFACE m_axi max_read_burst_length=256 bundle=gmem0`
4. **fb 写入是随机地址**: 投影点散落, 所以写是非连续的. 如果吞吐是瓶颈, 改成先写到内部 BRAM, 结束后 DMA 出去. 本初版先用随机写, 看性能再定
5. **csim 失败**: 一般是参考实现和 HLS 算法不一致. 把 ref_project 的运算对齐 pov_project 每一行即可
6. **综合时序超 6.67ns**: 降到 10ns (100MHz) 重跑. 或者给 loop 加 `#pragma HLS PIPELINE II=2`
