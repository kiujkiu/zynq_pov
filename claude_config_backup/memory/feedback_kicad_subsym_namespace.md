---
name: KiCad lib_symbols 子符号名 NOT 加 library namespace
description: 自制 symbol 时, leaf 用 "Lib:Name" 但 sub-symbol (_0_1/_1_1) 只能用 "Name_0_1", 加 ":" 前缀 KiCad load 失败
type: feedback
originSessionId: 37aa49b2-ddd9-4c38-a89f-2bf1258edd1c
---
**规则**: 嵌入 .kicad_sch 的 lib_symbols 时, leaf symbol 名带 library 前缀 `(symbol "Lib:Name" ...)`, 但其内部 sub-symbol 必须 BARE name `(symbol "Name_0_1" ...)`, 不能用 `(symbol "Lib:Name_0_1" ...)`.

**Why**: 实测 — 写带 namespace 前缀的 sub-symbol 后 `kicad-cli sch erc` 报 "加载原理图失败" 直接拒绝 load. 改 bare 名后 load 正常.

证据: 看 KiCad 标准库 (`C:\Program Files\KiCad\10.0\share\kicad\symbols\*.kicad_sym`) — leaf 是 `(symbol "AMS1117-3.3" ...)` (bare 因为单 lib 文件没 namespace), sub 是 `(symbol "AMS1117-3.3_0_1" ...)`. 我 flatten extends 时 leaf 加上 `Regulator_Linear:` 前缀但 sub-symbol 不加, 这个组合 KiCad 接受.

**How to apply**:
- `kicad_sch_lib.py` 的 `define_chip()` 已经处理: `bare_name = lib_id.split(":")[-1]`, sub 用 bare_name.
- `flatten_extends()` 也保持 sub 的 bare 名.
- 写 .kicad_sym 独立 lib 文件时 leaf 不带前缀也 OK (库本身就是 namespace).

**其他 KiCad 10 坑** (一起记):
- 独立 `.kicad_sym` lib 文件头: `(version 20251024)` `(generator "kicad_symbol_editor")` — 跟 `.kicad_sch` 不同 (`(version 20260306)` `(generator "eeschema")`)
- pin_numbers/pin_names 在 lib_symbols 嵌入版本是 OPTIONAL — 没写也 load 成功
- lib_id 要匹配 sym-lib-table 里的某个 lib (否则 warning `lib_symbol_issues`, 但不阻止 ERC). 我用 `zynq7020_dev_local:` 因为它已经在 sym-lib-table 里.
