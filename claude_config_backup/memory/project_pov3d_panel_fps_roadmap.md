---
name: panel-fps-2026-06-17-128-8-5k-16-icnd2047-6bit-12k
description: 现役FM6124/128列/1bit/36M=8548fps(演示用); 后续ICND2047双沿+16列拆daisy+6bit目标12k(单缓冲实测~9500); fps公式+波形+为何不用PWM全在HTML报告
metadata: 
  node_type: memory
  type: project
  created_at: 2026-06-17 09:00 CST
  updated_at: 2026-06-22 CST
  originSessionId: 241cce13-9bee-40a1-a353-d0f7b04250fa
---

完整梳理 HTML: **`D:\claude_workspace\pov3d\panel_fps_report.html`** (公式+ASCII波形+6bit+ICND2047双沿+为何不PWM+拆daisy, 7节).

## 确认的现役配置 (2026-06-17 用户确认)
**FM6124 / 128列(不是旧memory记的16列) / 1/32扫 / 1-bit BCM / DCLK 36M(FCLK1 72M) = 8548 fps**(85.7M超频~9800). 移位卡: fps=DCLK/(链长×扫描)=36M/(128×32)=8789理想→8548实测(97%, 扣LATCH/ABCDE/OE_PRE8cyc/BLANK). 读 frame_count 0x4002000C[31:16] 2s差/2 测 fps.

## fps 公式 (任何POV驱动先算)
fps = min(移位 DCLK_eff/(链长×扫描×planes), 显示 1e9/(twOE×扫描×(2^N−1)))
临界链长 L*≈21(6bit/32扫): L>L*移位卡, L≤L*显示卡. 拆daisy 128→16 的意义=越过 L* 把瓶颈从移位搬到显示.

## 确认路线
1. **演示(现在)**: 128列 8.5k 板1 FM6124 直接跑, 转电机看实物.
2. **后续(6bit+高fps)**: 换 **ICND2047 永远双沿DDR**(25M物理=50Mbps) + **拆daisy 16列** + 6-bit.
   - 16列6bit: 移位16276 > 显示(twOE40ns)12401 → 显示卡, 理论 **12401**.
   - ⚠ **ICND2047 单缓冲只提前1plane, 藏不住LSB小plane移位(320ns>40ns) → 实测~9500**, 非12401.
   - 逼近12k: 链长砍到8列(IO翻倍) 或 换内置GCLK芯片(ICN2053/2065).
   - gamma LUT → ~9500 的6bit 感知接近8bit, 演示够.

## ICND2047 各色深速度坐实 (2026-06-22, 按 icnd2047_panel_seq.v FSM 逐拍算)

代码 `icnd2047_panel_seq.v` (模块名借 hub75e_panel_seq_v2): aclk=50MHz/20ns, DDR 1bit/拍, disp_target=t_unit<<plane.

**每扫拍数 = 移位(planes×W) + 显示((2^N−1)×t_unit) + 开销(~8/plane)**. 关键: **显示项跟链长 W 无关** → 1-bit 缩 W 涨 fps(移位卡), 8-bit 缩 W 不涨(显示 OE 卡).

| 色深 | W | overlap | 速度 | 备注 |
|---|---|---|---|---|
| **1-bit** | **128** | — | **~11.7k ✅已验证** | **当前实测配置**: `_flash_fps.tcl` 头注释 "ICND2047 1-bit 128col 32scan 50MHz" + measfps planes=1; PARAM=127; v30(79d4932 06-04)=7540 → 62031f3(06-17 纯LE脉冲砍开销)→~11.7k |
| **6-bit** | **16** | **开** | **★11.5k (t_unit=1/20ns) / ~8.5-9.5k (t_unit=2/40ns 守spec)** | 甜区, ⚠**W=16=拆daisy未来(需48lane), 非当前** |
| 6-bit | **128(当前)** | 开 | **~2k(移位卡)** | 当前单链8颗daisy, PARAM=127; 6bit想上9.5k必须先拆daisy |
| 6-bit | 16 | 关(顺序) | ~5.8k | 不 overlap 掉一半 |
| 6-bit | 128 | 开 | ~2k | 不拆 daisy 被移位卡死 |
| 8-bit | 任意 | 任意 | **~2.7k(36扫)/3.06k(32扫) 硬顶** | OE 40ns 地板, 拆/超频/overlap 都救不动 |

★ **后续提示就用: 6-bit BCM / W=16 / ICND2047 overlap**, 按扫描数线性缩放(每扫拍数不变, fps×扫数反比):

