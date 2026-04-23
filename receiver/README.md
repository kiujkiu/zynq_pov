# Zynq 侧 POV3D 接收端

C 实现的协议解码器 + lwIP RAW API TCP 服务骨架,用于在 Zynq-7020 裸机下接
收 `D:\workspace\host` 发来的 MODEL_DEF / FRAME / BYE 流。

## 文件清单

| 文件 | 用途 |
|---|---|
| `pov3d_protocol.h` | 协议线上格式定义,与 `host/protocol.py` 一一对应 |
| `pov3d_decoder.h/.c` | 字节流状态机,输入字节,输出回调(**与 lwIP 无关,可主机测试**) |
| `pov3d_lwip.h/.c` | lwIP RAW API TCP 服务,把接收到的 pbuf 喂给 decoder |
| `pov3d_main.c` | 裸机 main 骨架:初始化网络 + 启动服务 + 主循环 |
| `test_decoder.c` | 主机 Linux 下的烟雾测试,TCP 连到 Python server 跑一遍 |

## 编译主机端烟雾测试(先验证 C 解码器)

Zynq 板子还没就绪时,**可以在 PC 上先跑 C 解码器测试**,确认理解协议
无误。任一 POSIX 环境(WSL / Linux / MSYS2 / MinGW)均可:

```bash
# WSL / Linux
sudo apt install gcc           # 若未装
cd D:\workspace\zynq_pov\receiver    # 在 WSL 里是 /mnt/d/workspace/zynq_pov/receiver
gcc -Wall -O2 -std=c99 test_decoder.c pov3d_decoder.c -o test_decoder

# Windows MinGW / MSVC:
gcc -Wall -O2 -std=c99 test_decoder.c pov3d_decoder.c -o test_decoder.exe
# 或 cl.exe test_decoder.c pov3d_decoder.c  (MSVC)
```

然后按阶段 2 的流程:一边起 Python server,一边跑 C 测试:

```
# 窗口 A
cd D:\workspace\host
python server.py

# 窗口 B
./test_decoder --max-frames 120
```

C 测试的输出与 `receiver.py` 应当完全一致(frame_id / bone0_t 值一致),
区别只是前缀 `[c]` vs `[receiver]`。

## 集成到 Vitis 工程(Zynq-7020)

**假设**:你已经能跑通 Vitis 自带的 "LwIP Echo Server" 模板(能 ping 板子,
nc 能收到 echo)。

### 步骤

1. Vitis 里新建应用工程:`Application Project → Template: lwIP Echo Server`,
   BSP 用 standalone,lwIP 版本跟模板默认一致即可。
2. **删除** 模板生成的 `echo.c`。
3. 把本目录的 5 个文件复制进 Vitis 工程的 `src/`:
   - `pov3d_protocol.h`
   - `pov3d_decoder.h` `pov3d_decoder.c`
   - `pov3d_lwip.h`    `pov3d_lwip.c`
   - `pov3d_main.c`(如果模板已有 `main.c`,把其中的 `start_application()`
     调用替换为 `pov3d_lwip_start(...)`,不要两份 main)
4. 改 `pov3d_main.c` 里的 `ipaddr` / `netmask` / `gw` 匹配你的局域网。
   如果想用 DHCP,照抄 Xilinx 模板 `main.c` 里对应的 `#if LWIP_DHCP` 代码。
5. Build → Program FPGA → Run。串口应打印:
   ```
   [pov3d] listening on :9000, waiting for host...
   ```
6. PC 上:确保 Python server `--host 0.0.0.0`(或留 `127.0.0.1` 但要改成
   Zynq IP),然后:
   ```powershell
   python server.py --host 0.0.0.0
   ```
   Zynq 主动 *不是* 监听端,它也在监听——这里反了。
   实际流程见下一节。

### 谁主动连接

**Zynq 做 TCP client,PC 做 TCP server**(`python server.py` 保持不变)。

- 板子上电后每 1 秒尝试连接 PC `:9000`,连上就开始接收
- 连接断开或异常后自动重连,无需人工介入
- PC 也可以随时重启 server,Zynq 会自动重连

把 `pov3d_main.c` 里的 `IP4_ADDR(&host_ip, 192,168,1,100)` 改成你 PC 的
IP(用 `ipconfig` 查一下),然后 PC 那侧:

```powershell
cd D:\workspace\host
python server.py --host 0.0.0.0
```

(`--host 0.0.0.0` 让 server 监听所有网卡,Zynq 才能从局域网连进来。)

## 内存占用提示(Zynq-7020)

- `pov3d_decoder_t`(BSS):512 KB(`POV3D_MAX_PACKET`)
- `pov3d_main.c` 模型缓存:256 KB 顶点 + 128 KB 索引 = 384 KB
- 合计 ~900 KB,都在 DDR,对 Zynq-7020 的 1 GB DDR 毫无压力。
- 如果你想省内存:把 `POV3D_MAX_PACKET` 调小(但要 ≥ 你实际 MODEL_DEF 包大小),
  或改成流式处理(直接把顶点字节 DMA 写进 voxelizer,无需落地在 CPU 缓存)。

## 协议速记

字节序:全部小端,Cortex-A9 默认小端,结构体可直接 memcpy。

```
每个包: pov3d_header_t (12B) + payload (payload_len B)

MODEL_DEF payload:
    pov3d_model_def_t (44B)
    顶点数据 (vertex_count * vertex_stride B)
    索引数据 (index_count * 4 B)

FRAME payload:
    pov3d_frame_hdr_t (12B)
    对每个物体:
        model_id(2) + bone_count(2) = 4B
        model_matrix[16]              = 64B
        骨骼矩阵 bone_count * floats_per_bone * 4B
        其中 floats_per_bone = (flags & FLAG_SKIN_MAT34) ? 12 : 16
```

## 如果要做 C 解码器的单元测试

`test_decoder.c` 目前直接连 TCP。如果想做离线测试(不依赖 Python server
运行),可以:

1. 用 Python 把一段流 dump 到文件:
   ```python
   # 临时改 server.py 的 sendall() 把字节也写到 capture.bin
   ```
2. C 测试读 capture.bin,一次性喂给 `pov3d_decoder_feed`。
3. 这样可以在 CI 里跑,不需要开 server。

我没默认做这个,保持测试足够简单。有需要告诉我。
