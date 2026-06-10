"""从 LXB SCH PDF page 8 抽 GPIO1 connector pin → SITE name 映射, 然后用 IBIS pkg 转 SITE → PACKAGE_PIN.
PyMuPDF 坐标抽 + Y 行对齐 (memory feedback_memory_pdf_pinout_swap.md 经验)"""
import fitz, re, os

pdf_path = r'D:\芯片资料\zynq7020-484\01_硬件资料\SCH_Schematic1_2024-10-07.pdf'
if not os.path.exists(pdf_path):
    pdf_path = r'D:\claude_workspace\pov3d\lxb_sch.pdf'

doc = fitz.open(pdf_path)
print(f"PDF: {pdf_path}, pages: {doc.page_count}")

# 找包含 "GPIO1" 跟 "PIN" 跟 "site name" pattern (IO_L..._33) 的 page
for pno in range(doc.page_count):
    page = doc[pno]
    text = page.get_text()
    if 'GPIO1' in text and 'IO_L' in text and '_33' in text:
        print(f"\n--- page {pno+1} matches GPIO1 ---")
        # raw text 看看
        words = page.get_text("words")
        # extract IO_L*_33 and GPIO1 P. or pin numbers
        gpio1_words = [w for w in words if re.match(r'IO_L\d+[PN]_T\d+', w[4]) and '_33' in w[4]]
        for w in gpio1_words[:50]:
            x, y, _, _, txt = w[0], w[1], w[2], w[3], w[4]
            print(f"  ({x:.0f},{y:.0f}) {txt}")
        break
