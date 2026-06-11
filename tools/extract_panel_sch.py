from pypdf import PdfReader
r = PdfReader(r"D:\claude_workspace\pov3d\zynq_pov\docs\C2-P0.9375-ICND2065-RT5960-IC-SCH.pdf")
for i, p in enumerate(r.pages):
    print(f"=== PAGE {i+1} ===")
    print(p.extract_text())
