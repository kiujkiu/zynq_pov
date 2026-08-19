#!/usr/bin/env python3
"""
schdoc_netlist.py -- 直接从 Altium .SchDoc 抽网表 (不用装 Altium, 不用导 PDF)

为什么要它: 2260 转接板的 PDF 是 7 月的旧版, 08-13 改完 SCH 没重新导出。
既有的 mlkpai_fs03/tools/sch_netlist.py 是从**打印出来的 PDF** 里捞隐藏文本的,
源文件更新了而 PDF 没更新时就用不上。这个直接读 .SchDoc。

原理:
  .SchDoc 是 OLE 复合文档, `FileHeader` 流里是一串「4 字节长度 + |KEY=VAL|... 」记录。
  RECORD=1 元件 / =2 引脚 / =27 导线 / =25 网络标号 / =17 电源端口 / =34 位号。
  引脚的电气连接点在 LOCATION 沿 PINCONGLOMERATE[1:0] 指的方向外推 PINLENGTH。
  然后按坐标做并查集, 连上「端点落在别的线段中间」的 T 形连接。

⚠ 两个已知限制:
  * 靠**同名网络标号**跨图连接的网, 这里会打印成同名的多条 —— 本工具只做几何连接,
    合并同名网请看输出里重复出现的网名。
  * 电源端口 (RECORD=17) 当普通标号处理, 够用。

用法:
  python3 tools/schdoc_netlist.py <file.SchDoc> [--only J1,P1]
"""
import sys
import collections

try:
    import olefile
except ImportError:
    raise SystemExit("需要 olefile:  pip install olefile")


def records(path):
    data = olefile.OleFileIO(path).openstream("FileHeader").read()
    out, i = [], 0
    while i + 4 <= len(data):
        n = int.from_bytes(data[i:i + 4], "little") & 0xFFFFFF
        if n == 0 or i + 4 + n > len(data):
            break
        out.append(data[i + 4:i + 4 + n].rstrip(b"\x00").decode("gbk", "replace"))
        i += 4 + n
    return out


def kv(rec):
    d = {}
    for f in rec.split("|"):
        if "=" in f:
            k, v = f.split("=", 1)
            d[k] = v
    return d


ROT = {0: (1, 0), 1: (0, 1), 2: (-1, 0), 3: (0, -1)}


def netlist(path):
    D = [kv(r) for r in records(path)]

    desig = {}
    for d in D:
        if d.get("RECORD") == "34" and d.get("NAME") == "Designator":
            desig[int(d["OWNERINDEX"])] = d.get("TEXT")

    def F(d, k):
        return float(d.get(k, 0))

    parent = {}

    def find(a):
        parent.setdefault(a, a)
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb

    segs, wpts = [], set()
    for d in D:
        if d.get("RECORD") == "27":
            n = int(d.get("LOCATIONCOUNT", "0"))
            pts = [(F(d, f"X{i}"), F(d, f"Y{i}")) for i in range(1, n + 1)]
            for a, b in zip(pts, pts[1:]):
                segs.append((a, b))
                union(a, b)
                wpts.add(a)
                wpts.add(b)

    pins = []
    for d in D:
        if d.get("RECORD") == "2":
            oi = int(d.get("OWNERINDEX", "-1"))
            dx, dy = ROT[int(d.get("PINCONGLOMERATE", "0")) & 3]
            L = F(d, "PINLENGTH")
            p = (F(d, "LOCATION.X") + dx * L, F(d, "LOCATION.Y") + dy * L)
            pins.append((desig.get(oi, f"?{oi}"), d.get("DESIGNATOR", ""), p))

    labels = [(d.get("TEXT"), (F(d, "LOCATION.X"), F(d, "LOCATION.Y")))
              for d in D if d.get("RECORD") in ("25", "17")]

    def on_seg(p, a, b):
        (x, y), (x1, y1), (x2, y2) = p, a, b
        if (min(x1, x2) - .01 <= x <= max(x1, x2) + .01 and
                min(y1, y2) - .01 <= y <= max(y1, y2) + .01):
            return abs((x2 - x1) * (y - y1) - (y2 - y1) * (x - x1)) < 1e-6
        return False

    for p in list(wpts) + [p for _, _, p in pins] + [p for _, p in labels]:
        find(p)
        for a, b in segs:
            if on_seg(p, a, b):
                union(p, a)

    names = collections.defaultdict(set)
    for t, p in labels:
        names[find(p)].add(t)

    nets = collections.defaultdict(list)
    for des, pd, p in pins:
        nets[find(p)].append(f"{des}.{pd}")
    return names, nets


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    path = sys.argv[1]
    only = None
    if "--only" in sys.argv:
        only = set(sys.argv[sys.argv.index("--only") + 1].split(","))

    names, nets = netlist(path)
    rows = []
    for r, pl in nets.items():
        if only:
            pl = [x for x in pl if x.split(".")[0] in only]
            if not pl:
                continue
        rows.append(("/".join(sorted(names.get(r, ["(unnamed)"]))), sorted(pl)))
    for nm, pl in sorted(rows):
        print(f"{nm:22s}: " + "  ".join(pl))


if __name__ == "__main__":
    main()
