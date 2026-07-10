---
name: pov3d-2026-06-16
description: 每级数据(传输/清网格/散射/gather/显示)+ 128²/200²/400² 分辨率对比(点数/网格/切片/gather时间/BRAM能否塞)+ 200×200全链改造卡物理panel; 完整 HTML 报告
metadata: 
  node_type: memory
  type: project
  created_at: 2026-06-16 15:42 CST
  updated_at: 2026-06-16 15:42 CST
  originSessionId: 241cce13-9bee-40a1-a353-d0f7b04250fa
---

完整 HTML: **`D:\claude_workspace\pov3d\onchip_pipeline_report.html`** (8节全级数据).

## 每级数据 (B1, 128²×720)
① 点云传输 1.6-2MB/帧 (链路定: JTAG~MB/s, GEM0 110MB/s, ESP32 0.1-2Mbps) ② 清网格 8MB ~7ms ~1.1GB/s ③ 散射 读2MB+写0.5MB ~1-5ms 随机写延迟bound ④ **gather 读47MB(11.8M×4B随机)+写5.76MB ~880ms = 瓶颈(DDR随机读55ns/次)** → B1合计 **~900ms实测** ⑤ 显示 8KB/片 **9800片/s**(102µs) HP2 48-78MB/s. 体帧率上限 9800÷720=**13.6/s**. HP1=生成/HP2=显示/HP0=VDMA 隔离.

## 资源 (impl)
整设计: LUT 24.3% / FF 15.9% / BRAM 35.4% / DSP 14.5%. pov_render_full IP: BRAM 51×18K, DSP 16, FF 9293, LUT 12474, Fmax 205MHz. 余量大.

## 分辨率对比
| | 128²×720(现) | 200²×540 | 400²×720 |
|点数| ~13万 | **~30万** | ~100万 |
|网格彩色×4B| 128³=8MB | 200³=32MB | 400³=256MB |
|切片compact| 5.76MB | 10.8MB | 57.6MB |
|gather随机读| 11.8M | 21.6M | 115M |
|gather时间DDR| ~0.88s | **~1.6s** | **~9s** |
|panel像素/片| 16384 | 40000 | 160000 |
|单色1bit网格塞BRAM(4.9Mb)| **2.1Mb能✓** | 8Mb不能 | 64Mb不能 |
|7020可行| 现役 | 勉强(静态可) | 需UltraScale+ |
**关键拐点**: 只有 128³单色(2.1Mb)能进 7020 BRAM → 才有1-cycle提速(gather~80ms实时); 200³+及彩色全塞不下→只能DDR随机读(慢). 网格放DDR没问题(32/256MB随便放), 慢只对"每帧实时30fps"才卡; 静态/预算循环DDR完全够.

## 200×200×540 全链改造 (卡物理 panel)
可改(render数学): G 128³→200³, 切片720→540, 点数~30万. ⛔卡: panel变换/pack/transform_lut/显示IP/物理panel 全编码 dual 128×64 布局, 必须先定 **几块panel/怎么拼/原生扫描尺寸+色序+朝向/几条SDI** 才能改输出链. 200×200 静态在7020可做(DDR轻松,gather1.6s), 限制=实时动画(BRAM装不下8Mb)+panel驱动(48-SDI). 比400×400现实. 关联 [[project_pov3d_hls_onchip_render]] [[project_pov3d_linux_wifi_anim_feasibility]] [[project_pov3d_48sdi_io_plan]] [[project_pov3d_final_target]].
