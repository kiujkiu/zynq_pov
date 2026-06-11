from pypdf import PdfReader
out = []
r = PdfReader(r"D:\claude_workspace\pov3d\zynq_pov\docs\ICND3019_datasheet_CN_V2.0_20220106.pdf")
for i, p in enumerate(r.pages):
    out.append(f"=== PAGE {i+1} ===")
    out.append(p.extract_text())
with open(r"D:\claude_workspace\pov3d\zynq_pov\icnd3019_ds.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(out))
print(f"OK {len(out)//2} pages")
