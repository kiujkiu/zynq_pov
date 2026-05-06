# 换机迁移 + 环境安装指南

> 写于 2026-05-06，commit 起点：`f64cc4b`（HDMI 颜色 GBR 修复 + Blender PBR bake + hybrid mode 实验）。
>
> 用途：旧机太卡/重装系统，需要换电脑继续 POV3D 项目。

---

## 0. 当前进度速览

- **稳定 baseline**：USE_PL=0，ARM 渲染 + HDMI 输出，60 FPS，颜色已对齐 Windows 3D Viewer。
- **HLS IP** `pov_project_batch` 已综合好，HDMI fb 字节序统一为 **GBR**（不是标准 BGR）。
- **Blender bake (Option A)** 已完成：`host/anime_62459_baked.glb` 把 PBR + IBL 烘焙到 texture，主机端 `voxelize_mesh` 用三角形质心 + max-area-wins 体素化。
- **未解 bug（任务 #38 / #39）**：USE_PL=1 时 PL 的 m_axi 写 ring DDR 失败（ring nz=0/100K，但 ap_start fire 正常）。怀疑 Vivado BD 的 `axi_smc_pov_hp/S00_AXI` m_axi 路由回归。需要 ChipScope ILA 或 BD 检查。
- 软件 hybrid mode（boot 用 ARM 渲染、收到 anime 后切 PL）框架已写好，但被上面这个硬件 bug 阻塞。

---

## 1. 旧机出发前必做

### 1.1 推送代码
```bash
cd /mnt/d/workspace/zynq_pov
git status                       # 确认 working tree 干净
git push origin master           # 推到 https://github.com/kiujkiu/zynq_pov
```

### 1.2 备份不在 repo 里的产物
| 文件 | 路径 | 说明 |
|---|---|---|
| Claude auto-memory | `~/.claude/projects/-home-kiujkiu-workspace-pov3d/memory/*.md` | 已经拷到 `docs/claude_memory/`，跟 repo 走，新机可还原 |
| BOOT.bin | `tools/BOOT.bin` | 4.2 MB，本地生成产物。新机要重新走 (a)→(b)→(c)→(d) 流程 |
| .xsa 平台文件 | `02_hello_zynq/hello_zynq_wrapper.xsa` | Vivado 产物，新机重综合后产生 |
| HLS IP zip | `hls_proj/proj_pov/solution1/impl/ip/*.zip` | HLS 综合产物，新机重综合后产生 |
| 鹿小班板上 QSPI 内容 | 板载 | 已烧录的 BOOT.bin 仍在板上，硬件验证不丢 |

### 1.3（可选）打包记忆备份当二保险
```bash
tar czf ~/claude_memory_pov3d.tar.gz \
    -C ~/.claude/projects -home-kiujkiu-workspace-pov3d/memory
```
拷 U 盘。但是因为已经 `cp` 进 `docs/claude_memory/`，跟 git 一起走了，这步可以跳。

---

## 2. 新机要装的软件

### 2.1 必装
| 软件 | 版本 | 安装位置建议 | 备注 |
|---|---|---|---|
| **Windows 10/11** | x64 | — | WSL2 跑 Claude Code，主程序在 Windows 端跑 Vivado/Vitis |
| **WSL2 + Ubuntu** | 22.04 LTS | — | `wsl --install -d Ubuntu` |
| **Vivado** | 2024.2 | `D:\Vivado\2024.2` | 装 Standard 版即可；带 Vitis HLS |
| **Vitis** | 2024.2 | `D:\Vitis\2024.2` | 嵌入式开发用 |
| **Cable Driver** | Vivado 自带 | 装 Vivado 时勾选 | 不然 JTAG 烧 bit / boot.bin 烧 QSPI 都识别不了 |
| **Python** | 3.10+ | Win + WSL 都装 | 主机端发送脚本 |
| **USB-UART 驱动** | 看板上 USB 桥 | — | 鹿小班一般是 CP210x（Silicon Labs）。装完 COM 号会变，记得改脚本 |
| **Git** | 任意 | — | Win + WSL 都装 |