| 扫描 | t_unit=1 (20ns 借跑) | t_unit=2 (40ns 守spec) | 显示理论顶 | 体刷新(360片) |
|---|---|---|---|---|
| **32扫** | **11.5k估/11,098实测** | ~9.5k估/**8,265实测** | 12,401 | 32→26Hz |
| **36扫**(最终192×216目标) | **~10.2k** | **~7.5k** | 11,023 | ~28 / ~21Hz |

t_unit=1=20ns 是 aclk 1 拍, **违 datasheet twOE=40ns** = "借跑": LSB OE 20ns 太短 LED 电流建不起来 → 最暗 1-2 位失真, 名义 6bit 实测~4-5bit. POV+gamma LUT 下最暗位压黑里可能看不出 → 上板写 t_unit=1 跑暗场渐变实测最低位分不分得开再定. 守 40ns(t_unit=2) 是干净 6bit 但 -35% fps. gamma LUT 让 6-bit 感知≈8bit.

🔴🔴 **2026-07-02 用户scope实证: 上面 overlap ON 的 8,265/11,098 是"假6bit"!** overlap 显示窗口=`max(shift,disp_target)` → W=16 时 shift≈16拍 把小plane(disp_target<16)全撑成同宽 → **OE宽度都一样, 非1:2:4:8:16:32 → 退化成近1bit**. **真6bit(OE精确1:2:4:8:16:32)必须 overlap OFF**(S_DISPLAY精确disp_count>=disp_target), 实测 **overlap OFF t_unit=1=7,551**(真6bit). **单latch上"快overlap"与"真6bit"不可兼得** — 要梯度色就 overlap OFF吃fps损失. (详见 [[project_pov3d_icnd2047_p3_bringup]] fb数字棋盘段)

**8-bit 为何死**: BCM 金字塔 MSB=128×LSB 死锁, LSB=t_unit 被 twOE 40ns 地板焊死 → MSB 锁 5120ns, 总显示 255×40ns=10.2µs/扫 固定, 跟 W 无关 → 32扫 3064fps 顶. 想 MSB 缩到 16clk 需 LSB=2.5ns, 违地板 16×. 代码另坑: planes_cfg=reg_ctrl[15:13] 只 3-bit(1~7), **8 编不进, 要跑真 8-bit 得先加宽字段+BCM_PLANES=8**.

## ICND2047 驱动方案总结 (2026-06-29 整理, 实现方法+帧率)
IP `icnd2047_panel_seq.v`(模块名借 hub75e_panel_seq_v2), 基址 0x40020000, 128×64/32扫. FSM: S_SHIFT→S_LATCH→S_ADDR_ABCDE→S_DISPLAY→下个plane/行.
**6 个实现要点**: ① DDR双沿移位(DCLK每aclk翻, 1bit/aclk, 50Mbps/lane@25M) ② **BCM外控OE灰度**(disp_target=t_unit<<plane, 1:2:4..加权; 不用片内PWM, POV高fps正解) ③ **纯LE脉冲锁存**(S_LATCH里CLK停低无边沿→消除像素偏移, 关键fix) ④ 外部ABCDE行选(不用片内行计数器) ⑤ 色序BRG重映射(r1=pattern[B]/g1=[R]/b1=[G]) ⑥ overlap(reg1 SR移下行+reg2 latch显当前行).
**已实测**: 1-bit/W=128/32扫/50MHz = **~11.7k fps**(棋盘格实拍验证, 3根因修: 色序/纯LE偏移/IP inline防OOC缓存).
**🎯 最终目标 W=16/6bit/32扫**: 移位上限 50e6/(16×32×6)=16,276 / 显示上限 1e9/(40ns×32×63)=**12,401**(取小=显示卡); **ICND2047 单缓冲只提前1plane藏不住小plane移位(320ns>40ns) → 实测 ≈9,500 fps**(体刷新 360片~26Hz/1583RPM, 720片~13Hz). gamma LUT 感知接近8bit. **前提: 拆daisy W=16=48 lane**(6lane×8芯片独立SDI, 现W=128是6lane单链). 想破9,500上12,401: 链长砍到8(96 lane)或换ICN2053/2065内置GCLK. **8-bit 任何W都被OE40ns顶~3k**.

## 为何不用 PWM 灰度芯片(MBI5264等)
内置GCLK灰度跑满一个刷新周期=ms级 → 物理刷新15-380Hz, POV要7K+差20-460×; 无外部OE做不了BCM; SRAM对每片新图无用. POV正解=BCM外控OE(FM6124/ICND2047)非PWM内置灰度. 关联 [[project_pov3d_rotor_chip_arch]] [[reference_pov_chip_selection]] [[project_pov3d_panel_chip_pivot_2026-06-04]] [[project_pov3d_48sdi_io_plan]] [[project_pov3d_icnd2047_p3_bringup]].
