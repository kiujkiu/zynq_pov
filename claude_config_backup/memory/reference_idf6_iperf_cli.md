---
name: IDF v6 iperf example CLI + iperf2.exe 位置
description: ESP32 iperf example v6 命令语法（命令改名了）+ Win 端 iperf2 二进制位置
type: reference
originSessionId: 8002516f-20d0-4b20-8757-a51821fbfd7d
---
ESP-IDF v6 把 iperf example 的 CLI 命令改了，老语法 (`sta -s SSID -p PASS`) 不通。

**WiFi 控制**
```
wifi_scan                              # 列周围 AP
wifi_band <2g|5g|auto> --current       # 切频段
sta_connect <SSID> <PASS> [-n <ch>]    # 连 AP，-n 强制信道
sta_disconnect                         # 断开
wifi_config_query sta                  # 看当前连接 channel/BW/phymode
```

**iperf**
```
iperf -s -i <interval>                 # TCP server
iperf -s -u -i <interval>              # UDP server
iperf -c <ip> -i 1 -t 60               # TCP client
iperf -c <ip> -u -b 100000000 -i 1 -t 60   # UDP client (100Mbps)
iperf --abort                          # 停 iperf（不是 -a）
```

**性能 stats**
```
wifi_stats tx disable                  # 关 TX 周期统计（默认 enable，超吵）
wifi_stats rx disable                  # 关 RX 周期统计
wifi_stats tx get                      # 一次性查
```

**SSID 含空格**：必须双引号包 `"iPhone 13"`

**串口注意**：`iperf -s -i 3` 启动时不打印 "Server listening"，直接看 PC client 端能不能连上就行。

**iperf2 Windows 二进制位置**
- 路径：`D:\esp-idf\examples\wifi\iperf\iperf2bin\iperf-2.0.9-win64\iperf.exe`
- ESP32 iperf example 走 **iperf2 协议**，不是 iperf3，PC 端必须用 iperf2 client
- 从 iperf.fr 下载时 **2.0.9 能解压**；2.1.x / 2.2.x 的 zip PowerShell `Expand-Archive` 会失败，要么换 `tar -xf`，要么直接用 2.0.9

**Why:** 第一次跑 v6 iperf 时被 `sta` 命令改名 `sta_connect` 浪费了一轮测试；写下来下次省事。

**How to apply:** 任何 ESP32 iperf 测试直接 copy 上面的命令；脚本驱动串口时记得用 `sta_connect` 而不是 `sta`。