### 2.2 Python 包（在 Win 端 cmd 跑）
```cmd
pip install pyserial trimesh numpy pillow pygltflib pyqt6 obs-websocket-py
```

### 2.3 Claude Code（WSL 内）
```bash
npm install -g @anthropic-ai/claude-code
# 或按照 https://claude.com/claude-code 最新指南
```

### 2.4 可选（高级功能）
| 软件 | 用途 |
|---|---|
| **Blender 4.2 LTS** | 重新跑 `host/blender/bake_pbr.py` 烘焙新模型 |
| **OBS Studio + obs-websocket** | `tools/capture_obs.py` 抓 HDMI 输出做对照 |
| **VS Code** | 编辑 + Vivado / Vitis 之外的开发 |

---

## 3. 新机恢复仓库

### 3.1 路径选择（重要）
**强烈建议保持** `D:\workspace\zynq_pov` （WSL 看就是 `/mnt/d/workspace/zynq_pov`）。原因：

- `tools/bd_use_batch_ip.tcl` 第 6-8 行写死了 `D:/workspace/zynq_pov/...` 绝对路径
- `hls_proj/run_hls.tcl` 工作目录假设也是这个
- Claude Code 的 auto-memory 路径根据 cwd 哈希，路径一致才能自动加载旧记忆

如果一定要换路径：
1. 改 `tools/bd_use_batch_ip.tcl` 里的 `proj_dir` 和 `ip_repo`
2. 把 `docs/claude_memory/*.md` 拷到新 cwd 对应的 `~/.claude/projects/<新-hash>/memory/` 下

### 3.2 克隆
```bash
mkdir -p /mnt/d/workspace
cd /mnt/d/workspace
git clone https://github.com/kiujkiu/zynq_pov.git
cd zynq_pov
```

### 3.3 还原 Claude 记忆
```bash
mkdir -p ~/.claude/projects/-home-kiujkiu-workspace-pov3d/memory
cp docs/claude_memory/*.md \
   ~/.claude/projects/-home-kiujkiu-workspace-pov3d/memory/
```
> 注：路径 hash `-home-kiujkiu-workspace-pov3d` 是从 `/home/kiujkiu/workspace/pov3d` 来的——这是旧机 Claude Code 启动时所在的目录。如果新机 Claude 启动目录是 `/mnt/d/workspace/zynq_pov`，hash 会不同；启动一次让它自动建目录，再把 md 拷进去即可。

---

## 4. 一键把硬件流水线跑回来

clone 出来的产物都不全，下面四步流程把 bitstream + ELF + BOOT.bin 重新生成。

### (a) HLS 综合 → IP 包
```cmd
cd D:\workspace\zynq_pov\hls_proj
"D:\Vitis\2024.2\bin\vitis_hls.bat" -f run_hls.tcl
```
- 时间：5–10 分钟
- 产物：`proj_pov/solution1/impl/ip/xilinx_com_hls_pov_project_batch_1_0.zip`
- 注意：`run_hls.tcl` 已注释掉 `csim_design`（旧 testbench 用 BGR 与现 IP 的 GBR 对不上，跳过不影响综合）

### (b) Vivado BD 替 IP + bitstream + .xsa
```cmd
cd D:\workspace\zynq_pov\tools
"D:\Vivado\2024.2\bin\vivado.bat" -mode batch -source bd_use_batch_ip.tcl
```
- 时间：30–50 分钟（新机第一次 IP 缓存为空更慢）
- 产物：`02_hello_zynq/hello_zynq_wrapper.xsa`
- 注意：脚本里已 `INCREMENTAL_CHECKPOINT ""` 禁用增量综合（先前 graph differ 崩过）

### (c) Vitis 编 hello_world ELF
```
1. 启 D:\Vitis\2024.2\bin\vitis.bat
2. workspace 选 D:\workspace\zynq_pov\02_hello_zynq\vitis_ws
3. Update / Re-import platform: 指向上一步的 hello_zynq_wrapper.xsa
4. Build hello_world
```
产物：`02_hello_zynq/vitis_ws/hello_world/build/hello_world.elf`

