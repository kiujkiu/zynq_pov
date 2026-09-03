# 手册全文抽取 (供 grep / agent 引用)

| 文件 | 来源 PDF | 内容 |
|---|---|---|
| `pg.txt` | `pov3d/models/ICND2260_编程指导_CN_2025_V2.8_*.pdf` | 编程指导 V2.8 |
| `ds.txt` | `pov3d/dr1v90/docs/vendor/chipone/ICND2260_datasheet_CN_2023_V1.7.pdf` | 数据手册 V1.7 |

**行号是稳定的引用锚点**, 已被多次交叉验证:
- `ds.txt:452` = 「对于 mini-LVDS 驱动端, 传输延时可设置为 1/8tLVCP, 1/4tLVCP 或 3/8tLVCP」
  (全文**仅此一处**提到转发延时, 且**没有任何寄存器定义** —— 见记忆库
   `reference_icnd2260_forward_delay_reg_absent`)
- `pg.txt:1871` = 「IREF = reg0x2d[5:4] 00:0.1mA 01:0.2mA 10:0.3mA 11:0.4mA 默认值 reg0x2d[5:4]=1」

⚠ 之前这两个文件只存在于某次会话的 scratchpad 里, 导致后来的 agent 全都读不到手册,
  却又被要求"标注【手册明确·出处】" —— 这是产生**编造出处**的完美条件。放进仓库就是为了断掉这个。
