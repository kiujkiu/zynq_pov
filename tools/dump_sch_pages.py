import sys, pypdf
r = pypdf.PdfReader(r"D:\芯片资料\zynq7020-484\01_硬件资料\SCH_Schematic1_2024-10-07.pdf")
for i in [6, 7]:
    text = r.pages[i].extract_text()
    print(f"=== Page {i+1} ({len(text)} chars) ===")
    with open(rf"D:\claude_workspace\pov3d\zynq_pov\tools\sch_p{i+1}.txt", "w", encoding="utf-8") as f:
        f.write(text)
