from pypdf import PdfReader
out = []
r = PdfReader(r"D:\claude_workspace\pov3d\zynq_pov\docs\ICND1069_编程指导_CN_2024_V1.2_深圳映己鸿鹄科技有限公司专用.pdf")
for i, p in enumerate(r.pages):
    out.append(f"=== PAGE {i+1} ===")
    out.append(p.extract_text())
with open(r"D:\claude_workspace\pov3d\zynq_pov\icnd1069_prog.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(out))
print("OK")
