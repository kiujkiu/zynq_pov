# 怎么从 .SchDoc 直接抽网表（以及为什么不能只信 PDF）

## 起因

核转接板线序时，第一反应是用既有的 `mlkpai_fs03/tools/sch_netlist.py`
（从 Altium 打印的 PDF 里捞隐藏文本 `PI<位号><pin>` / `NL<网名>`）。
但 `zynq-lxb_2260_led4048V0.1/SCH/` 下：

```
LKS_FOC.SchDoc   2026-08-13 21:21   286 KB   ← 2260 的真内容
LKS_FOC.pdf      2026-07-27 15:25   220 KB   ← 和 pV1.2 那份**字节数完全一样**, 是老屏的图
```

PDF 里出现的还是 `DCLK / LAT / GCLK / R1..B3 / A / B / C`，即 1-bit 老屏那套。
**改完原理图没有重新导出 PDF。** 只看 PDF 会得出「这块板还没画 2260」的错误结论。

⇒ 以后核任何板子，先比 `.SchDoc` 与 `.pdf` 的时间戳；PDF 更旧就别用它。

## 工具

`tools/schdoc_netlist.py`，只依赖 `olefile`（WSL 里已装）。

```bash
python3 tools/schdoc_netlist.py "/mnt/d/工程项目/硬件/pov/zynq-lxb_2260_led4048V0.1/SCH/LKS_FOC.SchDoc" --only J1,P1
```

原理：`.SchDoc` 是 OLE 复合文档，`FileHeader` 流是「4 字节长度 + `|KEY=VAL|…`」记录串。
用到的记录类型：

| RECORD | 含义 | 用到的字段 |
|---|---|---|
| 1 | 元件 | `LIBREFERENCE` / `COMPONENTDESCRIPTION` |
| 2 | 引脚 | `OWNERINDEX` `DESIGNATOR` `LOCATION.X/Y` `PINLENGTH` `PINCONGLOMERATE` |
| 27 | 导线 | `LOCATIONCOUNT` `X1..Xn` `Y1..Yn` |
| 25 / 17 | 网络标号 / 电源端口 | `TEXT` `LOCATION.X/Y` |
| 34 | 位号 | `OWNERINDEX` `TEXT`（`NAME=Designator`） |

两个坑：

1. **引脚的电气连接点不是 `LOCATION`**，而是从 `LOCATION` 沿
   `PINCONGLOMERATE[1:0]`（0=右 1=上 2=左 3=下）外推 `PINLENGTH`。
   校验方法：未连接引脚上会放 No-ERC 标记（RECORD=29），它的坐标正好落在外推后的点上。
2. **T 形连接**：一根线的端点落在另一根线的中间时，两者没有共同端点。
   必须额外做「点在线段上」的判定再并起来，只并端点会把一张网切成好几块。

`RECORD=1` 的位号要用 `OWNERINDEX = 元件记录下标 − 1` 去查（记录下标 1-based）。

## 用它得到的东西

见 `00_board_and_protocol.md` §2 的完整网表。另外顺手确认了
`zynq-mlp_2260V0.1`（米联派那块）是半成品：J1 侧画了 2260 信号，P1 侧还没接上去。
