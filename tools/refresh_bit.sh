#!/usr/bin/env bash
# refresh_bit.sh — 从 Vivado 导出的 XSA 提取新 bitstream，覆盖 Vitis 工程里所有缓存副本
# 用法:   bash refresh_bit.sh <vitis_project_root>
# 示例:   bash refresh_bit.sh /mnt/d/workspace/zynq_pov/02_hello_zynq
#
# 背景 (2026-04-21 踩坑记):
# Vitis 2024.2 Unified 的 "Clean + Build Platform" 会重建 BSP 里的 xparameters.h，
# 但不会更新 hello_plat/hw/*.bit 和 hello_world/_ide/bitstream/*.bit 这几个 Run
# 启动配置真正下载到 PL 的 bit 副本。结果就是 xparameters.h 里看得到新 IP，
# 但板子跑的还是旧 bit，PL 里根本没有那些 IP → 数据访问 abort.
#
# 本脚本解决的是那一层：只搬 bit，不碰 BSP（BSP 由 Vitis Build 负责）。

set -euo pipefail

PROJ_ROOT="${1:-}"
if [[ -z "$PROJ_ROOT" || ! -d "$PROJ_ROOT" ]]; then
  echo "用法: bash refresh_bit.sh <vitis_project_root>"
  echo "例:   bash refresh_bit.sh /mnt/d/workspace/zynq_pov/02_hello_zynq"
  exit 1
fi

XSA=$(ls "$PROJ_ROOT"/*.xsa 2>/dev/null | head -1)
if [[ -z "$XSA" ]]; then
  echo "ERROR: 找不到 $PROJ_ROOT/*.xsa，先在 Vivado 做 Export Hardware"
  exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "源 XSA: $XSA"
python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$XSA" "$TMP"

SRC_BIT="$TMP/hello_zynq_wrapper.bit"
if [[ ! -f "$SRC_BIT" ]]; then
  # 兜底: 找任意一个 .bit
  SRC_BIT=$(find "$TMP" -maxdepth 2 -name '*.bit' | head -1)
fi
if [[ -z "$SRC_BIT" || ! -f "$SRC_BIT" ]]; then
  echo "ERROR: XSA 里没 .bit，Vivado Export Hardware 时没勾 Include bitstream？"
  exit 1
fi
echo "新 bit 大小: $(stat -c %s "$SRC_BIT") bytes  ($(stat -c %y "$SRC_BIT"))"

COUNT=0
while IFS= read -r -d '' dst; do
  cp "$SRC_BIT" "$dst"
  echo "  updated: $dst"
  COUNT=$((COUNT+1))
done < <(find "$PROJ_ROOT/vitis_ws" -name '*.bit' -print0 2>/dev/null)

if [[ $COUNT -eq 0 ]]; then
  echo "WARN: $PROJ_ROOT/vitis_ws 下没找到任何 .bit 副本，可能 Vitis 工程路径不同"
  exit 2
fi
echo "共更新 $COUNT 个 bit 文件"
