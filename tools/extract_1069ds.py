from pypdf import PdfReader
out = []
r = PdfReader(r"D:\claude_workspace\pov3d\zynq_pov\docs\ICND1069_datasheet_CN_2023_V1.1.pdf")
for i, p in enumerate(r.pages):
    out.append(f"=== PAGE {i+1} ===")
    out.append(p.extract_text())
with open(r"D:\claude_workspace\pov3d\zynq_pov\icnd1069_ds.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(out))
print(f"OK {len(out)//2} pages")