### (d) 合 BOOT.bin + 烧 QSPI
```bash
# WSL 里
cd /mnt/d/workspace/zynq_pov/tools
./refresh_bit.sh        # 把 bit + fsbl + elf 合 BOOT.bin
```
QSPI 烧录方法见 `docs/claude_memory/reference_refresh_bit_script.md`。

---

## 5. 主机端跑通

新机 COM 口大概率不是 COM10，先在 Win 设备管理器查 USB-UART 端口号，然后改：
```python
# host/test_send_one.py  第 30 行
port = "COM<新号>"   # 比如 COM5
```
然后：
```cmd
cd D:\workspace\zynq_pov\host
python test_send_one.py
# 默认: z_stretch=1.5, n=30000, anime_62459_baked.glb
```
HDMI 应该立刻显示 anime 模型，颜色与 3D Viewer 接近。

---

## 6. 下一步开发：解决任务 #38 / #39

**问题描述（详见 `docs/claude_memory/feedback_use_pl1_uart_unreliable.md`）**：

USE_PL=1 时 `pov_project_batch_0` 触发后 ap_done 正确返回，但 ring buffer DDR 区域 nz=0（应该有 ~20K 非零字节）。同 bitstream 之前实测 nz=20060 工作过，现在回归。

**怀疑**：BD 里 `pov_project_batch_0/m_axi_gmem*` → `axi_smc_pov_hp/S00_AXI` / `S01_AXI` 路由问题。

**调试建议**（按顺序）：
1. 用 Vivado 打开 BD，目视确认 `axi_smc_pov_hp` 仍连通到 `processing_system7_0/S_AXI_HP1`
2. 加 ChipScope ILA 抓 `pov_project_batch_0/m_axi_gmem0` 的 AWVALID/AWADDR/WVALID
3. 如果 AW 不发，看 ap_start 触发时 `ap_idle` 是否复位异常
4. 实在搞不定，改回 `USE_PL=0` 走 ARM 渲染（baseline 完美）

**hybrid mode 软件框架**已写在 `02_hello_zynq/vitis_ws/hello_world/src/helloworld.c`：
- `read_model_n()` noinline + DSB barrier 解决 cache stale read
- MMU 把 ring buffer 0x12000000 的 3MB 区段标 non-cacheable（属性 0x11DE2）
- main loop 根据 `model_n > 1000` 切换 ARM↔PL 渲染路径
- boot 期 ARM 渲染时塞 100K busy poll 保证 anime UART 接收稳定

只要 (b) 阶段 PL m_axi 写 DDR 修好，整个 hybrid 路径直接跑通。

---

## 7. 关键路径速查

| 想做什么 | 看哪 |
|---|---|
| 改 ARM 渲染 / hybrid 切换 | `02_hello_zynq/vitis_ws/hello_world/src/helloworld.c` |
| 改 HLS IP（fb 写、batch 流程） | `hls_proj/pov_project.cpp` |
| 重综合 HLS | `hls_proj/run_hls.tcl` |
| 重 BD + bitstream | `tools/bd_use_batch_ip.tcl` |
| 主机端发送 anime | `host/test_send_one.py` |
| 主机端体素化（mesh-aware） | `host/glb_to_points.py` `voxelize_mesh()` |
| Blender PBR bake | `host/blender/bake_pbr.py` |
| 颜色调参参考 | `docs/claude_memory/project_pov3d_color_tuning.md` |
| HDMI fb 字节序 = GBR | `docs/claude_memory/project_pov3d_hdmi_fb_byte_order.md` |
| 协议格式 PPCL | `docs/claude_memory/project_pov3d_stream_protocol.md` |
| 终极目标参数 | `docs/claude_memory/project_pov3d_final_target.md` |

---

## 8. Git 状态参考

最近主要 commit：
```
f64cc4b  HDMI 颜色 GBR 修复 + Blender PBR bake + hybrid mode 实验    ← 本次会话终点
b170584  studio lighting 改色相保留 — 修"全显白"
784d6a9  回滚增量清除尝试 — 不稳定
b11ad2a  voxelize_model 增量清除: 32MB memset → ~100us 选择性清
94fdd33  HLS pov_voxel_slice_batch 综合完成 (#29)
4d14b43  HLS 综合脚本: pov_voxel_slice_batch IP 包生成
```
