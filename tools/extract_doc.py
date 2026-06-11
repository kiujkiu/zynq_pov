"""Extract .doc text via olefile WordDocument stream parsing."""
import olefile, re, sys
path = r"D:\claude_workspace\pov3d\zynq_pov\docs\P0.9375COB规格书Z.doc"
ole = olefile.OleFileIO(path)
for s in ole.listdir():
    if "WordDocument" in s:
        with ole.openstream(s) as f:
            data = f.read()
        # 提取 UTF-16-LE 区段, 过滤连续非控制字符
        text16 = data.decode('utf-16-le', errors='replace')
        # 找连续的可读字符串 (>= 3 chars)
        out = []
        cur = []
        for ch in text16:
            o = ord(ch)
            if (32 <= o < 127) or (0x4E00 <= o <= 0x9FFF) or ch in '\r\n\t':
                cur.append(ch)
            else:
                if len(cur) >= 3:
                    out.append("".join(cur))
                cur = []
        if cur: out.append("".join(cur))
        text = "\n".join(out)
        with open(r"D:\claude_workspace\pov3d\zynq_pov\panel_spec.txt", "w", encoding="utf-8") as fp:
            fp.write(text)
        print(f"extracted {len(text)} chars, {len(out)} segments")
        break
